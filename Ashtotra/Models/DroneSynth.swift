import AVFoundation

/// Generates calm meditation sounds on the device, so no recordings need to be bundled:
/// a four-string tanpura drone, a singing bowl struck every few breaths, and a closing bell.
final class DroneSynth {
    enum Kind { case tanpura, bowl, none }

    private let engine = AVAudioEngine()
    private let voice = SynthVoice()
    private var source: AVAudioSourceNode?

    /// Overall loudness (used by the sleep timer's fade-out).
    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    func start(_ kind: Kind) {
        voice.kind = kind
        voice.targetGain = kind == .none ? 0 : 1
        guard source == nil else { return }

        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: rate > 0 ? rate : 44_100, channels: 1)!
        voice.sampleRate = format.sampleRate
        let voice = self.voice
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            for frame in 0..<Int(frameCount) {
                out[frame] = voice.nextSample()
            }
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    /// Fades the drone out but keeps the engine running so a bell can still ring.
    func fadeOut() {
        voice.targetGain = 0
    }

    func ringBell() {
        voice.bellStart = voice.time
    }

    func stop() {
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
    }
}

/// Sample-by-sample synthesis state. Touched only from the audio render thread after setup.
private final class SynthVoice {
    var kind: DroneSynth.Kind = .none
    var sampleRate = 44_100.0
    var gain = 0.0
    var targetGain = 0.0
    var time = 0.0
    var bellStart = -100.0

    // Tanpura: Pa, Sa', Sa', low Sa (C tuning), plucked in turn.
    private let strings = [98.00, 130.81, 130.81, 65.41]
    private var lastPluck = [-10.0, -10.0, -10.0, -10.0]
    private var nextString = 0
    private var nextPluckTime = 0.5
    private let pluckGap = 1.25
    private let harmonics: [Double] = [1, 0.55, 0.62, 0.45, 0.38, 0.3, 0.24, 0.18, 0.12, 0.08]
    private var stringPhases = [[Double]](repeating: [Double](repeating: 0, count: 10), count: 4)

    // Singing bowl: inharmonic partials with slow beating.
    private let bowlPartials: [(ratio: Double, amp: Double, decay: Double)] =
        [(1, 1, 14), (2.76, 0.45, 9), (5.40, 0.25, 5), (8.93, 0.1, 3)]
    private var bowlStart = 0.3
    private var bowlPhases = [Double](repeating: 0, count: 8)
    private var bellPhases = [Double](repeating: 0, count: 8)

    func nextSample() -> Float {
        let dt = 1 / sampleRate
        time += dt
        // ~3 second fades in and out.
        gain += (targetGain - gain) * min(1, dt / 1.2)

        var sample = 0.0
        if gain > 0.0005 {
            switch kind {
            case .tanpura: sample = tanpura() * 0.16
            case .bowl: sample = bowl(base: 196, start: &bowlStart, phases: &bowlPhases, every: 16) * 0.22
            case .none: break
            }
            sample *= gain
        }
        if time - bellStart < 12 {
            var start = bellStart
            sample += bowl(base: 293.66, start: &start, phases: &bellPhases, every: nil) * 0.3
        }
        return Float(max(-1, min(1, sample)))
    }

    private func tanpura() -> Double {
        if time >= nextPluckTime {
            lastPluck[nextString] = time
            nextString = (nextString + 1) % strings.count
            nextPluckTime = time + (nextString == 0 ? pluckGap * 1.6 : pluckGap)
        }
        var sum = 0.0
        for s in 0..<strings.count {
            let t = time - lastPluck[s]
            guard t < 8 else { continue }
            let attack = 1 - exp(-t * 60)
            for h in 0..<harmonics.count {
                let k = Double(h + 1)
                // Higher harmonics fade sooner; a slow swell in the middle ones gives the buzzing "jawari".
                let env = exp(-t / (5.0 / (1 + 0.18 * k))) * (1 + 0.35 * sin(t * 1.7 + k))
                stringPhases[s][h] += 2 * .pi * strings[s] * k / sampleRate
                if stringPhases[s][h] > 2 * .pi { stringPhases[s][h] -= 2 * .pi }
                sum += harmonics[h] * env * attack * sin(stringPhases[s][h])
            }
        }
        return sum
    }

    private func bowl(base: Double, start: inout Double, phases: inout [Double], every interval: Double?) -> Double {
        if let interval, time - start > interval { start = time }
        let t = time - start
        guard t >= 0 else { return 0 }
        let attack = 1 - exp(-t * 200)
        var sum = 0.0
        for (i, partial) in bowlPartials.enumerated() {
            let env = partial.amp * exp(-t / partial.decay) * attack
            for j in 0..<2 {
                let detune = j == 0 ? 0.0 : 0.6
                let index = i * 2 + j
                phases[index] += 2 * .pi * (base * partial.ratio + detune) / sampleRate
                if phases[index] > 2 * .pi { phases[index] -= 2 * .pi }
                sum += env * 0.5 * sin(phases[index])
            }
        }
        return sum
    }
}
