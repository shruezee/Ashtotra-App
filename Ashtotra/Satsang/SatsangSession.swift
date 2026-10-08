import Combine
import Foundation
import GroupActivities
import Observation

/// Runs a SharePlay satsang: joins sessions, keeps everyone on the host's state, and shares files.
@MainActor
@Observable
final class SatsangSession {
    private(set) var state = SatsangState()
    private(set) var isActive = false
    private(set) var participantCount = 0
    private(set) var localID: UUID?
    /// Shared files, loaded and ready to show.
    private(set) var files: [UUID: URL] = [:]
    private(set) var lastError: String?
    /// Chat lines, newest last (kept to the most recent 200).
    private(set) var chat: [SatsangChat] = []
    /// Messages the user hasn't seen because the chat panel was closed.
    private(set) var unreadChat = 0
    var isChatOpen = false { didSet { if isChatOpen { unreadChat = 0 } } }
    /// Reactions to float across the screen.
    private(set) var reactions: [FloatingReaction] = []
    /// Becomes true when a satsang this device hosted has ended (used to offer the host purchase).
    private(set) var finishedHosting = false
    func acknowledgeFinishedHosting() { finishedHosting = false }

    /// People whose messages this user has chosen to hide.
    private(set) var hiddenSenders = Set<UUID>()

    struct FloatingReaction: Identifiable, Equatable {
        let id = UUID()
        let reaction: SatsangReaction
        let lane: Double
    }

    /// True while the device is in a FaceTime call where SharePlay can start directly.
    private(set) var isEligibleInCall = false

    var isHost: Bool { localID != nil && state.hostID == localID }
    var hostIsPresent: Bool { state.hostID.map { presentIDs.contains($0) } ?? false }

    @ObservationIgnored private var session: GroupSession<SatsangActivity>?
    @ObservationIgnored private var messenger: GroupSessionMessenger?
    @ObservationIgnored private var journal: GroupSessionJournal?
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var presentIDs = Set<UUID>()
    @ObservationIgnored private var wantsToHost = false
    @ObservationIgnored private let observer = GroupStateObserver()
    /// Called once when this device becomes host (used to spend the free satsang).
    @ObservationIgnored var onBecameHost: (() -> Void)?

    init() {
        isEligibleInCall = observer.isEligibleForGroupSession
        observer.$isEligibleForGroupSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isEligibleInCall = $0 }
            .store(in: &subscriptions)
        Task { [weak self] in
            for await session in SatsangActivity.sessions() {
                self?.configure(session)
            }
        }
    }

    // MARK: Starting and leaving

    /// Start inside the current FaceTime call. Returns false if SharePlay couldn't start.
    func startInCall() async -> Bool {
        wantsToHost = true
        do {
            return try await SatsangActivity().activate()
        } catch {
            wantsToHost = false
            lastError = "SharePlay couldn't start. Make sure you're in a FaceTime call."
            return false
        }
    }

    /// Mark that the next session (started from the share sheet) is ours to lead.
    func prepareToHost() { wantsToHost = true }

    func leave() {
        session?.leave()
        reset()
    }

    /// Host only: end the satsang for everyone.
    func endForEveryone() {
        session?.end()
        reset()
    }

    /// Lead the satsang if the host has left.
    func claimHost() {
        guard let localID, !hostIsPresent else { return }
        state.hostID = localID
        broadcast()
        onBecameHost?()
    }

    // MARK: Host actions

    func show(_ content: SatsangContent) {
        guard isHost else { return }
        state.content = content
        state.position = 0
        state.mediaPlaying = false
        state.mediaTime = 0
        state.mediaUpdatedAt = .now
        broadcast()
    }

    func setPosition(_ position: Int) {
        guard isHost, position != state.position, position >= 0 else { return }
        state.position = position
        broadcast()
    }

    /// Host reports what its player is doing; followers match it.
    func updateMedia(playing: Bool, time: Double) {
        guard isHost else { return }
        state.mediaPlaying = playing
        state.mediaTime = max(0, time)
        state.mediaUpdatedAt = .now
        broadcast()
    }

    func setMutedForOthers(_ muted: Bool) {
        guard isHost else { return }
        state.mediaMutedForOthers = muted
        broadcast()
    }

    /// Share a file from this device. Shows it to everyone once it's in the journal.
    func share(fileAt url: URL) async {
        guard isHost, let journal, let kind = SatsangFileInfo.kind(for: url) else {
            lastError = "That file type can't be shared. Use a video, PDF or image."
            return
        }
        let title = url.deletingPathExtension().lastPathComponent
        do {
            let attachment = try await journal.add(SatsangFile(url: url), metadata: SatsangFileInfo(kind: kind, title: title))
            files[attachment.id] = url
            switch kind {
            case .video: show(.video(attachment: attachment.id, title: title))
            case .pdf: show(.pdf(attachment: attachment.id, title: title))
            case .image: show(.image(attachment: attachment.id, title: title))
            }
        } catch {
            lastError = "Couldn't share that file. Very large videos may be too big; try a YouTube link instead."
        }
    }

    func clearError() { lastError = nil }

    // MARK: Chat

    func sendChat(_ text: String, name: String) {
        guard let localID, let cleaned = SatsangRules.cleaned(text) else { return }
        guard state.chatEnabled || isHost else {
            lastError = "The host has paused chat for now."
            return
        }
        let line = SatsangChat(senderID: localID, senderName: name.isEmpty ? "Guest" : name, text: cleaned)
        append(line)
        send(.chat(line), to: .all)
    }

    func react(_ reaction: SatsangReaction) {
        float(reaction)
        send(.reaction(reaction), to: .all)
    }

    /// Host only: pause or resume chat for everyone.
    func setChatEnabled(_ enabled: Bool) {
        guard isHost else { return }
        state.chatEnabled = enabled
        broadcast()
    }

    /// Host only: remove a message for everyone.
    func removeChat(_ id: UUID) {
        guard isHost else { return }
        chat.removeAll { $0.id == id }
        send(.removeChat(id), to: .all)
    }

    /// Hide everything from one person, on this device only.
    func hideMessages(from sender: UUID) {
        guard sender != localID else { return }
        hiddenSenders.insert(sender)
        chat.removeAll { $0.senderID == sender }
    }

    func isFromMe(_ line: SatsangChat) -> Bool { line.senderID == localID }
    func isFromHost(_ line: SatsangChat) -> Bool { line.senderID == state.hostID }

    private func append(_ line: SatsangChat) {
        chat.append(line)
        if chat.count > 200 { chat.removeFirst(chat.count - 200) }
        if !isChatOpen && !isFromMe(line) { unreadChat += 1 }
    }

    private func float(_ reaction: SatsangReaction) {
        let item = FloatingReaction(reaction: reaction, lane: .random(in: 0.15...0.85))
        reactions.append(item)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.reactions.removeAll { $0.id == item.id }
        }
    }

    #if DEBUG
    /// Screenshot and layout checks without a FaceTime call.
    func debugSimulate(asHost: Bool, content: SatsangContent, position: Int = 0, people: Int = 5) {
        let me = UUID()
        localID = me
        presentIDs = [me, UUID()]
        participantCount = people
        let hostID = asHost ? me : presentIDs.first { $0 != me }!
        state = SatsangState(hostID: hostID, content: content, position: position)
        chat = [
            SatsangChat(senderID: hostID, senderName: asHost ? "Shruthi" : "Lakshmi aunty", text: "Welcome everyone 🙏 We'll start with the Hanuman Chalisa."),
            SatsangChat(senderID: UUID(), senderName: "Ravi", text: "Jai Shri Ram! Joining from Melbourne 🌸"),
            SatsangChat(senderID: me, senderName: "Me", text: "Namaste 🙏 ready when you are"),
        ]
        unreadChat = asHost ? 0 : 2
        isActive = true
    }
    #endif

    // MARK: Session plumbing

    private func configure(_ session: GroupSession<SatsangActivity>) {
        reset()
        self.session = session
        let messenger = GroupSessionMessenger(session: session, deliveryMode: .reliable)
        let journal = GroupSessionJournal(session: session)
        self.messenger = messenger
        self.journal = journal
        localID = session.localParticipant.id
        isActive = true

        session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if case .invalidated = state { self?.reset() }
            }
            .store(in: &subscriptions)

        session.$activeParticipants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participants in
                guard let self else { return }
                let newcomers = participants.filter { !self.presentIDs.contains($0.id) }
                self.presentIDs = Set(participants.map(\.id))
                self.participantCount = participants.count
                // Bring late joiners up to date.
                if self.isHost, !newcomers.isEmpty {
                    self.send(.state(self.state), to: .only(newcomers))
                }
            }
            .store(in: &subscriptions)

        tasks.append(Task { [weak self] in
            for await (message, context) in messenger.messages(of: SatsangMessage.self) {
                self?.handle(message, from: context.source)
            }
        })

        tasks.append(Task { [weak self] in
            for await attachments in journal.attachments {
                for attachment in attachments where self?.files[attachment.id] == nil {
                    if let file = try? await attachment.load(SatsangFile.self) {
                        self?.files[attachment.id] = file.url
                    }
                }
            }
        })

        session.join()

        if wantsToHost {
            wantsToHost = false
            state.hostID = session.localParticipant.id
            broadcast()
            onBecameHost?()
        } else {
            send(.requestState, to: .all)
        }
    }

    private func handle(_ message: SatsangMessage, from sender: Participant) {
        switch message {
        case .state(let incoming):
            if SatsangRules.accepts(incoming, from: sender.id, current: state, present: presentIDs) {
                state = incoming
            }
        case .requestState:
            if isHost { send(.state(state), to: .only(sender)) }
        case .chat(let line):
            if SatsangRules.acceptsChat(line, from: sender.id, state: state, hidden: hiddenSenders) { append(line) }
        case .reaction(let reaction):
            if !hiddenSenders.contains(sender.id) { float(reaction) }
        case .removeChat(let id):
            if SatsangRules.acceptsRemoval(from: sender.id, state: state) { chat.removeAll { $0.id == id } }
        }
    }

    private func broadcast() {
        state.revision += 1
        send(.state(state), to: .all)
    }

    private func send(_ message: SatsangMessage, to participants: Participants) {
        guard let messenger else { return }
        Task {
            try? await messenger.send(message, to: participants)
        }
    }

    private func reset() {
        if isActive && isHost { finishedHosting = true }
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        // Keep the eligibility subscription; drop session ones.
        subscriptions.removeAll()
        observer.$isEligibleForGroupSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isEligibleInCall = $0 }
            .store(in: &subscriptions)
        session = nil
        messenger = nil
        journal = nil
        isActive = false
        participantCount = 0
        presentIDs = []
        localID = nil
        files = [:]
        chat = []
        unreadChat = 0
        isChatOpen = false
        reactions = []
        hiddenSenders = []
        state = SatsangState()
    }
}
