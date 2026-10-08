import SwiftUI

enum AppTab: String {
    case today, prayers, meditate, names
}

struct RootView: View {
    @State private var tab: AppTab = .today
    @State private var todayPath = NavigationPath()
    @State private var prayersPath = NavigationPath()
    @State private var namesPath = NavigationPath()
    @State private var meditatePath = NavigationPath()
    @State private var showSettings = false
    @Environment(PracticeLog.self) private var log
    @Environment(SatsangSession.self) private var satsang
    @State private var showSatsangRoom = false
    @State private var debugSheet: String?

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $todayPath) {
                TodayView(tab: $tab).appDestinations()
            }
            .tabItem { Label("Today", systemImage: "sun.horizon.fill") }
            .tag(AppTab.today)

            NavigationStack(path: $prayersPath) {
                PrayersView().appDestinations()
            }
            .tabItem { Label("Prayers", systemImage: "book.closed.fill") }
            .tag(AppTab.prayers)

            NavigationStack(path: $meditatePath) {
                MeditateView().appDestinations()
            }
            .tabItem { Label("Meditate", systemImage: "leaf.fill") }
            .tag(AppTab.meditate)

            NavigationStack(path: $namesPath) {
                NamesView().appDestinations()
            }
            .tabItem { Label("108 Names", systemImage: "circle.dotted") }
            .tag(AppTab.names)
        }
        .environment(\.openSettings, OpenSettingsAction { showSettings = true })
        // Joining from FaceTime or Messages, or starting one, opens the satsang room.
        .fullScreenCover(isPresented: $showSatsangRoom, onDismiss: { if satsang.isActive { satsang.leave() } }) {
            SatsangRoomView()
        }
        .sheet(item: Binding(get: { debugSheet.map(DebugSheet.init) }, set: { debugSheet = $0?.id })) { sheet in
            if sheet.id == "paywall" { SatsangPaywall() } else { SatsangStartView() }
        }
        .onChange(of: satsang.isActive) { _, active in
            // Give any open sheet (e.g. the start screen) time to close before presenting.
            Task {
                if active { try? await Task.sleep(for: .milliseconds(600)) }
                showSatsangRoom = satsang.isActive
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        #if DEBUG
        .onAppear(perform: openDemoRoute)
        #endif
    }

    #if DEBUG
    /// Screenshot hooks: `-demoRoute settings`, `-demoRoute shiva`, `-demoRoute prayer:hanuman-chalisa`,
    /// `-demoRoute routine:morning`, `-demoRoute tab:prayers`.
    private func openDemoRoute() {
        if UserDefaults.standard.bool(forKey: "demoSeed") { seedDemoHistory() }
        guard let route = UserDefaults.standard.string(forKey: "demoRoute") else { return }
        let parts = route.split(separator: ":", maxSplits: 1).map(String.init)
        let book = PrayerBook.shared
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("settings", _):
            showSettings = true
        case ("satsangstart", _):
            debugSheet = "start"
        case ("paywall", _):
            debugSheet = "paywall"
        case ("satsang", let what?):
            // -demoRoute satsang:host-prayer | satsang:guest-names | satsang:host-welcome
            let asHost = what.hasPrefix("host")
            if what.hasSuffix("prayer") { satsang.debugSimulate(asHost: asHost, content: .prayer(id: "hanuman-chalisa"), position: 3) }
            else if what.hasSuffix("names") { satsang.debugSimulate(asHost: asHost, content: .names(id: "ganesha"), position: 7) }
            else { satsang.debugSimulate(asHost: asHost, content: .welcome) }
        case ("meditate", _):
            tab = .meditate
        case ("journey", _):
            todayPath.append(JourneyRoute())
        case ("tab", let name?):
            tab = AppTab(rawValue: name) ?? .today
        case ("prayer", let id?):
            if let prayer = book.prayer(id: id) {
                tab = .prayers
                prayersPath.append(prayer)
            }
        case ("routine", let id?):
            if let routine = book.routines.first(where: { $0.id == id }) {
                todayPath.append(routine)
            }
        case (let id?, nil):
            if let collection = Library.shared.collection(id: id) {
                tab = .names
                namesPath.append(collection)
            }
        default:
            break
        }
    }

    /// `-demoSeed YES`: a believable fortnight of practice for screenshots.
    private func seedDemoHistory() {
        let calendar = Calendar.current
        for offset in 1...16 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: .now), offset != 9 else { continue }
            let devotion = Weekday.devotion(for: calendar.component(.weekday, from: day))
            log.record("routine:morning", on: day)
            if offset % 3 != 0 { log.record("prayer:\(devotion.prayerID)", on: day) }
            if offset % 4 != 1 { log.addMeditation(minutes: [2, 5, 2, 10][offset % 4], on: day) }
            if offset % 2 == 0 { log.record("routine:evening", on: day) }
        }
        log.record("routine:morning")
        log.addMeditation(minutes: 2)
        log.setPosition(41, in: "shiva")
    }
    #endif
}

struct JourneyRoute: Hashable {}

/// Debug-only sheets opened by `-demoRoute` for screenshots.
private struct DebugSheet: Identifiable { let id: String }

extension View {
    /// Every tab can open prayers, routines and 108-name lists.
    func appDestinations() -> some View {
        navigationDestination(for: Prayer.self) { PrayerReaderView(prayer: $0) }
            .navigationDestination(for: Routine.self) { RoutineView(routine: $0) }
            .navigationDestination(for: NameCollection.self) { ReaderView(collection: $0) }
            .navigationDestination(for: JourneyRoute.self) { _ in JourneyView() }
    }

    /// Gear button that opens Settings.
    func settingsToolbar() -> some View {
        modifier(SettingsToolbar())
    }
}

private struct SettingsToolbar: ViewModifier {
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }
}

struct OpenSettingsAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue = OpenSettingsAction {}
}

extension EnvironmentValues {
    var openSettings: OpenSettingsAction {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}
