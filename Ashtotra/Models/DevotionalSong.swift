import AVFoundation
import MediaPlayer
import SwiftUI
import UniformTypeIdentifiers

/// The user's own favourite devotional song for meditation: either a song from their Music
/// library (played by the system music player) or an audio/video file they picked from Files
/// (kept privately inside the app so it works offline). Nothing is ever uploaded.
enum DevotionalSong {
    static let idKey = "meditationSongID"
    static let titleKey = "meditationSongTitle"
    static let sourceKey = "meditationSongSource"
    static let fileKey = "meditationSongFile"

    enum Source: String {
        case music, file
    }

    /// What to play, as saved in settings.
    struct Choice: Equatable {
        var source: Source
        var persistentID: String
        var fileName: String

        var isChosen: Bool {
            switch source {
            case .music: !persistentID.isEmpty
            case .file: !fileName.isEmpty
            }
        }
    }

    /// MP3, M4A, WAV, AIFF and the sound track of MP4/MOV videos.
    static let fileTypes: [UTType] = [.mp3, .mpeg4Audio, .wav, .aiff, .audio, .mpeg4Movie, .quickTimeMovie, .movie]

    /// Private copies of chosen files, so they keep playing after the original moves.
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Devotional songs", isDirectory: true)
    }

    /// Copies a file picked from Files into the app (replacing any earlier one) and returns its stored name.
    static func importFile(from url: URL) throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        for old in (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
            try? fileManager.removeItem(at: old)
        }
        let name = url.lastPathComponent
        try fileManager.copyItem(at: url, to: folder.appendingPathComponent(name))
        return name
    }

    /// A friendly title from a file name: "Om Namah Shivaya.mp3" → "Om Namah Shivaya".
    static func title(forFile name: String) -> String {
        (name as NSString).deletingPathExtension
    }

    @MainActor private static var filePlayer: AVQueuePlayer?
    @MainActor private static var looper: AVPlayerLooper?

    /// Plays the chosen song on repeat. Returns false if it can no longer be found.
    @MainActor
    static func play(_ choice: Choice) -> Bool {
        switch choice.source {
        case .music:
            return play(persistentID: choice.persistentID)
        case .file:
            let url = folder.appendingPathComponent(choice.fileName)
            guard !choice.fileName.isEmpty, FileManager.default.fileExists(atPath: url.path) else { return false }
            let player = AVQueuePlayer()
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            filePlayer = player
            player.play()
            return true
        }
    }

    static var isAuthorized: Bool { MPMediaLibrary.authorizationStatus() == .authorized }

    static func requestAccess() async -> Bool {
        if isAuthorized { return true }
        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    static func item(persistentID: String) -> MPMediaItem? {
        guard let id = UInt64(persistentID) else { return nil }
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: id),
                                                          forProperty: MPMediaItemPropertyPersistentID))
        return query.items?.first
    }

    @MainActor
    static func play(persistentID: String) -> Bool {
        guard let item = item(persistentID: persistentID) else { return false }
        let player = MPMusicPlayerController.applicationQueuePlayer
        player.setQueue(with: MPMediaItemCollection(items: [item]))
        player.repeatMode = .one
        player.play()
        return true
    }

    @MainActor
    static func stop() {
        MPMusicPlayerController.applicationQueuePlayer.stop()
        filePlayer?.pause()
        looper = nil
        filePlayer = nil
    }
}

/// System song picker.
struct SongPicker: UIViewControllerRepresentable {
    var onPick: (MPMediaItem) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = true
        picker.prompt = "Choose a devotional song for meditation"
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let parent: SongPicker
        init(_ parent: SongPicker) { self.parent = parent }

        func mediaPicker(_ picker: MPMediaPickerController, didPickMediaItems collection: MPMediaItemCollection) {
            if let item = collection.items.first { parent.onPick(item) }
            parent.dismiss()
        }

        func mediaPickerDidCancel(_ picker: MPMediaPickerController) {
            parent.dismiss()
        }
    }
}
