import SwiftUI

/// Picks up exactly where the static launch screen leaves off (same colour, same icon,
/// same place), then adds a gentle loading message and the copyright line.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false
    @State private var messageIndex = 0

    private let messages = ["Lighting the lamp…", "Preparing your prayers…", "Taking a calm breath…"]

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            // Centred on the whole screen, like the launch screen, so the icon doesn't jump.
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.saffron.opacity(0.28), .clear],
                                         center: .center, startRadius: 10, endRadius: 190))
                    .frame(width: 380, height: 380)
                    .scaleEffect(glow ? 1.08 : 0.85)
                    .opacity(glow ? 1 : 0)
                Image("LaunchIcon")
                    .shadow(color: Theme.saffron.opacity(glow ? 0.35 : 0), radius: 18, y: 8)
                    // Title and loading message hang below the icon without moving it.
                    .overlay(alignment: .top) {
                        VStack(spacing: 10) {
                            Text("Ashtotra")
                                .font(.title.weight(.bold))
                            Text(messages[messageIndex])
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .id(messageIndex)
                                .transition(.opacity)
                            ProgressView()
                                .tint(Theme.saffron)
                                .padding(.top, 4)
                        }
                        .fixedSize()
                        .offset(y: 120 + 32)
                        .opacity(glow ? 1 : 0)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack {
                Spacer()
                Text("© 2026 Shruezee Studio")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
            .opacity(glow ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ashtotra. \(messages[messageIndex]) Copyright 2026 Shruezee Studio.")
        .task {
            withAnimation(reduceMotion ? .easeIn(duration: 0.3) : .easeOut(duration: 0.9)) { glow = true }
            for index in 1..<messages.count {
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.easeInOut(duration: 0.35)) { messageIndex = index }
            }
        }
    }
}

#Preview {
    SplashView()
}
