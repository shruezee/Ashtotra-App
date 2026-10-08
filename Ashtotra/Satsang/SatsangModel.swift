import CoreTransferable
import Foundation
import GroupActivities
import UniformTypeIdentifiers

/// "Satsang on Ashtotra": everyone in a FaceTime call or Messages group follows the same prayer,
/// video, PDF or image, led by one host.
struct SatsangActivity: GroupActivity {
    static let activityIdentifier = "com.shruezee.ashtotra.satsang"

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Satsang on Ashtotra"
        metadata.subtitle = "Chant and pray together"
        metadata.type = .generic
        metadata.fallbackURL = URL(string: "https://shruezee.github.io/Ashtotra-App/")
        return metadata
    }
}

/// What everyone is looking at.
enum SatsangContent: Codable, Hashable {
    case welcome
    case prayer(id: String)
    case names(id: String)
    case youtube(videoID: String)
    case video(attachment: UUID, title: String)
    case pdf(attachment: UUID, title: String)
    case image(attachment: UUID, title: String)

    var isPlayable: Bool {
        switch self {
        case .youtube, .video: true
        default: false
        }
    }

    var attachmentID: UUID? {
        switch self {
        case .video(let id, _), .pdf(let id, _), .image(let id, _): id
        default: nil
        }
    }
}

/// The host's view of the satsang, mirrored on every device.
struct SatsangState: Codable, Equatable {
    /// `Participant.id` of the host. Only the host's updates are followed.
    var hostID: UUID?
    var content: SatsangContent = .welcome
    /// Verse index, name index, or PDF page, depending on `content`.
    var position = 0
    var mediaPlaying = false
    /// Media position in seconds at `mediaUpdatedAt`.
    var mediaTime: Double = 0
    var mediaUpdatedAt = Date(timeIntervalSince1970: 0)
    /// When true, everyone except the host hears the video silently (so the group can chant over it).
    var mediaMutedForOthers = false
    /// Increases with every host change so stale messages are ignored.
    var revision = 0

    /// Where the media should be now, allowing for time since the host's last update.
    func expectedMediaTime(at now: Date = .now) -> Double {
        guard mediaPlaying else { return mediaTime }
        return mediaTime + max(0, now.timeIntervalSince(mediaUpdatedAt))
    }
}

enum SatsangMessage: Codable {
    case state(SatsangState)
    case requestState
}

/// Pure decisions about who leads, kept separate so they can be tested without SharePlay.
enum SatsangRules {
    /// Follow an incoming state only if it comes from the current host, or the host seat is empty
    /// (nobody leads yet, or the host has left the call) and the sender is claiming it.
    static func accepts(_ incoming: SatsangState, from sender: UUID, current: SatsangState, present: Set<UUID>) -> Bool {
        guard incoming.hostID == sender else { return false }
        if let host = current.hostID, host == sender {
            return incoming.revision > current.revision
        }
        return current.hostID == nil || !present.contains(current.hostID!)
    }

    /// How far a follower may drift from the host before jumping to catch up.
    static let driftTolerance: Double = 1.5

    static func needsSeek(local: Double, expected: Double) -> Bool {
        abs(local - expected) > driftTolerance
    }
}

/// Extracts the video ID from the forms of YouTube link people paste.
enum YouTubeLink {
    static func videoID(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidID(trimmed) { return trimmed }
        guard let url = URL(string: trimmed.hasPrefix("http") ? trimmed : "https://" + trimmed),
              let host = url.host?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        var candidate: String?
        if host.hasSuffix("youtu.be") {
            candidate = parts.first
        } else if host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com") {
            if let v = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value {
                candidate = v
            } else if let index = parts.firstIndex(where: { ["embed", "shorts", "live", "v"].contains($0) }), index + 1 < parts.count {
                candidate = parts[index + 1]
            }
        }
        return candidate.flatMap { isValidID($0) ? $0 : nil }
    }

    private static func isValidID(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}

/// A file shared into the satsang (video, PDF or image). Travels through the SharePlay journal.
struct SatsangFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .data) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("satsang", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(UUID().uuidString + "-" + received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return SatsangFile(url: destination)
        }
    }
}

/// Describes a shared file so everyone shows it the right way.
struct SatsangFileInfo: Codable {
    enum Kind: String, Codable { case video, pdf, image }
    let kind: Kind
    let title: String

    static func kind(for url: URL) -> Kind? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .image) { return .image }
        return nil
    }
}
