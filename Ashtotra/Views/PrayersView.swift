import SwiftUI

struct PrayersView: View {
    @Environment(PracticeLog.self) private var log
    @State private var query = ""
    private let book = PrayerBook.shared

    var body: some View {
        List {
            if query.isEmpty {
                let favorites = book.prayers.filter { log.isFavorite($0.id) }
                if !favorites.isEmpty {
                    Section("Favourites") {
                        ForEach(favorites) { PrayerRow(prayer: $0) }
                    }
                }
                Section("Daily routines") {
                    ForEach(book.routines) { routine in
                        NavigationLink(value: routine) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.title).font(.headline)
                                    Text(routine.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: routine.symbol).foregroundStyle(Theme.saffron)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            ForEach([Prayer.Kind.stotra, .aarti, .mantra], id: \.self) { kind in
                let items = book.prayers(of: kind).filter(matches)
                if !items.isEmpty {
                    Section(kind.title) {
                        ForEach(items) { PrayerRow(prayer: $0) }
                    }
                    .listRowBackground(Theme.card)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Prayers")
        .searchable(text: $query, prompt: "Search prayers")
        .settingsToolbar()
        .overlay {
            if !query.isEmpty && !book.prayers.contains(where: matches) {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func matches(_ prayer: Prayer) -> Bool {
        query.isEmpty
            || prayer.title.localizedCaseInsensitiveContains(query)
            || prayer.nativeTitle.contains(query)
            || prayer.about.localizedCaseInsensitiveContains(query)
    }
}

struct PrayerRow: View {
    @Environment(PracticeLog.self) private var log
    let prayer: Prayer

    var body: some View {
        NavigationLink(value: prayer) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Theme.gradient(for: prayer))
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer.title).font(.headline)
                    Text(prayer.nativeTitle, script: .devanagari)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if log.isFavorite(prayer.id) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.tint(for: prayer))
                        .accessibilityLabel("Favourite")
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Theme.card)
    }
}
