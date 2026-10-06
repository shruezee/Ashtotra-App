import AVFoundation
import Observation

/// Reads lines aloud with the device's Hindi voice, one after another, and reports
/// which line is being spoken so screens can highlight and follow along.
@MainActor
@Observable
final class Reciter: NSObject {
    private(set) var isPlaying = false
    private(set) var currentIndex: Int?
    /// Set when the last line has been spoken.
    private(set) var finishedToken = 0
    /// Identifies who started the current recitation (a prayer id or names id).
    private(set) var owner: String?

    private var lines: [String] = []
    private let synthesizer = AVSpeechSynthesizer()

    /// 0.5 is a calm chanting pace; 1.0 is the system's normal reading speed.
    var pace: Double {
        get { UserDefaults.standard.object(forKey: "recitePace") as? Double ?? 0.8 }
        set { UserDefaults.standard.set(newValue, forKey: "recitePace") }
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    static var hasVoice: Bool { voice != nil }

    private static var voice: AVSpeechSynthesisVoice? {
        let hindi = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "hi-IN" }
        return hindi.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "hi-IN")
    }

    func isPlaying(_ owner: String) -> Bool {
        isPlaying && self.owner == owner
    }

    /// Start reading `lines` (Devanagari) from `index`.
    func play(_ lines: [String], from index: Int = 0, owner: String) {
        stop()
        guard lines.indices.contains(index) else { return }
        self.lines = lines
        self.owner = owner
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        isPlaying = true
        speak(at: index)
    }

    func stop() {
        isPlaying = false
        currentIndex = nil
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func speak(at index: Int) {
        currentIndex = index
        let utterance = AVSpeechUtterance(string: Self.speakable(lines[index]))
        utterance.voice = Self.voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(pace)
        utterance.postUtteranceDelay = 0.35
        synthesizer.speak(utterance)
    }

    private func advance() {
        guard isPlaying, let index = currentIndex else { return }
        if index + 1 < lines.count {
            speak(at: index + 1)
        } else {
            stop()
            finishedToken += 1
        }
    }

    /// Makes text friendlier for a Hindi voice: the Om sign and verse marks are not spoken well.
    nonisolated static func speakable(_ text: String) -> String {
        text.replacingOccurrences(of: "ॐ", with: "ओम्")
            .replacingOccurrences(of: "ऽ", with: "")
            .replacingOccurrences(of: "॥", with: "।")
    }
}

extension Reciter: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.advance() }
    }
}
