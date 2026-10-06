import SwiftUI

struct MeditateView: View {
    @Environment(PracticeLog.self) private var log
    @AppStorage("meditationLength") private var minutes = MeditationLength.defaultMinutes
    @AppStorage("meditationSound") private var sound: MeditationSound = .tanpura
    @AppStorage("breathPattern") private var patternID = BreathPattern.calm.id
    @AppStorage("breathHaptics") private var hapticsOn = true
    @AppStorage(DevotionalSong.idKey) private var songID = ""
    @AppStorage(DevotionalSong.titleKey) private var songTitle = ""
    @State private var showPicker = false
    @State private var libraryDenied = false
    @State private var sessionOpen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Sit comfortably, gently close your eyes, and let your breath slow down.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                durationCard
                soundCard
                breathCard
                Button {
                    sessionOpen = true
                } label: {
                    Label("Begin \(minutes)-minute meditation", systemImage: "leaf.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.saffron)
                .buttonBorderShape(.roundedRectangle(radius: 20))
                stats
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Meditate")
        .settingsToolbar()
        .fullScreenCover(isPresented: $sessionOpen) {
            MeditationSessionView(minutes: minutes, sound: sound, pattern: .named(patternID),
                                  haptics: hapticsOn && BreathHaptics.isSupported, songID: songID)
        }
        .sheet(isPresented: $showPicker) {
            SongPicker { item in
                songID = String(item.persistentID)
                songTitle = [item.title, item.artist].compactMap { $0 }.joined(separator: " · ")
                sound = .myMusic
            }
            .ignoresSafeArea()
        }
        #if DEBUG
        .onAppear {
            if UserDefaults.standard.string(forKey: "demoRoute") == "meditate:session" { sessionOpen = true }
        }
        #endif
    }

    private var durationCard: some View {
        Card(title: "Length") {
            HStack(spacing: 16) {
                RoundButton(symbol: "minus", label: "One minute less") { minutes = max(MeditationLength.range.lowerBound, minutes - 1) }
                    .disabled(minutes <= MeditationLength.range.lowerBound)
                VStack(spacing: 0) {
                    Text("\(minutes)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(minutes == 1 ? "minute" : "minutes")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                RoundButton(symbol: "plus", label: "One minute more") { minutes = min(MeditationLength.range.upperBound, minutes + 1) }
                    .disabled(minutes >= MeditationLength.range.upperBound)
            }
            Slider(value: Binding(get: { Double(minutes) }, set: { minutes = Int($0.rounded()) }),
                   in: Double(MeditationLength.range.lowerBound)...Double(MeditationLength.range.upperBound), step: 1) {
                Text("Minutes")
            } minimumValueLabel: { Text("1") } maximumValueLabel: { Text("20") }
                .tint(Theme.saffron)
            HStack {
                ForEach([2, 5, 10, 20], id: \.self) { preset in
                    Button { withAnimation { minutes = preset } } label: {
                        Text("\(preset) min").lineLimit(1).fixedSize()
                    }
                        .buttonStyle(.bordered)
                        .tint(minutes == preset ? Theme.saffron : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.snappy, value: minutes)
        .sensoryFeedback(.selection, trigger: minutes)
    }

    private var soundCard: some View {
        Card(title: "Sound") {
            ForEach(MeditationSound.allCases) { option in
                Button {
                    if option == .myMusic && songID.isEmpty { chooseSong() } else { sound = option }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.symbol)
                            .frame(width: 28)
                            .foregroundStyle(Theme.saffron)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title).font(.headline)
                            if option == .myMusic {
                                Text(songTitle.isEmpty ? "Choose a song from your Music library" : songTitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if sound == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.saffron)
                                .accessibilityLabel("Selected")
                        }
                    }
                    .frame(minHeight: 48)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            if sound == .myMusic || !songID.isEmpty {
                Button(songID.isEmpty ? "Choose song" : "Change song", action: chooseSong)
                    .font(.subheadline.weight(.semibold))
            }
            if libraryDenied {
                Text("Ashtotra needs access to your Music library to play your song. You can allow it in the Settings app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var breathCard: some View {
        Card(title: "Breath guide") {
            Picker("Rhythm", selection: $patternID) {
                ForEach(BreathPattern.all) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.segmented)
            Text(BreathPattern.named(patternID).summary + " seconds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if BreathHaptics.isSupported {
                Toggle(isOn: $hapticsOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptic breath").font(.headline)
                        Text("Feel a gentle vibration rise as you breathe in and fade as you breathe out, so you can keep your eyes closed.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Theme.saffron)
            }
        }
    }

    private var stats: some View {
        let today = log.meditationMinutes(on: .now)
        return HStack {
            StatTile(value: "\(today)", label: "min today")
            StatTile(value: "\(log.totalMeditationMinutes)", label: "min in total")
            StatTile(value: "\(log.streak())", label: log.streak() == 1 ? "day streak" : "days streak")
        }
    }

    private func chooseSong() {
        Task {
            if await DevotionalSong.requestAccess() {
                libraryDenied = false
                showPicker = true
            } else {
                libraryDenied = true
            }
        }
    }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: title)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 22))
    }
}

struct RoundButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .frame(width: 60, height: 60)
                .background(Theme.saffron.opacity(0.15), in: .circle)
        }
        .foregroundStyle(Theme.saffron)
        .accessibilityLabel(label)
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
