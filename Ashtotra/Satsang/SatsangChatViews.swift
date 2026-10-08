import SwiftUI

/// Chat for everyone in the satsang. Messages live only on participants' devices.
struct SatsangChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SatsangSession.self) private var satsang
    @AppStorage("satsangName") private var name = ""
    @State private var draft = ""
    @State private var askName = false
    @State private var nameDraft = ""
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !satsang.state.chatEnabled {
                    Label(satsang.isHost ? "Chat is paused for everyone. Only you can post." : "The host has paused chat during chanting.",
                          systemImage: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Theme.saffron.opacity(0.12))
                }
                messages
                ReactionStrip()
                    .padding(.top, 6)
                composer
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Satsang chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if satsang.isHost {
                    ToolbarItem(placement: .topBarTrailing) {
                        Toggle(isOn: Binding(get: { satsang.state.chatEnabled }, set: { satsang.setChatEnabled($0) })) {
                            Label("Chat on", systemImage: "bubble.left.and.bubble.right")
                        }
                        .toggleStyle(.button)
                        .accessibilityLabel(satsang.state.chatEnabled ? "Pause chat for everyone" : "Turn chat back on")
                    }
                }
            }
            .alert("Your name in satsang", isPresented: $askName) {
                TextField("Name", text: $nameDraft)
                Button("Save") {
                    name = String(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
                    send()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Shown next to your messages, only to people in this satsang.")
            }
            .onAppear { satsang.isChatOpen = true }
            .onDisappear { satsang.isChatOpen = false }
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if satsang.chat.isEmpty {
                        Text("Say hello, share a blessing, or ask which page everyone is on. Messages disappear when the satsang ends.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(satsang.chat) { line in
                        ChatBubble(line: line, mine: satsang.isFromMe(line), host: satsang.isFromHost(line))
                            .id(line.id)
                            .contextMenu { menu(for: line) }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: satsang.chat.count) { _, _ in
                if let last = satsang.chat.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            .onAppear { if let last = satsang.chat.last { proxy.scrollTo(last.id, anchor: .bottom) } }
        }
    }

    @ViewBuilder
    private func menu(for line: SatsangChat) -> some View {
        Button { UIPasteboard.general.string = line.text } label: { Label("Copy", systemImage: "doc.on.doc") }
        if satsang.isHost {
            Button(role: .destructive) { satsang.removeChat(line.id) } label: { Label("Remove for everyone", systemImage: "trash") }
        }
        if !satsang.isFromMe(line) {
            Button { satsang.hideMessages(from: line.senderID) } label: {
                Label("Hide messages from \(line.senderName)", systemImage: "eye.slash")
            }
            Button(role: .destructive) { report(line) } label: { Label("Report", systemImage: "exclamationmark.bubble") }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(satsang.state.chatEnabled || satsang.isHost ? "Message" : "Chat is paused", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($typing)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.card, in: .rect(cornerRadius: 20))
                .disabled(!satsang.state.chatEnabled && !satsang.isHost)
                .onSubmit(sendOrAskName)
                .onChange(of: draft) { _, new in
                    if new.count > SatsangChat.maxLength { draft = String(new.prefix(SatsangChat.maxLength)) }
                }
            Button(action: sendOrAskName) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.saffron)
            }
            .disabled(SatsangRules.cleaned(draft) == nil)
            .accessibilityLabel("Send")
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private func sendOrAskName() {
        guard SatsangRules.cleaned(draft) != nil else { return }
        if name.isEmpty {
            nameDraft = ""
            askName = true
        } else {
            send()
        }
    }

    private func send() {
        satsang.sendChat(draft, name: name)
        draft = ""
    }

    /// Reports go to the developer by email, so no server is needed.
    private func report(_ line: SatsangChat) {
        let body = "I'd like to report this satsang message.\n\nFrom: \(line.senderName)\nMessage: \(line.text)\nTime: \(line.sentAt.formatted())"
        var components = URLComponents(string: "mailto:shruthianthropic@gmail.com")!
        components.queryItems = [URLQueryItem(name: "subject", value: "Ashtotra satsang report"),
                                 URLQueryItem(name: "body", value: body)]
        if let url = components.url { openURL(url) }
        satsang.hideMessages(from: line.senderID)
    }
}

private struct ChatBubble: View {
    let line: SatsangChat
    let mine: Bool
    let host: Bool

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
            if !mine {
                HStack(spacing: 4) {
                    Text(line.senderName).font(.caption.weight(.semibold))
                    if host { Image(systemName: "crown.fill").font(.caption2).foregroundStyle(Theme.saffron).accessibilityLabel("Host") }
                }
                .foregroundStyle(.secondary)
            }
            Text(line.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(mine ? Theme.saffron : Theme.card, in: .rect(cornerRadius: 18))
                .foregroundStyle(mine ? .white : .primary)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mine ? "You: \(line.text)" : "\(line.senderName)\(host ? ", host" : ""): \(line.text)")
    }
}

/// One-tap blessings everyone sees float up.
struct ReactionStrip: View {
    @Environment(SatsangSession.self) private var satsang

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SatsangReaction.allCases) { reaction in
                Button {
                    satsang.react(reaction)
                } label: {
                    Text(reaction.rawValue)
                        .font(.title2)
                        .frame(width: 52, height: 44)
                        .background(Theme.card, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send \(reaction.label)")
            }
        }
        .sensoryFeedback(.selection, trigger: satsang.reactions.count)
    }
}

/// Reactions drifting up the room, from anyone in the satsang.
struct FloatingReactionsOverlay: View {
    @Environment(SatsangSession.self) private var satsang
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ForEach(satsang.reactions) { item in
                FloatingEmoji(text: item.reaction.rawValue, reduceMotion: reduceMotion)
                    .position(x: geo.size.width * item.lane, y: geo.size.height * 0.75)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct FloatingEmoji: View {
        let text: String
        let reduceMotion: Bool
        @State private var risen = false

        var body: some View {
            Text(text)
                .font(.system(size: 44))
                .offset(y: risen && !reduceMotion ? -260 : 0)
                .opacity(risen ? 0 : 1)
                .scaleEffect(risen ? 1.3 : 0.8)
                .onAppear { withAnimation(.easeOut(duration: 2.8)) { risen = true } }
        }
    }
}
