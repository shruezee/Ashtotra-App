import SwiftUI

struct NamesView: View {
    @Environment(PracticeLog.self) private var log
    @AppStorage("script") private var script: Script = .simple

    private let library = Library.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ForEach(library.collections) { collection in
                    NavigationLink(value: collection) {
                        CollectionCard(collection: collection, script: script)
                    }
                    .buttonStyle(.plain)
                }
                footer
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("108 Names")
        .settingsToolbar()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ashtottara Shatanamavali: chant 108 names with a mala.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            if log.totalCompletions > 0 {
                Label(progressSummary, systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.saffron)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    private var progressSummary: String {
        let streak = log.streak()
        let times = log.totalCompletions == 1 ? "1 offering" : "\(log.totalCompletions) offerings"
        return streak > 1 ? "\(times) · \(streak) days in a row" : times
    }

    private var footer: some View {
        Text("No ads, no accounts, no tracking. Everything stays on your device.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}

struct CollectionCard: View {
    @Environment(PracticeLog.self) private var log
    let collection: NameCollection
    let script: Script

    var body: some View {
        let position = log.position(in: collection.id)
        let done = log.completions(of: collection.id)

        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(collection.title)
                    .font(.title.weight(.bold))
                Text(collection.nativeTitle, script: .devanagari)
                    .font(.title3)
                    .opacity(0.9)
                Text(collection.blurb)
                    .font(.callout)
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    if position > 0 {
                        Label("Continue at \(position + 1)", systemImage: "bookmark.fill")
                    } else {
                        Label("108 names", systemImage: "circle.grid.3x3.fill")
                    }
                    if done > 0 {
                        Label("\(done)×", systemImage: "checkmark.seal.fill")
                            .accessibilityLabel("Completed \(done) times")
                    }
                }
                .font(.footnote.weight(.semibold))
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.headline)
                .opacity(0.8)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gradient(for: collection), in: .rect(cornerRadius: 24))
        .shadow(color: Theme.tint(for: collection).opacity(0.25), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the 108 names")
    }
}

#Preview {
    NavigationStack { NamesView() }.environment(PracticeLog())
}
