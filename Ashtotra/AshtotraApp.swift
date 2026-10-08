import SwiftUI

@main
struct AshtotraApp: App {
    @State private var log = PracticeLog()
    @State private var reciter = Reciter()
    @State private var satsang = SatsangSession()
    @State private var store = SatsangStore()
    @State private var sleep = SleepPlayer()
    @State private var showSplash = AshtotraApp.wantsSplash

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(log)
                    .environment(reciter)
                    .environment(satsang)
                    .environment(store)
                    .environment(sleep)
                    .tint(Theme.saffron)
                    .onAppear { satsang.onBecameHost = { store.spendFreeSatsangIfNeeded() } }
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                guard showSplash else { return }
                // Load the prayer texts while the splash is showing.
                await Task.detached(priority: .userInitiated) {
                    _ = PrayerBook.shared.prayers.count
                    _ = Library.shared.collections.count
                }.value
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
            }
        }
    }

    /// Screenshot runs open a screen directly, so they skip the splash.
    private static var wantsSplash: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "demoRoute") == nil
            && !UserDefaults.standard.bool(forKey: "demoSeed")
            && !UserDefaults.standard.bool(forKey: "skipSplash")
        #else
        return true
        #endif
    }
}
