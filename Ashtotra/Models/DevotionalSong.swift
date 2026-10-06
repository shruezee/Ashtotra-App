import MediaPlayer
import SwiftUI

/// The user's own favourite devotional song, chosen from their Music library and
/// played through the system music player. Ashtotra never copies or uploads it.
enum DevotionalSong {
    static let idKey = "meditationSongID"
    static let titleKey = "meditationSongTitle"

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
