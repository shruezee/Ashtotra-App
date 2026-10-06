import SwiftUI

enum AppTab: String {
    case today, prayers, names
}

struct RootView: View {
    @State private var tab: AppTab = .today
    @State private var todayPath = NavigationPath()
    @State private var prayersPath = NavigationPath()
    @State private var namesPath = NavigationPath()
    @State private var showSettings = false

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

            NavigationStack(path: $namesPath) {
                NamesView().appDestinations()
            }
            .tabItem { Label("108 Names", systemImage: "circle.dotted") }
            .tag(AppTab.names)
        }
        .environment(\.openSettings, OpenSettingsAction { showSettings = true })
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
        guard let route = UserDefaults.standard.string(forKey: "demoRoute") else { return }
        let parts = route.split(separator: ":", maxSplits: 1).map(String.init)
        let book = PrayerBook.shared
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("settings", _):
            showSettings = true
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
    #endif
}

extension View {
    /// Every tab can open prayers, routines and 108-name lists.
    func appDestinations() -> some View {
        navigationDestination(for: Prayer.self) { PrayerReaderView(prayer: $0) }
            .navigationDestination(for: Routine.self) { RoutineView(routine: $0) }
            .navigationDestination(for: NameCollection.self) { ReaderView(collection: $0) }
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
