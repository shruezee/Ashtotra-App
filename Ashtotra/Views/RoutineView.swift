import SwiftUI

/// A short sequence of mantras for a moment of the day, read or listened to in one go.
struct RoutineView: View {
    @Environment(PracticeLog.self) private var log
    @Environment(Reciter.self) private var reciter
    @AppStorage("script") private var script: Script = .simple
    @AppStorage("readerScale") private var scale = 1.0
    @ScaledMetric(relativeTo: .title3) private var baseSize: CGFloat = 21

    let routine: Routine
    private let book = PrayerBook.shared

    private var prayers: [Prayer] { book.prayers(in: routine) }

    /// Lines across all prayers, tagged with the prayer index for highlighting.
    private var lines: [(prayer: Int, text: String)] {
        prayers.enumerated().flatMap { index, prayer in
            prayer.verses.flatMap(\.lines).map { (index, $0.devanagari) }
        }
    }

    var body: some View {
        let allLines = lines
        let speakingPrayer = reciter.isPlaying(routine.id) ? reciter.currentIndex.map { allLines[$0].prayer } : nil

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(routine.subtitle, systemImage: routine.symbol)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    ForEach(Array(prayers.enumerated()), id: \.offset) { index, prayer in
                        VStack(alignment: .leading, spacing: 10) {
                            NavigationLink(value: prayer) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prayer.title).font(.headline)
                                        Text(prayer.about).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            ForEach(Array(prayer.verses.enumerated()), id: \.offset) { _, verse in
                                VerseView(verse: verse, script: script, fontSize: baseSize * scale,
                                          tint: Theme.textTint(for: prayer), highlighted: speakingPrayer == index)
                            }
                            if let meaning = prayer.meaning {
                                Text(meaning)
                                    .font(.callout)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .id(index)
                    }
                    Button {
                        toggleDone()
                    } label: {
                        Label(isDone ? "Done today" : "Mark as done today",
                              systemImage: isDone ? "checkmark.seal.fill" : "hands.sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .tint(isDone ? .green : Theme.saffron)
                    .sensoryFeedback(.success, trigger: isDone)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: speakingPrayer) { _, index in
                if let index { withAnimation { proxy.scrollTo(index, anchor: .top) } }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            ListenBar(owner: routine.id, tint: Theme.saffron) { allLines.map(\.text) }
        }
        .navigationTitle(routine.title)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ReaderOptionsMenu(script: $script, scale: $scale, shareText: shareText)
            }
        }
        .onDisappear {
            if reciter.isPlaying(routine.id) { reciter.stop() }
        }
    }

    private var activity: String { "routine:\(routine.id)" }
    private var isDone: Bool { log.did(activity) }

    private func toggleDone() {
        if isDone { log.unrecord(activity) } else { log.record(activity) }
    }

    private var shareText: String {
        let body = prayers.map { prayer in
            prayer.title + "\n" + prayer.verses.flatMap(\.lines).map { $0.text(in: script) }.joined(separator: "\n")
        }.joined(separator: "\n\n")
        return "\(routine.title)\n\n\(body)\n\nShared from Ashtotra"
    }
}
