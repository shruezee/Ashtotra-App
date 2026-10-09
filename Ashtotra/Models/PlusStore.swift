import Foundation
import Observation
import Security
import StoreKit

/// "Ashtotra Plus": one subscription that unlocks hosting satsangs and meditation (including Sleep).
/// Prayers, the 108 names, chanting, and joining a satsang are always free.
///
/// Before subscribing, each feature has a free period that starts the first time it's used:
/// hosting a satsang is free for one day, and meditation is free for one month.
@MainActor
@Observable
final class PlusStore {
    static let monthlyID = "com.shruezee.ashtotra.plus.monthly"
    static let yearlyID = "com.shruezee.ashtotra.plus.yearly"
    static let productIDs = [monthlyID, yearlyID]

    /// Pricing is off during the launch: every feature is free and no paywall or badge shows.
    /// Turn on once the local artist voices are in and the app has around 1,000 users.
    static let pricingLive = false

    static let hostingFreePeriod: TimeInterval = 24 * 60 * 60
    static let meditationFreePeriod: TimeInterval = 30 * 24 * 60 * 60

    enum Feature { case hosting, meditation }

    let pricingEnabled: Bool
    private(set) var isSubscribed = false
    private(set) var products: [Product] = []
    private(set) var hostingStart: Date?
    private(set) var meditationStart: Date?

    @ObservationIgnored private let storage: TrialStorage
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(storage: TrialStorage = KeychainTrialStorage(), now: @escaping () -> Date = Date.init,
         observeTransactions: Bool = true, pricingEnabled: Bool = PlusStore.pricingLive) {
        self.pricingEnabled = pricingEnabled
        self.storage = storage
        self.now = now
        hostingStart = storage.date(for: "hostingTrialStart")
        meditationStart = storage.date(for: "meditationTrialStart")
        guard observeTransactions, pricingEnabled else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refresh()
                }
            }
        }
        Task { await load() }
    }

    // MARK: Access

    func canUse(_ feature: Feature) -> Bool {
        !pricingEnabled || isSubscribed || status(of: feature) != .ended
    }

    enum FreeStatus: Equatable {
        case notStarted
        case active(endsAt: Date)
        case ended
    }

    func status(of feature: Feature) -> FreeStatus {
        let (start, length) = feature == .hosting
            ? (hostingStart, Self.hostingFreePeriod)
            : (meditationStart, Self.meditationFreePeriod)
        guard let start else { return .notStarted }
        let end = start.addingTimeInterval(length)
        return now() < end ? .active(endsAt: end) : .ended
    }

    /// Call when the feature is actually used; starts its free period the first time.
    func beginFreePeriodIfNeeded(_ feature: Feature) {
        guard pricingEnabled, !isSubscribed else { return }
        switch feature {
        case .hosting where hostingStart == nil:
            hostingStart = now()
            storage.set(hostingStart!, for: "hostingTrialStart")
        case .meditation where meditationStart == nil:
            meditationStart = now()
            storage.set(meditationStart!, for: "meditationTrialStart")
        default:
            break
        }
    }

    /// Short text for badges and banners.
    func badge(for feature: Feature) -> String {
        if isSubscribed { return "✓ PLUS" }
        switch status(of: feature) {
        case .notStarted: return feature == .hosting ? "FIRST DAY FREE" : "1 MONTH FREE"
        case .active(let end): return "FREE · " + Self.timeLeft(until: end, from: now())
        case .ended: return "PLUS"
        }
    }

    static func timeLeft(until end: Date, from start: Date) -> String {
        let seconds = max(0, end.timeIntervalSince(start))
        if seconds >= 2 * 24 * 3600 { return "\(Int(seconds / 86_400)) DAYS LEFT" }
        if seconds >= 2 * 3600 { return "\(Int(seconds / 3600)) HRS LEFT" }
        return "\(max(1, Int(seconds / 60))) MIN LEFT"
    }

    // MARK: StoreKit

    func load() async {
        products = ((try? await Product.products(for: Self.productIDs)) ?? []).sorted { $0.price < $1.price }
        await refresh()
    }

    func refresh() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil,
               (transaction.expirationDate ?? .distantFuture) > now() {
                active = true
            }
        }
        isSubscribed = active
    }
}

// MARK: - Free-period storage

/// Where free-period start dates are kept.
protocol TrialStorage {
    func date(for key: String) -> Date?
    func set(_ date: Date, for key: String)
}

/// Keychain keeps the dates even if the app is deleted and reinstalled, so free periods can't be restarted.
struct KeychainTrialStorage: TrialStorage {
    private let service = "com.shruezee.ashtotra.trials"

    func date(for key: String) -> Date? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: key, kSecReturnData as String: true]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let seconds = Double(String(decoding: data, as: UTF8.self)) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    func set(_ date: Date, for key: String) {
        let data = Data(String(date.timeIntervalSince1970).utf8)
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// For tests and previews.
final class MemoryTrialStorage: TrialStorage {
    private var values: [String: Date] = [:]
    func date(for key: String) -> Date? { values[key] }
    func set(_ date: Date, for key: String) { values[key] = date }
}
