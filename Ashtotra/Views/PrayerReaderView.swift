import SwiftUI

struct PrayerReaderView: View {
    @Environment(PracticeLog.self) private var log
    @Environment(Reciter.self) private var reciter
    @AppStorage("script") private var script: Script = .simple
    @AppStorage("readerScale") private var scale = 1.0
    @ScaledMetric(relativeTo: .title3) private var baseSize: CGFloat = 21

    let prayer: Prayer

    /// Every line in reading order, with the verse it belongs to.
    private var lines: [(verse: Int, line: ScriptText)] {
        prayer.verses.enumerated().flatMap { index, verse in verse.lines.map { (index, $0) } }
    }

    var body: some View {
        let allLines = lines
        let speaking = reciter.isPlaying(prayer.id) ? reciter.currentIndex : nil

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ForEach(Array(prayer.verses.enumerated()), id: \.offset) { verseIndex, verse in
                        let offset = allLines.firstIndex { $0.verse == verseIndex } ?? 0
                        VerseView(verse: verse, script: script, fontSize: baseSize * scale,
                                  tint: Theme.textTint(for: prayer),
                                  highlighted: speaking.map { $0 >= offset && $0 < offset + verse.lines.count } ?? false)
                            .id(verseIndex)
                    }
                    if prayer.kind != .mantra {
                        doneButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: reciter.currentIndex) { _, index in
                guard reciter.isPlaying(prayer.id), let index, allLines.indices.contains(index) else { return }
                withAnimation { proxy.scrollTo(allLines[index].verse, anchor: .center) }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            ListenBar(owner: prayer.id, tint: Theme.tint(for: prayer)) {
                allLines.map(\.line.devanagari)
            }
        }
        .navigationTitle(prayer.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    log.toggleFavorite(prayer.id)
                } label: {
                    Label(log.isFavorite(prayer.id) ? "Remove from favourites" : "Add to favourites",
                          systemImage: log.isFavorite(prayer.id) ? "heart.fill" : "heart")
                }
                .sensoryFeedback(.selection, trigger: log.isFavorite(prayer.id))
                ReaderOptionsMenu(script: $script, scale: $scale, shareText: shareText)
            }
        }
        .onDisappear {
            if reciter.isPlaying(prayer.id) { reciter.stop() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prayer.nativeTitle, script: .devanagari)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textTint(for: prayer))
            Text(prayer.about)
                .font(.body)
                .foregroundStyle(.secondary)
            if let meaning = prayer.meaning {
                Text(meaning)
                    .font(.callout)
                    .italic()
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: .rect(cornerRadius: 16))
                    .accessibilityLabel("Meaning: \(meaning)")
            }
        }
        .padding(.top, 8)
    }

    private var doneButton: some View {
        Button {
            log.recordPractice()
        } label: {
            Label(log.practiced() ? "Offered today" : "I've recited this today",
                  systemImage: log.practiced() ? "checkmark.seal.fill" : "hands.sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
        .tint(Theme.tint(for: prayer))
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .sensoryFeedback(.success, trigger: log.practiced())
        .padding(.top, 8)
    }

    private var shareText: String {
        let body = prayer.verses.map { verse in
            verse.lines.map { $0.text(in: script) }.joined(separator: "\n")
        }.joined(separator: "\n\n")
        return "\(prayer.title)\n\n\(body)\n\nShared from Ashtotra"
    }
}

struct VerseView: View {
    let verse: Verse
    let script: Script
    let fontSize: CGFloat
    let tint: Color
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = verse.label {
                Text(label)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let number = verse.number {
                    Text("\(number)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(minWidth: 26, alignment: .trailing)
                        .accessibilityLabel("Verse \(number)")
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(verse.lines.enumerated()), id: \.offset) { _, line in
                        Text(line.text(in: script), script: script)
                            .font(.system(size: fontSize))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(highlighted ? tint.opacity(0.16) : Theme.card, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(highlighted ? 0.6 : 0), lineWidth: 2)
        }
        .animation(.easeInOut(duration: 0.25), value: highlighted)
        .accessibilityElement(children: .combine)
    }
}

/// Script, text size and share, tucked into one menu.
struct ReaderOptionsMenu: View {
    @Binding var script: Script
    @Binding var scale: Double
    let shareText: String

    var body: some View {
        Menu {
            Picker("Script", selection: $script) {
                ForEach(Script.allCases) { Text($0.label).tag($0) }
            }
            Section("Text size") {
                Button { scale = min(scale + 0.15, 2.0) } label: { Label("Larger text", systemImage: "textformat.size.larger") }
                    .disabled(scale >= 2.0)
                Button { scale = max(scale - 0.15, 0.7) } label: { Label("Smaller text", systemImage: "textformat.size.smaller") }
                    .disabled(scale <= 0.7)
            }
            ShareLink(item: shareText) { Label("Share", systemImage: "square.and.arrow.up") }
        } label: {
            Label("Reading options", systemImage: "textformat")
        }
    }
}

/// Play / stop read-aloud with a pace control. Uses the device's Hindi voice, offline.
struct ListenBar: View {
    @Environment(Reciter.self) private var reciter
    let owner: String
    let tint: Color
    let lines: () -> [String]
    @State private var pace = 0.8

    var body: some View {
        let playing = reciter.isPlaying(owner)
        HStack(spacing: 14) {
            Button {
                if playing { reciter.stop() } else { reciter.play(lines(), owner: owner) }
            } label: {
                Label(playing ? "Stop" : "Listen", systemImage: playing ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.headline)
                    .frame(minWidth: 120, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .buttonBorderShape(.capsule)
            .disabled(!Reciter.hasVoice)

            Menu {
                Picker("Pace", selection: $pace) {
                    Text("Slow").tag(0.6)
                    Text("Calm").tag(0.8)
                    Text("Normal").tag(1.0)
                }
            } label: {
                Label(paceName, systemImage: "tortoise")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 52)
            }
            .onChange(of: pace) { _, new in reciter.pace = new }
            .onAppear { pace = reciter.pace }
            .accessibilityLabel("Reading pace: \(paceName)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: .capsule)
        .padding(.bottom, 8)
    }

    private var paceName: String {
        switch pace {
        case ..<0.7: "Slow"
        case ..<0.9: "Calm"
        default: "Normal"
        }
    }
}
