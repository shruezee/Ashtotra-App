import AVFoundation
import MediaPlayer
import Observation

/// Background sounds for falling asleep. All are generated on the device (no recordings),
/// except "My devotional song", which plays the user's own song.
enum SleepSound: String, CaseIterable, Identifiable {
    case rain, ocean, wind, forest, fireplace
    case whiteNoise, pinkNoise, brownNoise
    case omChant, templeBells, tanpura, singingBowl, mySong

    var id: String { rawValue }

    enum Group: String, CaseIterable {
        case nature = "Nature", noise = "Soft noise", devotional = "Devotional"
    }

    var group: Group {
        switch self {
        case .rain, .ocean, .wind, .forest, .fireplace: .nature
        case .whiteNoise, .pinkNoise, .brownNoise: .noise
        case .omChant, .templeBells, .tanpura, .singingBowl, .mySong: .devotional
        }
    }

    var title: String {
        switch self {
        case .rain: "Gentle rain"
        case .ocean: "Ocean waves"
        case .wind: "Soft wind"
        case .forest: "Night crickets"
        case .fireplace: "Fireplace"
        case .whiteNoise: "White noise"
        case .pinkNoise: "Pink noise"
        case .brownNoise: "Brown noise"
        case .omChant: "Om drone"
        case .templeBells: "Temple bells"
        case .tanpura: "Tanpura"
        case .singingBowl: "Singing bowl"
        case .mySong: "My devotional song"
        }
    }

    var symbol: String {
        switch self {
        case .rain: "cloud.rain.fill"
        case .ocean: "water.waves"
        case .wind: "wind"
        case .forest: "moon.stars.fill"
        case .fireplace: "flame.fill"
        case .whiteNoise, .pinkNoise, .brownNoise: "waveform"
        case .omChant: "circle.hexagongrid.fill"
        case .templeBells: "bell.fill"
        case .tanpura: "music.quarternote.3"
        case .singingBowl: "bell.circle.fill"
        case .mySong: "music.note"
        }
    }

    static func grouped(_ group: Group) -> [SleepSound] { allCases.filter { $0.group == group } }
}

/// Sleep timer choices in minutes; nil means play until stopped.
enum SleepTimer {
    static let options: [Int?] = [15, 30, 45, 60, 90, nil]
    static let defaultMinutes = 30
    /// Sound fades out gently over the final minute.
    static let fadeSeconds: Double = 60

    /// Volume multiplier for the time remaining (1 until the last minute, then down to 0).
    static func fadeGain(remaining: Double?) -> Double {
        guard let remaining else { return 1 }
        return min(1, max(0, remaining / fadeSeconds))
    }

    static func label(_ minutes: Int?) -> String {
        guard let minutes else { return "Until I stop" }
        return minutes < 60 ? "\(minutes) min" : minutes % 60 == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(minutes % 60) min"
    }
}

/// Plays a sleep sound with a timer, keeps playing when the phone is locked, and shows
/// controls on the Lock Screen.
@MainActor
@Observable
final class SleepPlayer {
    private(set) var sound: SleepSound?
    private(set) var endsAt: Date?
    private(set) var isPlaying = false
    private(set) var songMissing = false
    var volume: Double = 0.7 { didSet { applyVolume() } }

    @ObservationIgnored private let soundscape = SoundscapeSynth()
    @ObservationIgnored private let drone = DroneSynth()
    @ObservationIgnored private var tick: Task<Void, Never>?
    @ObservationIgnored private var song = DevotionalSong.Choice(source: .music, persistentID: "", fileName: "")
    @ObservationIgnored private var remoteSetUp = false

    var remaining: Double? { endsAt.map { max(0, $0.timeIntervalSinceNow) } }

    func play(_ sound: SleepSound, minutes: Int?, song: DevotionalSong.Choice) {
        stop()
        self.sound = sound
        self.song = song
        endsAt = minutes.map { Date.now.addingTimeInterval(Double($0) * 60) }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                         options: sound == .mySong && song.source == .music ? [.mixWithOthers] : [])
        try? AVAudioSession.sharedInstance().setActive(true)
        switch sound {
        case .tanpura: drone.start(.tanpura)
        case .singingBowl: drone.start(.bowl)
        case .mySong: songMissing = !DevotionalSong.play(song)
        default: soundscape.start(sound)
        }
        isPlaying = true
        applyVolume()
        setUpRemoteCommands()
        updateNowPlaying()
        tick = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if let remaining = self.remaining, remaining <= 0 {
                    self.stop()
                    return
                }
                self.applyVolume()
            }
        }
    }

    func stop() {
        tick?.cancel()
        tick = nil
        soundscape.stop()
        drone.stop()
        if sound == .mySong { DevotionalSong.stop() }
        isPlaying = false
        sound = nil
        endsAt = nil
        songMissing = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Add ten minutes to the timer.
    func extend() {
        guard let endsAt else { return }
        self.endsAt = max(endsAt, .now).addingTimeInterval(600)
        updateNowPlaying()
    }

    private func applyVolume() {
        let level = Float(volume * SleepTimer.fadeGain(remaining: remaining))
        soundscape.volume = level
        drone.volume = level
        DevotionalSong.setVolume(level)
    }

    private func updateNowPlaying() {
        guard let sound else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: sound == .mySong ? (UserDefaults.standard.string(forKey: DevotionalSong.titleKey) ?? sound.title) : sound.title,
            MPMediaItemPropertyArtist: "Ashtotra · Sleep",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        if let remaining { info[MPMediaItemPropertyPlaybackDuration] = remaining }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setUpRemoteCommands() {
        guard !remoteSetUp else { return }
        remoteSetUp = true
        let center = MPRemoteCommandCenter.shared()
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
    }
}

/// Generates nature sounds, soft noise, an Om drone and temple bells, sample by sample.
final class SoundscapeSynth {
    private let engine = AVAudioEngine()
    private let voice = SoundscapeVoice()
    private var source: AVAudioSourceNode?

    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    func start(_ sound: SleepSound) {
        voice.reset(sound)
        guard source == nil else { return }
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: rate > 0 ? rate : 44_100, channels: 1)!
        voice.sampleRate = format.sampleRate
        let voice = self.voice
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            for frame in 0..<Int(frameCount) { out[frame] = voice.next() }
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func stop() {
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
    }

    /// For tests: render samples without an audio device.
    static func render(_ sound: SleepSound, seconds: Double, sampleRate: Double = 8_000) -> [Float] {
        let voice = SoundscapeVoice()
        voice.sampleRate = sampleRate
        voice.reset(sound)
        return (0..<Int(seconds * sampleRate)).map { _ in voice.next() }
    }
}

/// Render-thread state. Uses a tiny xorshift generator so no allocation happens per sample.
private final class SoundscapeVoice {
    var sampleRate = 44_100.0
    private var sound: SleepSound = .rain
    private var time = 0.0
    private var gain = 0.0
    private var seed: UInt64 = 0x9E37_79B9_7F4A_7C15

    // Noise colouring
    private var pinkState = [Double](repeating: 0, count: 7)
    private var brown = 0.0
    private var low1 = 0.0, low2 = 0.0, high = 0.0
    // Events
    private var dropEnv = 0.0, crackleEnv = 0.0, crackleLow = 0.0
    private var wavePeriod = 9.0, waveStart = 0.0
    private var chirpStart = 0.0, nextChirp = 0.5, chirpPhase = 0.0
    private var phases = [Double](repeating: 0, count: 16)
    private var bellStart = -100.0, nextBell = 1.0
    private let bellRatios = [1.0, 2.0, 2.76, 5.4]
    private let bellAmps = [1.0, 0.5, 0.35, 0.15]

    func reset(_ sound: SleepSound) {
        self.sound = sound
        time = 0
        gain = 0
    }

    func next() -> Float {
        let dt = 1 / sampleRate
        time += dt
        gain += (1 - gain) * min(1, dt / 2.5)   // 2.5 s fade-in
        let sample: Double = switch sound {
        case .whiteNoise: white() * 0.22
        case .pinkNoise: pink() * 0.35
        case .brownNoise: brownNoise() * 0.9
        case .rain: rain()
        case .ocean: ocean()
        case .wind: wind()
        case .forest: crickets()
        case .fireplace: fire()
        case .omChant: om()
        case .templeBells: bells()
        default: 0
        }
        return Float(max(-1, min(1, sample * gain)))
    }

    // MARK: Building blocks

    private func white() -> Double {
        seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
        return Double(seed % 2_000_001) / 1_000_000 - 1
    }

    /// Paul Kellet's pink-noise filter.
    private func pink() -> Double {
        let w = white()
        pinkState[0] = 0.99886 * pinkState[0] + w * 0.0555179
        pinkState[1] = 0.99332 * pinkState[1] + w * 0.0750759
        pinkState[2] = 0.96900 * pinkState[2] + w * 0.1538520
        pinkState[3] = 0.86650 * pinkState[3] + w * 0.3104856
        pinkState[4] = 0.55000 * pinkState[4] + w * 0.5329522
        pinkState[5] = -0.7616 * pinkState[5] - w * 0.0168980
        let out = pinkState.prefix(6).reduce(0, +) + pinkState[6] + w * 0.5362
        pinkState[6] = w * 0.115926
        return out * 0.11
    }

    private func brownNoise() -> Double {
        brown = (brown + 0.02 * white()) / 1.02
        return brown * 3.5
    }

    private func lowpass(_ x: Double, _ state: inout Double, cutoff: Double) -> Double {
        let a = 1 - exp(-2 * .pi * cutoff / sampleRate)
        state += a * (x - state)
        return state
    }

    private func chance(perSecond rate: Double) -> Bool {
        (white() + 1) / 2 < rate / sampleRate
    }

    // MARK: Sounds

    private func rain() -> Double {
        // Steady hiss of distant rain, gently swelling, plus nearby drops.
        let hiss = pink() - lowpass(pink(), &low1, cutoff: 400)
        let swell = 0.75 + 0.25 * sin(time * 0.13) * sin(time * 0.07)
        if chance(perSecond: 35) { dropEnv = 0.4 + 0.6 * (white() + 1) / 2 }
        dropEnv *= exp(-dt(1 / 0.006))
        let drop = dropEnv * lowpass(white(), &low2, cutoff: 2_500)
        return hiss * 0.55 * swell + drop * 0.35
    }

    private func ocean() -> Double {
        if time - waveStart > wavePeriod {
            waveStart = time
            wavePeriod = 7.5 + 4 * (white() + 1) / 2
        }
        let p = (time - waveStart) / wavePeriod
        // Swell up, break, and wash back.
        let envelope = p < 0.55 ? pow(p / 0.55, 1.6) : exp(-(p - 0.55) * 4.5)
        let body = lowpass(brownNoise(), &low1, cutoff: 350 + 1_400 * envelope)
        let foam = lowpass(white(), &low2, cutoff: 3_000) * envelope * envelope * 0.25
        return (body * (0.25 + 0.9 * envelope) + foam) * 0.9
    }

    private func wind() -> Double {
        let gust = 0.55 + 0.45 * sin(time * 0.21 + sin(time * 0.05) * 2)
        let cutoff = 250 + 700 * gust
        let band = lowpass(pink(), &low1, cutoff: cutoff) - lowpass(low1, &low2, cutoff: cutoff * 0.4)
        return band * 2.2 * gust
    }

    private func crickets() -> Double {
        // A soft night bed with crickets chirping in short trills.
        let bed = lowpass(brownNoise(), &low1, cutoff: 300) * 0.25
        if time >= nextChirp {
            chirpStart = time
            nextChirp = time + 0.55 + 0.5 * (white() + 1) / 2
        }
        let t = time - chirpStart
        var chirp = 0.0
        if t < 0.12 {
            let pulses = 0.5 - 0.5 * cos(2 * .pi * 30 * t)   // three quick pulses
            chirpPhase += 2 * .pi * 4_400 / sampleRate
            chirp = sin(chirpPhase) * pulses * sin(.pi * t / 0.12) * 0.12
        }
        return bed + chirp
    }

    private func fire() -> Double {
        let rumble = lowpass(brownNoise(), &low1, cutoff: 180) * 0.9
        if chance(perSecond: 9) { crackleEnv = 0.5 + 0.5 * (white() + 1) / 2 }
        crackleEnv *= exp(-dt(1 / 0.004))
        let crackle = (white() - lowpass(white(), &crackleLow, cutoff: 900)) * crackleEnv * 0.5
        let hiss = (pink() - lowpass(pink(), &low2, cutoff: 1_500)) * 0.05
        return rumble + crackle + hiss
    }

    private func om() -> Double {
        // A low "Ommm" drone on Sa (≈136 Hz): open "O" harmonics swelling into a closed "M" hum,
        // repeating every 8 seconds like slow group chanting.
        let base = 136.1
        let cycle = (time.truncatingRemainder(dividingBy: 8)) / 8
        let breath = cycle < 0.08 ? cycle / 0.08 : cycle > 0.92 ? (1 - cycle) / 0.08 : 1
        let open = cycle < 0.45 ? 1.0 : max(0, 1 - (cycle - 0.45) / 0.25)   // "O" fades into "M"
        var sum = 0.0
        for h in 0..<12 {
            let f = base * Double(h + 1)
            phases[h] += 2 * .pi * f / sampleRate
            if phases[h] > 2 * .pi { phases[h] -= 2 * .pi }
            // Vowel "O" formants near 500 and 850 Hz; the hum keeps only the lowest partials.
            let formant = exp(-pow((f - 500) / 180, 2)) + 0.6 * exp(-pow((f - 850) / 220, 2))
            let weight = (1 / Double(h + 1)) * (1 - open) + formant * open
            sum += sin(phases[h]) * weight
        }
        return sum * 0.22 * breath
    }

    private func bells() -> Double {
        // Distant temple bells over a soft hum.
        let hum = lowpass(brownNoise(), &low1, cutoff: 160) * 0.15
        if time >= nextBell {
            bellStart = time
            nextBell = time + 11 + 9 * (white() + 1) / 2
        }
        let t = time - bellStart
        guard t >= 0, t < 14 else { return hum }
        var bell = 0.0
        for i in 0..<4 {
            phases[i] += 2 * .pi * 523.25 * bellRatios[i] / sampleRate
            if phases[i] > 2 * .pi { phases[i] -= 2 * .pi }
            bell += sin(phases[i]) * bellAmps[i] * exp(-t / (6 / Double(i + 1)))
        }
        return hum + bell * 0.18 * (1 - exp(-t * 300))
    }

    private func dt(_ ratePerSecond: Double) -> Double { ratePerSecond / sampleRate }
}
