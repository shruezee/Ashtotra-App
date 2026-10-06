import Foundation

/// A breathing rhythm, in seconds per phase.
struct BreathPattern: Identifiable, Hashable {
    let id: String
    let name: String
    let inhale: Double
    let hold: Double
    let exhale: Double
    let rest: Double

    var cycle: Double { inhale + hold + exhale + rest }

    var summary: String {
        var parts = ["In \(Int(inhale))"]
        if hold > 0 { parts.append("hold \(Int(hold))") }
        parts.append("out \(Int(exhale))")
        if rest > 0 { parts.append("rest \(Int(rest))") }
        return parts.joined(separator: " · ")
    }

    static let calm = BreathPattern(id: "calm", name: "Calm", inhale: 4, hold: 2, exhale: 6, rest: 0)
    static let balanced = BreathPattern(id: "balanced", name: "Balanced", inhale: 4, hold: 4, exhale: 4, rest: 4)
    static let gentle = BreathPattern(id: "gentle", name: "Gentle", inhale: 4, hold: 0, exhale: 4, rest: 0)
    static let all = [calm, balanced, gentle]

    static func named(_ id: String) -> BreathPattern { all.first { $0.id == id } ?? calm }

    enum Phase: String {
        case inhale = "Breathe in"
        case hold = "Hold"
        case exhale = "Breathe out"
        case rest = "Rest"
    }

    /// Which phase `elapsed` seconds falls in, and how far through it (0…1).
    func phase(at elapsed: Double) -> (phase: Phase, progress: Double) {
        var t = elapsed.truncatingRemainder(dividingBy: cycle)
        for (phase, length) in [(Phase.inhale, inhale), (.hold, hold), (.exhale, exhale), (.rest, rest)] where length > 0 {
            if t < length { return (phase, t / length) }
            t -= length
        }
        return (.inhale, 0)
    }
}

/// What plays while meditating.
enum MeditationSound: String, CaseIterable, Identifiable {
    case tanpura, bowl, silence, myMusic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tanpura: "Tanpura drone"
        case .bowl: "Singing bowl"
        case .silence: "Silence"
        case .myMusic: "My devotional song"
        }
    }

    var symbol: String {
        switch self {
        case .tanpura: "waveform"
        case .bowl: "bell"
        case .silence: "speaker.slash"
        case .myMusic: "music.note"
        }
    }
}

enum MeditationLength {
    static let range = 1...20
    static let defaultMinutes = 2
}
