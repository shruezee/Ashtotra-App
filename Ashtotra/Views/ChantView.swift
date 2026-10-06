import SwiftUI
import UIKit

/// One name at a time, large, with a 108-bead progress ring.
struct ChantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(PracticeLog.self) private var log
    @Environment(Reciter.self) private var reciter
    @AppStorage("script") private var script: Script = .simple
    @AppStorage("haptics") private var haptics = true

    let collection: NameCollection
    @State private var index: Int
    @State private var finished = false
    private let library = Library.shared

    init(collection: NameCollection, startIndex: Int) {
        self.collection = collection
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Theme.gradient(for: collection).ignoresSafeArea()
            if finished {
                completion
                    .transition(.opacity)
            } else {
                chanting
            }
        }
        .foregroundStyle(.white)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            if listening { reciter.stop() }
        }
        .onChange(of: reciter.currentIndex) { _, spoken in
            guard listening, let spoken, spoken != index else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { index = spoken }
            log.setPosition(index, in: collection.id)
        }
        .onChange(of: reciter.finishedToken) { _, _ in
            if reciterOwner == lastListenOwner && index == 107 { finish() }
        }
        .sensoryFeedback(.selection, trigger: index) { _, _ in haptics }
        .sensoryFeedback(.success, trigger: finished) { _, new in haptics && new }
    }

    private var name: ScriptText { collection.names[index] }

    private var reciterOwner: String { "chant-\(collection.id)" }
    private var listening: Bool { reciter.isPlaying(reciterOwner) }
    @State private var lastListenOwner: String?

    private var spokenLines: [String] {
        collection.names.map { library.chantLine($0, script: .devanagari) }
    }

    private func toggleListening() {
        if listening {
            reciter.stop()
        } else {
            lastListenOwner = reciterOwner
            reciter.play(spokenLines, from: index, owner: reciterOwner)
        }
    }

    private func finish() {
        log.complete(collection.id)
        withAnimation(.easeInOut(duration: 0.5)) { finished = true }
        UIAccessibility.post(notification: .announcement, argument: "108 names offered")
    }

    private var chanting: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 12)
            ZStack {
                BeadRing(count: 108, done: index + 1)
                    .accessibilityHidden(true)
                VStack(spacing: 14) {
                    Text(library.om[script.rawValue] ?? "Om", script: script)
                        .font(.system(size: 40, weight: .semibold))
                        .opacity(0.85)
                    Text(name.text(in: script), script: script)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .id(index)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                    Text(library.namah[script.rawValue] ?? "namaha", script: script)
                        .font(.title2.weight(.medium))
                        .opacity(0.85)
                }
                .padding(.horizontal, 56)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
            }
            .frame(maxWidth: 520)
            .contentShape(.rect)
            .onTapGesture { advance() }
            .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
                if drag.translation.width < -30 { advance() }
                if drag.translation.width > 30 { goBack() }
            })
            Spacer(minLength: 12)
            if script != .simple && !typeSize.isAccessibilitySize {
                Text(name.simple)
                    .font(.headline)
                    .opacity(0.8)
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)
            }
            controls
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .accessibilityAction(named: "Next name") { advance() }
        .accessibilityAction(named: "Previous name") { goBack() }
    }

    private var topBar: some View {
        HStack {
            Button {
                log.setPosition(index, in: collection.id)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.18), in: .circle)
            }
            .accessibilityLabel("Close and remember my place")
            Spacer()
            VStack(spacing: 2) {
                Text(collection.title).font(.headline)
                Text("\(index + 1) of 108")
                    .font(.subheadline.monospacedDigit())
                    .opacity(0.85)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            ScriptMenu(script: $script)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.bold))
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.18), in: .circle)
        }
        .padding(.top, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button(action: toggleListening) {
                Image(systemName: listening ? "pause.fill" : "speaker.wave.2.fill")
                    .frame(width: 64, height: 64)
            }
            .background(.white.opacity(listening ? 0.45 : 0.16), in: .rect(cornerRadius: 20))
            .accessibilityLabel(listening ? "Pause listening" : "Listen and chant along")
            .disabled(!Reciter.hasVoice)

            Button(action: goBack) {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .disabled(index == 0)
            .background(.white.opacity(0.16), in: .rect(cornerRadius: 20))

            Button(action: advance) {
                Label(index == 107 ? "Offer" : "Next", systemImage: index == 107 ? "hands.sparkles.fill" : "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .background(.white.opacity(0.32), in: .rect(cornerRadius: 20))
        }
        .font(.title3.weight(.semibold))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .frame(maxWidth: 520)
    }

    private var completion: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🙏")
                .font(.system(size: 80))
                .accessibilityHidden(true)
            Text("108 names offered")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("May \(collection.title) bless your day with peace.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .opacity(0.9)
            let total = log.completions(of: collection.id)
            Text(total == 1 ? "Your first time with this list." : "You've completed this list \(total) times.")
                .font(.headline)
                .opacity(0.85)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: 520, minHeight: 64)
                    .background(.white.opacity(0.32), in: .rect(cornerRadius: 20))
            }
            Button {
                withAnimation { index = 0; finished = false }
                lastListenOwner = nil
            } label: {
                Text("Chant again")
                    .font(.headline)
                    .frame(minHeight: 52)
            }
        }
        .padding(24)
    }

    private func advance() {
        if index == 107 {
            if listening { reciter.stop() }
            finish()
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { index += 1 }
        log.setPosition(index, in: collection.id)
        if listening { reciter.play(spokenLines, from: index, owner: reciterOwner) }
    }

    private func goBack() {
        guard index > 0 else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { index -= 1 }
        log.setPosition(index, in: collection.id)
        if listening { reciter.play(spokenLines, from: index, owner: reciterOwner) }
    }
}

/// A mala of 108 beads drawn as a ring; beads already chanted glow.
struct BeadRing: View {
    let count: Int
    let done: Int

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - 8
            ZStack {
                ForEach(0..<count, id: \.self) { bead in
                    let angle = Double(bead) / Double(count) * 2 * .pi - .pi / 2
                    Circle()
                        .fill(.white.opacity(bead < done ? 0.95 : 0.25))
                        .frame(width: bead % 27 == 0 ? 9 : 6, height: bead % 27 == 0 ? 9 : 6)
                        .position(x: geo.size.width / 2 + radius * cos(angle),
                                  y: geo.size.height / 2 + radius * sin(angle))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
