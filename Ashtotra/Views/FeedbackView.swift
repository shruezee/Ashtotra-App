import StoreKit
import SwiftUI

/// What people like and what they'd like next. Feedback goes out as an email the person reviews and
/// sends themselves, so Ashtotra collects nothing and needs no account.
struct FeedbackView: View {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @State private var loved: Set<String> = []
    @State private var improve = ""
    @State private var idea = ""

    private static let areas = ["Prayers", "108 Names", "Chanting", "Voice recordings", "Meditation", "Sleep sounds", "Satsang"]
    private static let email = "shruthianthropic@gmail.com"
    private static let reviewURL = URL(string: "https://apps.apple.com/app/id1474584223?action=write-review")!

    var body: some View {
        Form {
            Section {
                Button {
                    requestReview()
                } label: {
                    Label("Rate Ashtotra", systemImage: "star.fill")
                }
                Button {
                    openURL(Self.reviewURL)
                } label: {
                    Label("Write an App Store review", systemImage: "square.and.pencil")
                }
            } header: {
                Text("Enjoying Ashtotra?")
            } footer: {
                Text("A short review helps other families find it.")
            }

            Section("What do you love?") {
                ForEach(Self.areas, id: \.self) { area in
                    Toggle(area, isOn: Binding(
                        get: { loved.contains(area) },
                        set: { if $0 { loved.insert(area) } else { loved.remove(area) } }))
                }
            }

            Section("What could be better?") {
                TextField("Tell us what felt confusing or missing", text: $improve, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("Feature idea") {
                TextField("A prayer, a language, a feature you'd like", text: $idea, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                Button {
                    if let url = mailURL { openURL(url) }
                } label: {
                    Label("Send feedback", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(loved.isEmpty && improve.isEmpty && idea.isEmpty)
            } footer: {
                Text("This opens an email for you to review and send. Nothing is sent automatically.")
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mailURL: URL? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let body = """
        What I love: \(loved.isEmpty ? "-" : loved.sorted().joined(separator: ", "))

        What could be better:
        \(improve.isEmpty ? "-" : improve)

        Feature idea:
        \(idea.isEmpty ? "-" : idea)

        Ashtotra \(version)
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Ashtotra feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
