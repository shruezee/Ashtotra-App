import SwiftUI

struct TodayView: View {
    @Environment(PracticeLog.self) private var log
    @AppStorage("script") private var script: Script = .simple
    @Binding var tab: AppTab
    @State private var showSatsang = false
    
    private let book = PrayerBook.shared
    private let library = Library.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greeting(now)
                    checklist(now)
                    todaysDevotion(now)
                    satsangCard
                    routines(now)
                    continueChanting
                    favorites
                    Text("No ads, no accounts, no tracking. Everything stays on your device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Ashtotra")
        .settingsToolbar()
        .sheet(isPresented: $showSatsang) { SatsangStartView() }
    }

    // MARK: Sections

    private var satsangCard: some View {
        Button {
            showSatsang = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "shareplay")
                    .font(.title)
                    .foregroundStyle(Theme.saffron)
                    .frame(width: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Satsang together").font(.headline)
                        PlusBadge(feature: .hosting)
                    }
                    Text("Pray and chant with family over FaceTime, in sync")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func greeting(_ now: Date) -> some View {
        let hour = Calendar.current.component(.hour, from: now)
        let hello = switch hour {
        case 4..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(hello) 🙏")
                .font(.title2.weight(.semibold))
            Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
                .foregroundStyle(.secondary)
            if log.practiced(on: now) || log.streak(today: now) > 0 {
                Label(streakText(now), systemImage: log.practiced(on: now) ? "checkmark.seal.fill" : "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.saffron)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    private func streakText(_ now: Date) -> String {
        let streak = log.streak(today: now)
        let today = log.practiced(on: now) ? "Prayed today" : "Not yet today"
        return streak > 1 ? "\(today) · \(streak) days in a row" : today
    }

    private func checklist(_ now: Date) -> some View {
        let list = DailyChecklist(date: now)
        let activities = log.activities(on: now)
        let done = list.doneCount(in: activities)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(text: "Today's practice")
                Spacer()
                Text(done == list.items.count ? "All done 🙏" : "\(done) of \(list.items.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(done == list.items.count ? .green : Theme.saffron)
            }
            VStack(spacing: 0) {
                ForEach(list.items) { item in
                    ChecklistRow(item: item, done: DailyChecklist.isDone(item, in: activities)) {
                        if DailyChecklist.isDone(item, in: activities) {
                            log.unrecord(item.activity)
                            item.alsoCounts.forEach { log.unrecord($0) }
                        } else {
                            log.record(item.activity)
                        }
                    } open: {
                        if case .meditate = item.destination { tab = .meditate }
                    }
                    if item != list.items.last { Divider().padding(.leading, 60) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 20))
            NavigationLink {
                JourneyView()
            } label: {
                HStack {
                    WeekStripPreview()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Theme.card, in: .rect(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Your practice this week. Opens your prayer calendar.")
        }
    }

    @ViewBuilder
    private func todaysDevotion(_ now: Date) -> some View {
        let devotion = Weekday.devotion(for: Calendar.current.component(.weekday, from: now))
        if let prayer = book.prayer(id: devotion.prayerID) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Today's devotion")
                NavigationLink(value: prayer) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(devotion.note)
                            .font(.subheadline.weight(.semibold))
                            .opacity(0.9)
                        Text(prayer.title)
                            .font(.title.weight(.bold))
                        Text(prayer.nativeTitle, script: .devanagari)
                            .font(.title3)
                            .opacity(0.9)
                        Label("Read or listen", systemImage: "speaker.wave.2.fill")
                            .font(.footnote.weight(.semibold))
                            .padding(.top, 4)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.gradient(for: prayer), in: .rect(cornerRadius: 24))
                    .shadow(color: Theme.tint(for: prayer).opacity(0.25), radius: 10, y: 5)
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                if let namesID = devotion.namesID, let collection = library.collection(id: namesID) {
                    NavigationLink(value: collection) {
                        Label("Also: 108 names of \(collection.title)", systemImage: "circle.dotted")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .padding(.horizontal, 16)
                            .background(Theme.card, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func routines(_ now: Date) -> some View {
        let current = book.routine(for: now)
        let others = book.routines.filter { $0.id != current.id }
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Right now")
            NavigationLink(value: current) {
                RoutineCard(routine: current, prominent: true)
            }
            .buttonStyle(.plain)
            SectionTitle(text: "Through the day")
                .padding(.top, 6)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(others) { routine in
                    NavigationLink(value: routine) {
                        RoutineCard(routine: routine, prominent: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var continueChanting: some View {
        let inProgress = library.collections.filter { log.position(in: $0.id) > 0 }
        if !inProgress.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Continue chanting")
                ForEach(inProgress) { collection in
                    NavigationLink(value: collection) {
                        HStack {
                            Label("\(collection.title): name \(log.position(in: collection.id) + 1) of 108",
                                  systemImage: "bookmark.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.textTint(for: collection))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 52)
                        .padding(.horizontal, 16)
                        .background(Theme.card, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var favorites: some View {
        let favorites = book.prayers.filter { log.isFavorite($0.id) }
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Your favourites")
            if favorites.isEmpty {
                Button {
                    tab = .prayers
                } label: {
                    Label("Tap ♡ on any prayer to keep it here. Browse prayers", systemImage: "heart")
                        .font(.callout)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(Theme.card, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(favorites) { prayer in
                    NavigationLink(value: prayer) {
                        HStack {
                            Circle().fill(Theme.gradient(for: prayer)).frame(width: 12, height: 12)
                            Text(prayer.title).font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 52)
                        .padding(.horizontal, 16)
                        .background(Theme.card, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ChecklistRow: View {
    let item: DailyChecklist.Item
    let done: Bool
    let toggle: () -> Void
    let open: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggle) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(done ? Color.green : Theme.saffron.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "\(item.title), done" : "Mark \(item.title) as done")
            .sensoryFeedback(.success, trigger: done) { _, new in new }

            destinationLink
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var destinationLink: some View {
        let label = HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(done, color: .secondary)
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: item.symbol).foregroundStyle(Theme.saffron)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 52)
        .contentShape(.rect)
        switch item.destination {
        case .routine(let routine): NavigationLink(value: routine) { label }.buttonStyle(.plain)
        case .prayer(let prayer): NavigationLink(value: prayer) { label }.buttonStyle(.plain)
        case .meditate: Button(action: open) { label }.buttonStyle(.plain)
        }
    }
}

/// Compact week rings for the Today screen.
struct WeekStripPreview: View {
    @State private var day = Calendar.current.startOfDay(for: .now)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week").font(.subheadline.weight(.semibold))
            WeekStrip(selectedDay: $day)
                .allowsHitTesting(false)
        }
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.weight(.bold))
            .accessibilityAddTraits(.isHeader)
    }
}

struct RoutineCard: View {
    let routine: Routine
    let prominent: Bool

    var body: some View {
        let count = routine.prayers.count
        VStack(alignment: .leading, spacing: prominent ? 8 : 6) {
            Image(systemName: routine.symbol)
                .font(prominent ? .title : .title2)
                .foregroundStyle(Theme.saffron)
                .accessibilityHidden(true)
            Text(routine.title)
                .font(prominent ? .title2.weight(.bold) : .headline)
            Text(prominent ? "\(routine.subtitle) · \(count) \(count == 1 ? "prayer" : "prayers")" : routine.subtitle)
                .font(prominent ? .callout : .footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(prominent ? 20 : 14)
        .frame(maxWidth: .infinity, minHeight: prominent ? 0 : 120, alignment: .topLeading)
        .background(Theme.card, in: .rect(cornerRadius: prominent ? 24 : 18))
        .overlay {
            RoundedRectangle(cornerRadius: prominent ? 24 : 18)
                .stroke(Theme.saffron.opacity(prominent ? 0.5 : 0.15), lineWidth: prominent ? 2 : 1)
        }
        .accessibilityElement(children: .combine)
    }
}
