import SwiftUI

@main
struct AshtotraApp: App {
    @State private var log = PracticeLog()
    @State private var reciter = Reciter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(log)
                .environment(reciter)
                .tint(Theme.saffron)
        }
    }
}
