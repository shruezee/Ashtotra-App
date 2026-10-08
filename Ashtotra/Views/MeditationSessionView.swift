import AVFoundation
import SwiftUI

/// The meditation itself: "gently close your eyes", a breathing circle, the chosen sound,
/// and a haptic breath guide, ending with a bell.
struct MeditationSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PracticeLog.self) private var log

    let minutes: Int
    let sound: MeditationSound
    let pattern: BreathPattern
    let haptics: Bool
    let song: DevotionalSong.Choice

    @State private var startedAt = Date()
    @State private var pausedAt: Date?
    @State private var pausedTotal: TimeInterval = 0
    @State private var finished = false
    @State private var lastPhase: BreathPattern.Phase?
    @State private var synth = DroneSynth()
    @State private var breath = BreathHaptics()
    @State private var songMissing = false

    private var total: TimeInterval { Double(minutes) * 60 }

    private func elapsed(at now: Date) -> TimeInterval {
        let end = pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedTotal)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.08, blue: 0.20), Color(red: 0.30, green: 0.12, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if finished {
                completion
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: pausedAt != nil)) { context in
                    session(at: context.date)
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: begin)
        .onDisappear(perform: tearDown)
        .task(id: pausedAt == nil) { await tick() }
    }

    // MARK: Session

    private func session(at now: Date) -> some View {
        let t = elapsed(at: now)
        let (phase, progress) = pattern.phase(at: t)
        let scale: Double = switch phase {
        case .inhale: 0.55 + 0.45 * ease(progress)
        case .hold: 1
        case .exhale: 1 - 0.45 * ease(progress)
        case .rest: 0.55
        }
        let remaining = max(0, total - t)
        let intro = max(0, 1 - max(0, t - 6) / 3)

        return VStack(spacing: 24) {
            HStack {
                Text(remaining.formattedClock)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .opacity(0.7)
                    .accessibilityLabel("\(Int(remaining / 60)) minutes \(Int(remaining) % 60) seconds left")
                Spacer()
                if sound == .myMusic && songMissing {
                    Label("Song unavailable", systemImage: "music.note")
                        .font(.footnote)
                        .opacity(0.7)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.72, blue: 0.35).opacity(0.9),
                                                  Color(red: 0.95, green: 0.42, blue: 0.20).opacity(0.25)],
                                         center: .center, startRadius: 4, endRadius: 170))
                    .frame(width: 320, height: 320)
                    .scaleEffect(reduceMotion ? 0.85 : scale)
                    .blur(radius: 1)
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 320, height: 320)
                VStack(spacing: 6) {
                    Text(phase.rawValue)
                        .font(.title.weight(.semibold))
                    if reduceMotion {
                        Text("\(Int(phaseLength(phase) * (1 - progress)) + 1)")
                            .font(.title2.monospacedDigit())
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
            }
            Spacer()

            VStack(spacing: 8) {
                Text("Gently close your eyes")
                    .font(.title2.weight(.medium))
                Text(haptics ? "Follow the gentle vibration: it rises as you breathe in and fades as you breathe out."
                             : "Breathe slowly with the circle.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
            }
            .padding(.horizontal, 32)
            .opacity(intro)
            .accessibilityHidden(intro == 0)

            HStack(spacing: 16) {
                Button(action: togglePause) {
                    Label(pausedAt == nil ? "Pause" : "Resume", systemImage: pausedAt == nil ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .background(.white.opacity(0.14), in: .rect(cornerRadius: 20))
                Button {
                    finish(early: true)
                } label: {
                    Label("End", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: 520)
        }
    }

    private var completion: some View {
        let sat = max(1, Int((min(elapsed(at: .now), total) / 60).rounded()))
        return VStack(spacing: 20) {
            Spacer()
            Text("🙏").font(.system(size: 80)).accessibilityHidden(true)
            Text("Namaste")
                .font(.largeTitle.weight(.bold))
            Text("You sat in stillness for \(sat) \(sat == 1 ? "minute" : "minutes").")
                .font(.title3)
                .multilineTextAlignment(.center)
                .opacity(0.9)
            Text("Take a moment before you open your eyes.")
                .font(.body)
                .opacity(0.7)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: 520, minHeight: 64)
                    .background(.white.opacity(0.2), in: .rect(cornerRadius: 20))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .padding(24)
    }

    // MARK: Lifecycle

    private func begin() {
        UIApplication.shared.isIdleTimerDisabled = true
        // The Music app plays in its own process, so let it mix with ours; files play inside Ashtotra.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: sound == .myMusic && song.source == .music ? [.mixWithOthers] : [])
        try? AVAudioSession.sharedInstance().setActive(true)
        switch sound {
        case .tanpura: synth.start(.tanpura)
        case .bowl: synth.start(.bowl)
        case .silence: synth.start(.none)
        case .myMusic:
            synth.start(.none)
            songMissing = !DevotionalSong.play(song)
        }
        if haptics { breath.prepare() }
        startedAt = .now
    }

    /// Drives haptics and the end of the session; the visuals come from TimelineView.
    private func tick() async {
        while !Task.isCancelled, !finished, pausedAt == nil {
            let t = elapsed(at: .now)
            if t >= total {
                finish(early: false)
                return
            }
            let phase = pattern.phase(at: t).phase
            if phase != lastPhase {
                lastPhase = phase
                if haptics { breath.play(phase, duration: phaseLength(phase)) }
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func togglePause() {
        if let pausedAt {
            pausedTotal += Date.now.timeIntervalSince(pausedAt)
            self.pausedAt = nil
            lastPhase = nil
        } else {
            pausedAt = .now
            breath.play(.hold, duration: 0)
        }
    }

    private func finish(early: Bool) {
        guard !finished else { return }
        let sat = Int((min(elapsed(at: .now), total) / 60).rounded())
        if !early || sat >= 1 {
            log.addMeditation(minutes: max(1, sat))
        }
        if early && sat < 1 {
            dismiss()
            return
        }
        synth.fadeOut()
        if sound == .myMusic { DevotionalSong.stop() }
        synth.ringBell()
        if haptics { breath.success() }
        withAnimation(.easeInOut(duration: 1)) { finished = true }
        UIAccessibility.post(notification: .announcement, argument: "Meditation complete. Namaste.")
    }

    private func tearDown() {
        UIApplication.shared.isIdleTimerDisabled = false
        breath.stop()
        if sound == .myMusic { DevotionalSong.stop() }
        Task {
            try? await Task.sleep(for: .seconds(finished ? 0 : 0.1))
            synth.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func phaseLength(_ phase: BreathPattern.Phase) -> Double {
        switch phase {
        case .inhale: pattern.inhale
        case .hold: pattern.hold
        case .exhale: pattern.exhale
        case .rest: pattern.rest
        }
    }

    private func ease(_ x: Double) -> Double { 0.5 - 0.5 * cos(.pi * x) }
}

private extension TimeInterval {
    var formattedClock: String {
        let seconds = Int(self.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
