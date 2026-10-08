import GroupActivities
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Start screen

/// Explains satsang, starts it (FaceTime or Messages), and handles the host purchase.
struct SatsangStartView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SatsangSession.self) private var satsang
    @Environment(SatsangStore.self) private var store
    @State private var showPaywall = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("🪔").font(.system(size: 56)).accessibilityHidden(true)
                    Text("Satsang together")
                        .font(.largeTitle.weight(.bold))
                    Text("Pray with family and friends wherever they are. Start a FaceTime call or Messages chat, and everyone's Ashtotra follows yours: the same prayer and verse, the same chant bead, a YouTube bhajan or video in sync, and PDFs or photos turned page by page.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Point(symbol: "person.2.fill", text: "Anyone with Ashtotra can join for free.")
                        Point(symbol: "crown.fill", text: "The host leads: chooses what to show, moves the verse, plays and pauses.")
                        Point(symbol: "speaker.slash.fill", text: "Mute a video for everyone else so the group can chant over it.")
                        Point(symbol: "lock.fill", text: "Private: it runs through FaceTime and Messages. Nothing goes to our servers.")
                    }
                    .padding(16)
                    .background(Theme.card, in: .rect(cornerRadius: 20))

                    if satsang.isEligibleInCall {
                        Button {
                            start(inCall: true)
                        } label: {
                            Label("Start satsang in this FaceTime call", systemImage: "shareplay")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.saffron)
                    }
                    Button {
                        start(inCall: false)
                    } label: {
                        Label(satsang.isEligibleInCall ? "Invite with Messages or FaceTime" : "Start satsang", systemImage: "person.2.wave.2.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(satsang.isEligibleInCall ? .secondary : Theme.saffron)

                    hostStatus

                    Text("To join a satsang someone else started, just tap Join when it appears in your FaceTime call or Messages chat.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { SatsangPaywall() }
            .sheet(isPresented: $showShareSheet) {
                ActivitySharingSheet { satsang.prepareToHost() }
                    .ignoresSafeArea()
            }
            .onChange(of: satsang.isActive) { _, active in if active { dismiss() } }
        }
    }

    @ViewBuilder
    private var hostStatus: some View {
        if store.isUnlocked {
            Label("You're a Satsang Host. Thank you! 🙏", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        } else if !store.freeSatsangUsed {
            Label("Your first satsang as host is free.", systemImage: "gift.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.saffron)
        } else {
            Button {
                showPaywall = true
            } label: {
                Label("Become a Satsang Host", systemImage: "crown.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Theme.saffron)
        }
    }

    private func start(inCall: Bool) {
        guard store.canHost else {
            showPaywall = true
            return
        }
        if inCall {
            Task { _ = await satsang.startInCall() }
        } else {
            showShareSheet = true
        }
    }

    private struct Point: View {
        let symbol: String
        let text: String
        var body: some View {
            Label {
                Text(text)
            } icon: {
                Image(systemName: symbol).foregroundStyle(Theme.saffron)
            }
            .font(.callout)
        }
    }
}

/// The system sheet for inviting people to SharePlay through Messages or FaceTime.
private struct ActivitySharingSheet: UIViewControllerRepresentable {
    let willShare: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        willShare()
        return (try? GroupActivitySharingController(SatsangActivity())) ?? UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}

// MARK: - Paywall

struct SatsangPaywall: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SatsangStore.self) private var store

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "crown.fill").font(.system(size: 56)).foregroundStyle(Theme.saffron)
                Text("Become a Satsang Host").font(.title.weight(.bold))
                Text("Lead satsangs over FaceTime and Messages as often as you like: prayers, chanting, YouTube, videos, PDFs and photos, in sync for everyone.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Label("One-time purchase, yours forever", systemImage: "checkmark.circle.fill")
                    Label("Shared with your Family Sharing group", systemImage: "checkmark.circle.fill")
                    Label("Joining is always free for everyone", systemImage: "checkmark.circle.fill")
                    Label("Supports an ad-free, private app", systemImage: "checkmark.circle.fill")
                }
                .font(.callout)
                .foregroundStyle(.primary)
                Spacer()
                Button {
                    Task {
                        await store.purchase()
                        if store.isUnlocked { dismiss() }
                    }
                } label: {
                    Group {
                        if store.isPurchasing {
                            ProgressView()
                        } else {
                            Text(store.product.map { "Unlock for \($0.displayPrice)" } ?? "Unlock")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.saffron)
                .disabled(store.isPurchasing)
                Button("Restore purchase") { Task { await store.restore() } }
                    .font(.subheadline)
                if let message = store.message {
                    Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
            .onDisappear { store.clearMessage() }
        }
    }
}

// MARK: - The room

/// What everyone sees during a satsang. The host gets controls; others follow.
struct SatsangRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SatsangSession.self) private var satsang
    @Environment(SatsangStore.self) private var store
    @AppStorage("script") private var script: Script = .simple
    @State private var localMuted = false
    @State private var choosing = false
    @State private var showPaywall = false

    private let book = PrayerBook.shared
    private let library = Library.shared

    var body: some View {
        let state = satsang.state
        NavigationStack {
            VStack(spacing: 0) {
                statusBar
                content(state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if satsang.isHost { hostControls(state) } else if state.content.isPlayable { followerMediaBar }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title(for: state.content))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        if satsang.isHost {
                            Button(role: .destructive) { satsang.endForEveryone(); dismiss() } label: {
                                Label("End satsang for everyone", systemImage: "xmark.circle")
                            }
                        }
                        Button { satsang.leave(); dismiss() } label: { Label("Leave satsang", systemImage: "rectangle.portrait.and.arrow.right") }
                    } label: {
                        Label("Leave", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ScriptMenu(script: $script)
                }
            }
            .sheet(isPresented: $choosing) { SatsangChooser() }
            .sheet(isPresented: $showPaywall) { SatsangPaywall() }
            .alert("Satsang", isPresented: Binding(get: { satsang.lastError != nil }, set: { if !$0 { satsang.clearError() } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(satsang.lastError ?? "")
            }
            .onChange(of: satsang.isActive) { _, active in if !active { dismiss() } }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    // MARK: Status

    private var statusBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "shareplay").foregroundStyle(Theme.saffron)
            Text("\(satsang.participantCount) in satsang").font(.subheadline.weight(.semibold))
            Spacer()
            if satsang.isHost {
                Label("You're the host", systemImage: "crown.fill").font(.footnote.weight(.semibold)).foregroundStyle(Theme.saffron)
            } else if satsang.hostIsPresent {
                Text("Following the host").font(.footnote).foregroundStyle(.secondary)
            } else if satsang.state.hostID != nil {
                Button("Host left. Lead now") {
                    if store.canHost { satsang.claimHost(); store.spendFreeSatsangIfNeeded() } else { showPaywall = true }
                }
                .font(.footnote.weight(.semibold))
            } else {
                Text("Waiting for the host…").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .accessibilityElement(children: .combine)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ state: SatsangState) -> some View {
        switch state.content {
        case .welcome:
            VStack(spacing: 14) {
                Text("🙏").font(.system(size: 64)).accessibilityHidden(true)
                Text(satsang.isHost ? "Choose what to share" : "Welcome to the satsang")
                    .font(.title2.weight(.bold))
                Text(satsang.isHost ? "Tap Share below to pick a prayer, the 108 names, a YouTube link, a video, a PDF or a photo."
                                    : "The host will share a prayer or video in a moment.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
        case .prayer(let id):
            if let prayer = book.prayer(id: id) { SatsangPrayerView(prayer: prayer, script: script) }
        case .names(let id):
            if let collection = library.collection(id: id) { SatsangNamesView(collection: collection, script: script) }
        case .youtube(let videoID):
            YouTubePlayerView(videoID: videoID, state: state, isHost: satsang.isHost, localMuted: localMuted) { playing, time in
                satsang.updateMedia(playing: playing, time: time)
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 12))
            .padding()
            .id(videoID)
        case .video(let attachment, _):
            if let url = satsang.files[attachment] {
                SyncedVideoView(url: url, state: state, isHost: satsang.isHost, localMuted: localMuted) { playing, time in
                    satsang.updateMedia(playing: playing, time: time)
                }
                .id(attachment)
            } else {
                loading("Receiving the video…")
            }
        case .pdf(let attachment, _):
            if let url = satsang.files[attachment] {
                SyncedPDFView(url: url, page: state.position, isHost: satsang.isHost) { satsang.setPosition($0) }
                    .id(attachment)
            } else {
                loading("Receiving the PDF…")
            }
        case .image(let attachment, _):
            if let url = satsang.files[attachment], let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit().padding()
                    .accessibilityLabel("Shared photo")
            } else {
                loading("Receiving the photo…")
            }
        }
    }

    private func loading(_ text: String) -> some View {
        VStack(spacing: 12) { ProgressView(); Text(text).foregroundStyle(.secondary) }
    }

    // MARK: Host controls

    private func hostControls(_ state: SatsangState) -> some View {
        VStack(spacing: 10) {
            if case .prayer(let id) = state.content, let prayer = book.prayer(id: id) {
                let verse = prayer.verses[min(state.position, prayer.verses.count - 1)]
                let numbered = prayer.verses.compactMap(\.number).count
                let label = verse.number.map { "Verse \($0) of \(numbered)" } ?? verse.label ?? "Verse"
                stepper(position: state.position, count: prayer.verses.count, label: label, noun: "verse")
            }
            if case .names = state.content {
                stepper(position: state.position, count: 108, label: "Name \(state.position + 1) of 108", noun: "name")
            }
            HStack(spacing: 12) {
                Button {
                    choosing = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up.on.square.fill")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.saffron)
                if state.content.isPlayable {
                    Button {
                        satsang.setMutedForOthers(!state.mediaMutedForOthers)
                    } label: {
                        Label(state.mediaMutedForOthers ? "Unmute for all" : "Mute for others",
                              systemImage: state.mediaMutedForOthers ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.saffron)
                }
            }
            .font(.headline)
        }
        .padding(16)
        .background(.thinMaterial)
    }

    private func stepper(position: Int, count: Int, label: String, noun: String) -> some View {
        HStack(spacing: 12) {
            Button { satsang.setPosition(position - 1) } label: {
                Image(systemName: "chevron.left").frame(width: 56, height: 52)
            }
            .buttonStyle(.bordered)
            .disabled(position == 0)
            .accessibilityLabel("Previous \(noun)")
            Text(label)
                .font(.headline.monospacedDigit())
                .frame(maxWidth: .infinity)
            Button { satsang.setPosition(min(position + 1, count - 1)) } label: {
                Image(systemName: "chevron.right").frame(width: 56, height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.saffron)
            .disabled(position >= count - 1)
            .accessibilityLabel("Next \(noun)")
        }
    }

    private var followerMediaBar: some View {
        HStack {
            if satsang.state.mediaMutedForOthers {
                Label("The host has muted the video so everyone can chant", systemImage: "speaker.slash.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(isOn: $localMuted) { Label("Mute on my phone", systemImage: "speaker.slash") }
                .toggleStyle(.button)
                .font(.footnote.weight(.semibold))
        }
        .padding(16)
        .background(.thinMaterial)
    }

    private func title(for content: SatsangContent) -> String {
        switch content {
        case .welcome: "Satsang"
        case .prayer(let id): book.prayer(id: id)?.title ?? "Prayer"
        case .names(let id): library.collection(id: id).map { "108 names of \($0.title)" } ?? "108 names"
        case .youtube: "YouTube"
        case .video(_, let title), .pdf(_, let title), .image(_, let title): title
        }
    }
}

/// A prayer with the host's current verse highlighted and centred.
private struct SatsangPrayerView: View {
    @Environment(SatsangSession.self) private var satsang
    let prayer: Prayer
    let script: Script
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 22

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(prayer.verses.enumerated()), id: \.offset) { index, verse in
                        VerseView(verse: verse, script: script, fontSize: size, tint: Theme.textTint(for: prayer),
                                  highlighted: index == satsang.state.position)
                            .id(index)
                            .onTapGesture { satsang.setPosition(index) }
                    }
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: satsang.state.position) { _, position in
                withAnimation { proxy.scrollTo(position, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(satsang.state.position, anchor: .center) }
        }
    }
}

/// The 108-name chant ring, moved by the host.
private struct SatsangNamesView: View {
    @Environment(SatsangSession.self) private var satsang
    let collection: NameCollection
    let script: Script
    private let library = Library.shared

    var body: some View {
        let index = min(max(satsang.state.position, 0), 107)
        ZStack {
            Theme.gradient(for: collection).ignoresSafeArea()
            BeadRing(count: 108, done: index + 1).padding(24).accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(library.om[script.rawValue] ?? "Om", script: script).font(.system(size: 36, weight: .semibold)).opacity(0.85)
                Text(collection.names[index].text(in: script), script: script)
                    .font(.largeTitle.weight(.bold)).multilineTextAlignment(.center).minimumScaleFactor(0.5)
                Text(library.namah[script.rawValue] ?? "namaha", script: script).font(.title2).opacity(0.85)
            }
            .padding(.horizontal, 56)
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
        .contentShape(.rect)
        .onTapGesture { satsang.setPosition(min(index + 1, 107)) }
    }
}

// MARK: - Choosing what to share (host)

struct SatsangChooser: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SatsangSession.self) private var satsang
    @State private var youtubeText = ""
    @State private var showFiles = false
    @State private var photoItem: PhotosPickerItem?
    @State private var sharing = false
    private let book = PrayerBook.shared
    private let library = Library.shared

    var body: some View {
        NavigationStack {
            List {
                Section("YouTube") {
                    TextField("Paste a YouTube link", text: $youtubeText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button("Play for everyone") {
                        if let id = YouTubeLink.videoID(from: youtubeText) { satsang.show(.youtube(videoID: id)); dismiss() }
                    }
                    .disabled(YouTubeLink.videoID(from: youtubeText) == nil)
                    if let pasted = UIPasteboard.general.string, YouTubeLink.videoID(from: pasted) != nil, youtubeText.isEmpty {
                        Button("Use the link you copied") { youtubeText = pasted }
                    }
                }
                Section("From your phone") {
                    PhotosPicker(selection: $photoItem, matching: .any(of: [.videos, .images])) {
                        Label("Video or photo", systemImage: "photo.on.rectangle")
                    }
                    Button { showFiles = true } label: { Label("PDF, video or image from Files", systemImage: "folder") }
                    if sharing { HStack { ProgressView(); Text("Sharing with everyone…") } }
                }
                Section("Prayers") {
                    ForEach(book.prayers.filter { $0.kind != .mantra }) { prayer in
                        Button(prayer.title) { satsang.show(.prayer(id: prayer.id)); dismiss() }
                    }
                }
                Section("108 names") {
                    ForEach(library.collections) { collection in
                        Button(collection.title) { satsang.show(.names(id: collection.id)); dismiss() }
                    }
                }
                Section("Daily mantras") {
                    ForEach(book.prayers(of: .mantra)) { prayer in
                        Button(prayer.title) { satsang.show(.prayer(id: prayer.id)); dismiss() }
                    }
                }
            }
            .navigationTitle("Share with everyone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .movie, .image]) { result in
                guard case .success(let url) = result else { return }
                Task { await shareFile(at: url, securityScoped: true) }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    sharing = true
                    defer { sharing = false }
                    if let file = try? await item.loadTransferable(type: PickedFile.self) {
                        await shareFile(at: file.url, securityScoped: false)
                    }
                }
            }
        }
    }

    private func shareFile(at url: URL, securityScoped: Bool) async {
        sharing = true
        defer { sharing = false }
        let accessing = securityScoped && url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        // Copy into our own folder so the file stays readable for the whole satsang.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("satsang", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        guard (try? FileManager.default.copyItem(at: url, to: copy)) != nil else { return }
        await satsang.share(fileAt: copy)
        dismiss()
    }
}

/// A video or image picked from Photos, delivered as a file.
private struct PickedFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in try copy(received.file) }
        FileRepresentation(importedContentType: .image) { received in try copy(received.file) }
    }

    private static func copy(_ file: URL) throws -> PickedFile {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + file.lastPathComponent)
        try FileManager.default.copyItem(at: file, to: destination)
        return PickedFile(url: destination)
    }
}
