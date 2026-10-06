import CoreHaptics

/// A vibration you can follow with your eyes closed: it swells as you breathe in,
/// stays still while you hold, and fades away as you breathe out.
final class BreathHaptics {
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    static var isSupported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    func prepare() {
        guard Self.isSupported, engine == nil else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = false
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }

    func play(_ phase: BreathPattern.Phase, duration: Double) {
        guard let engine, duration > 0 else { return }
        try? player?.stop(atTime: CHHapticTimeImmediate)

        let (from, to): (Float, Float) = switch phase {
        case .inhale: (0.08, 0.75)
        case .exhale: (0.6, 0.0)
        case .hold, .rest: (0, 0)
        }
        // A soft tap marks the start of each phase, even the still ones.
        var events = [CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: phase == .inhale ? 0.45 : 0.25),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
        ], relativeTime: 0)]
        var curves: [CHHapticParameterCurve] = []
        if max(from, to) > 0 {
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12),
            ], relativeTime: 0, duration: duration))
            curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: from),
                .init(relativeTime: duration, value: to),
            ], relativeTime: 0))
        }
        guard let pattern = try? CHHapticPattern(events: events, parameterCurves: curves) else { return }
        player = try? engine.makePlayer(with: pattern)
        try? player?.start(atTime: CHHapticTimeImmediate)
    }

    func success() {
        guard let engine,
              let pattern = try? CHHapticPattern(events: [0, 0.25, 0.5].map {
                  CHHapticEvent(eventType: .hapticTransient, parameters: [
                      CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                      CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                  ], relativeTime: $0)
              }, parameters: []) else { return }
        try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        engine?.stop()
        engine = nil
    }
}
