import Foundation
import Observation
import StoreKit

/// The one-time "Satsang Host" purchase. Joining a satsang is always free; hosting needs the
/// purchase, except for one free satsang to try it.
@MainActor
@Observable
final class SatsangStore {
    static let productID = "com.shruezee.ashtotra.satsanghost"

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isPurchasing = false
    private(set) var message: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updates: Task<Void, Never>?
    private(set) var freeSatsangUsed: Bool

    init(defaults: UserDefaults = .standard, observeTransactions: Bool = true) {
        self.defaults = defaults
        freeSatsangUsed = defaults.bool(forKey: "freeSatsangUsed")
        guard observeTransactions else { return }
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

    /// Whether this device may start or take over a satsang.
    var canHost: Bool { isUnlocked || !freeSatsangUsed }

    /// Call when a satsang actually starts with this device as host.
    func spendFreeSatsangIfNeeded() {
        guard !isUnlocked, !freeSatsangUsed else { return }
        freeSatsangUsed = true
        defaults.set(true, forKey: "freeSatsangUsed")
    }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
        await refresh()
    }

    func refresh() async {
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productID, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    func purchase() async {
        guard let product else {
            message = "The App Store isn't available right now. Please try again."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isUnlocked = true
                    message = "Thank you! You can host satsangs anytime. 🙏"
                }
            case .pending:
                message = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through. Please try again."
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
        message = isUnlocked ? "Satsang Host restored. 🙏" : "No previous purchase was found for this Apple Account."
    }

    func clearMessage() { message = nil }
}
