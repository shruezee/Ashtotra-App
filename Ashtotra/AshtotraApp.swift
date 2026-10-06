import SwiftUI

@main
struct AshtotraApp: App {
    @State private var log = PracticeLog()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(log)
                .tint(Theme.saffron)
        }
    }
}
