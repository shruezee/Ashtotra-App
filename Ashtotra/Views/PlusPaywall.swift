import StoreKit
import SwiftUI

/// Why the subscription screen is showing, which shapes its message.
enum PlusReason: String, Identifiable {
    case hostingEnded, meditationEnded, afterSatsang, general
    var id: String { rawValue }
}

/// Ashtotra Plus: Apple's subscription sheet (prices, renewal terms, restore, terms and privacy
/// are handled by StoreKit) with a header that explains what's included.
struct PlusPaywall: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlusStore.self) private var plus
    let reason: PlusReason

    var body: some View {
        SubscriptionStoreView(productIDs: PlusStore.productIDs) {
            header
        }
        .subscriptionStoreControlStyle(.automatic)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: URL(string: "https://shruezee.github.io/Ashtotra-App/privacy.html")!, for: .privacyPolicy)
        .tint(Theme.saffron)
        .background(Theme.background.ignoresSafeArea())
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await plus.refresh()
                dismiss()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Text(emoji).font(.system(size: 52)).accessibilityHidden(true)
            Text(title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                Label("Host satsangs: prayers, chanting, chat, YouTube, videos, PDFs", systemImage: "person.2.wave.2.fill")
                Label("Meditate with the haptic breath guide and your own song", systemImage: "leaf.fill")
                Label("Sleep sounds: rain, ocean, Om drone, temple bells and more", systemImage: "moon.zzz.fill")
                Label("Prayers, 108 names and joining satsangs stay free", systemImage: "heart.fill")
            }
            .font(.callout)
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 18))
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private var emoji: String {
        switch reason {
        case .afterSatsang: "🙏"
        case .meditationEnded: "🍃"
        case .hostingEnded: "🪔"
        case .general: "🕉️"
        }
    }

    private var title: String {
        switch reason {
        case .afterSatsang: "Hope your satsang was beautiful"
        case .hostingEnded: "You've used your free satsang"
        case .meditationEnded: "Your free month of meditation has ended"
        case .general: "Ashtotra Plus"
        }
    }

    private var message: String {
        switch reason {
        case .afterSatsang, .hostingEnded:
            "Keep leading satsangs for family and friends with Ashtotra Plus. Joining stays free for everyone."
        case .meditationEnded:
            "Keep meditating and drifting off to sleep sounds with Ashtotra Plus."
        case .general:
            "One subscription for hosting satsangs, meditation and sleep sounds."
        }
    }
}

/// Small capsule showing a feature's free period or Plus status.
struct PlusBadge: View {
    @Environment(PlusStore.self) private var plus
    let feature: PlusStore.Feature

    var body: some View {
        if plus.pricingEnabled {
            let text = plus.badge(for: feature)
            Text(text)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(plus.isSubscribed ? Color.green : Theme.saffron, in: .capsule)
                .accessibilityLabel(plus.isSubscribed ? "Included with Ashtotra Plus" : text.capitalized)
        }
    }
}

/// A one-line note above Meditate and Sleep about the free month.
struct PlusFreePeriodBanner: View {
    @Environment(PlusStore.self) private var plus
    let feature: PlusStore.Feature
    let showPlans: () -> Void

    var body: some View {
        if plus.pricingEnabled && !plus.isSubscribed {
            Button(action: showPlans) {
                HStack(spacing: 10) {
                    PlusBadge(feature: feature)
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Theme.card, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private var text: String {
        switch plus.status(of: feature) {
        case .notStarted: "Meditation and Sleep are free for your first month."
        case .active: "Enjoy your free month of Meditation and Sleep."
        case .ended: "Your free month has ended. Continue with Ashtotra Plus."
        }
    }
}
