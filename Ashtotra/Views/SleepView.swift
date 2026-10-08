import SwiftUI

/// Background sounds for sleep, with a timer that fades out gently.
struct SleepView: View {
    @Environment(SleepPlayer.self) private var player
    @AppStorage("sleepSound") private var selected: SleepSound = .rain
    @AppStorage("sleepMinutes") private var minutes = SleepTimer.defaultMinutes   // 0 = until stopped
    @AppStorage(DevotionalSong.idKey) private var songID = ""
    @AppStorage(DevotionalSong.titleKey) private var songTitle = ""
    @AppStorage(DevotionalSong.sourceKey) private var songSource = DevotionalSong.Source.music.rawValue
    @AppStorage(DevotionalSong.fileKey) private var songFile = ""
    @State private var showPlayer = false
    @State private var showPaywall = false
    @Environment(PlusStore.self) private var plus

    private var song: DevotionalSong.Choice {
        DevotionalSong.Choice(source: DevotionalSong.Source(rawValue: songSource) ?? .music, persistentID: songID, fileName: songFile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Drift off to soothing sounds. They keep playing when your screen locks, and fade out gently.")
                .font(.title3)
                .foregroundStyle(.secondary)

            if player.isPlaying, let sound = player.sound {
                nowPlaying(sound)
            }

            ForEach(SleepSound.Group.allCases, id: \.self) { group in
                Card(title: group.rawValue) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        ForEach(SleepSound.grouped(group)) { sound in
                            SoundTile(sound: sound, selected: selected == sound,
                                      subtitle: sound == .mySong ? (song.isChosen ? songTitle : "Choose in Meditate › Sound") : nil) {
                                selected = sound
                            }
                            .disabled(sound == .mySong && !song.isChosen)
                        }
                    }
                }
            }

            Card(title: "Sleep timer") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(SleepTimer.options, id: \.self) { option in
                        let value = option ?? 0
                        Button {
                            minutes = value
                        } label: {
                            Text(SleepTimer.label(option))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(minutes == value ? Theme.saffron : .secondary)
                        .accessibilityAddTraits(minutes == value ? .isSelected : [])
                    }
                }
            }

            Button {
                guard plus.canUse(.meditation) else {
                    showPaywall = true
                    return
                }
                plus.beginFreePeriodIfNeeded(.meditation)
                player.play(selected, minutes: minutes == 0 ? nil : minutes, song: song)
                showPlayer = true
            } label: {
                Label("Play \(selected.title)", systemImage: "moon.zzz.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.32, green: 0.25, blue: 0.62))
            .buttonBorderShape(.roundedRectangle(radius: 20))
        }
        .fullScreenCover(isPresented: $showPlayer) { SleepPlayerView() }
        .sheet(isPresented: $showPaywall) { PlusPaywall(reason: .meditationEnded) }
    }

    private func nowPlaying(_ sound: SleepSound) -> some View {
        HStack(spacing: 14) {
            Image(systemName: sound.symbol).font(.title2).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Playing \(sound.title)").font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(player.remaining.map { "Fades out in \(Int($0 / 60) + 1) min" } ?? "Plays until you stop it")
                        .font(.subheadline).opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            Spacer()
            Button { showPlayer = true } label: { Image(systemName: "chevron.up.circle.fill").font(.title) }
                .accessibilityLabel("Open sleep player")
            Button { player.stop() } label: { Image(systemName: "stop.circle.fill").font(.title) }
                .accessibilityLabel("Stop")
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(LinearGradient(colors: [Color(red: 0.2, green: 0.16, blue: 0.42), Color(red: 0.36, green: 0.2, blue: 0.45)],
                                   startPoint: .leading, endPoint: .trailing), in: .rect(cornerRadius: 20))
    }
}

private struct SoundTile: View {
    let sound: SleepSound
    let selected: Bool
    let subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: sound.symbol)
                    .font(.title2)
                    .foregroundStyle(selected ? .white : Theme.saffron)
                Text(sound.title)
                    .font(.headline)
                    .foregroundStyle(selected ? .white : .primary)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            .padding(12)
            .background(selected ? AnyShapeStyle(Theme.saffron) : AnyShapeStyle(Theme.card), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Dark, simple player for the bedside: what's playing, time left, volume, and stop.
struct SleepPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SleepPlayer.self) private var player

    var body: some View {
        @Bindable var player = player
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.14), Color(red: 0.16, green: 0.09, blue: 0.24)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down").font(.title3.weight(.bold)).frame(width: 52, height: 52)
                            .background(.white.opacity(0.12), in: .circle)
                    }
                    .accessibilityLabel("Close player, keep playing")
                    Spacer()
                }
                Spacer()
                if let sound = player.sound {
                    Image(systemName: sound.symbol).font(.system(size: 64)).opacity(0.85).accessibilityHidden(true)
                    Text(sound.title).font(.largeTitle.weight(.semibold))
                    if player.songMissing {
                        Text("Your song couldn't be found. Choose it again in Meditate › Sound.").font(.callout).opacity(0.75)
                            .multilineTextAlignment(.center)
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        if let remaining = player.remaining {
                            Text(String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60))
                                .font(.system(size: 54, weight: .light, design: .rounded).monospacedDigit())
                                .accessibilityLabel("\(Int(remaining / 60)) minutes left")
                        } else {
                            Text("Until you stop").font(.title2).opacity(0.8)
                        }
                    }
                    if player.endsAt != nil {
                        Button("+ 10 minutes") { player.extend() }.font(.headline).buttonStyle(.bordered).tint(.white)
                    }
                } else {
                    Text("Sweet dreams 🌙").font(.largeTitle.weight(.semibold))
                }
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill").opacity(0.7)
                    Slider(value: $player.volume, in: 0.05...1) { Text("Volume") }
                        .tint(.white)
                    Image(systemName: "speaker.wave.3.fill").opacity(0.7)
                }
                Button {
                    player.stop()
                    dismiss()
                } label: {
                    Label("Stop", systemImage: "stop.fill").font(.title3.weight(.semibold))
                        .frame(maxWidth: 520, minHeight: 64)
                        .background(.white.opacity(0.16), in: .rect(cornerRadius: 20))
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .preferredColorScheme(.dark)
        .onChange(of: player.isPlaying) { _, playing in if !playing { dismiss() } }
    }
}
