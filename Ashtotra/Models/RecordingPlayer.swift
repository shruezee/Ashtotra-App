import AVFoundation
import Observation

/// Plays a recording bundled with the app (an mp3 named after a prayer's `audio` key).
@MainActor
@Observable
final class RecordingPlayer: NSObject {
    private(set) var isPlaying = false
    private var player: AVAudioPlayer?

    func play(_ name: String) {
        stop()
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.delegate = self
        self.player = player
        isPlaying = player.play()
    }

    func stop() {
        player?.stop()
        player = nil
        guard isPlaying else { return }
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension RecordingPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
