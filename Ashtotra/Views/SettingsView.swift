import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("script") private var script: Script = .simple
    @AppStorage("showOmNamah") private var showOmNamah = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 6 * 60 + 30
    @State private var notificationsDenied = false
    @Environment(PlusStore.self) private var plus
    @State private var showPaywall = false
    @State private var manageSubscription = false
    @State private var restoreMessage: String?

    private let sample = Library.shared.collections[0].names[0]

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (parts.hour ?? 6) * 60 + (parts.minute ?? 30)
        }
    }

    private func updateReminder() {
        guard reminderOn else {
            DailyReminder.cancel()
            return
        }
        Task {
            let scheduled = await DailyReminder.schedule(minutesAfterMidnight: reminderMinutes)
            notificationsDenied = !scheduled
            if !scheduled { reminderOn = false }
        }
    }

    private func freeText(_ feature: PlusStore.Feature) -> String {
        switch plus.status(of: feature) {
        case .notStarted: feature == .hosting ? "First day free" : "First month free"
        case .active(let end): "Free, " + PlusStore.timeLeft(until: end, from: .now).lowercased()
        case .ended: "Needs Plus"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Script", selection: $script) {
                        ForEach(Script.allCases) { option in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                Text(option.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Read the names in")
                } footer: {
                    Text("Example: \(Library.shared.chantLine(sample, script: script))", script: script)
                }

                if plus.pricingEnabled {
                Section {
                    if plus.isSubscribed {
                        Label("Ashtotra Plus is active. Thank you! 🙏", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Button("Manage subscription") { manageSubscription = true }
                    } else {
                        LabeledContent("Hosting satsangs", value: freeText(.hosting))
                        LabeledContent("Meditation and Sleep", value: freeText(.meditation))
                        Button("See Ashtotra Plus plans") { showPaywall = true }
                    }
                    Button("Restore purchases") {
                        Task {
                            try? await AppStore.sync()
                            await plus.refresh()
                            restoreMessage = plus.isSubscribed ? "Ashtotra Plus restored." : "No active subscription found for this Apple Account."
                        }
                    }
                    if let restoreMessage {
                        Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Ashtotra Plus")
                } footer: {
                    Text("Hosting a satsang is free for your first day and meditation for your first month. Prayers, the 108 names and joining satsangs are always free.")
                }
                .sheet(isPresented: $showPaywall) { PlusPaywall(reason: .general) }
                .manageSubscriptionsSheet(isPresented: $manageSubscription)
                }

                Section("Reading") {
                    Toggle("Show “Om … namaha” on every name", isOn: $showOmNamah)
                    Toggle("Gentle vibration while chanting", isOn: $haptics)
                }

                Section {
                    Toggle("Daily prayer reminder", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                    if notificationsDenied {
                        Text("Notifications are turned off for Ashtotra. You can allow them in the Settings app.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("One gentle notification a day. Nothing else.")
                }
                .onChange(of: reminderOn) { _, _ in updateReminder() }
                .onChange(of: reminderMinutes) { _, _ in updateReminder() }

                Section {
                    if Reciter.hasVoice {
                        Text("Tap Listen on any prayer, or turn on Listen in chant mode, to hear it read aloud with your iPhone's Hindi voice. It works offline.")
                            .font(.callout)
                    } else {
                        Text("To hear prayers read aloud, add a Hindi voice in the Settings app: Accessibility › Spoken Content › Voices › Hindi.")
                            .font(.callout)
                    }
                } header: {
                    Text("Read aloud")
                } footer: {
                    Text("For better pronunciation, choose an Enhanced Hindi voice there.")
                }

                Section {
                    Text("Text follows your iPhone's text size. In any prayer you can also make it larger from the Aa menu.")
                        .font(.callout)
                }

                Section("About") {
                    Text("The prayers and 108 names are traditional texts, carefully checked against more than one source. If you spot a mistake, please let us know.")
                        .font(.callout)
                    Link(destination: URL(string: "mailto:shruthianthropic@gmail.com?subject=Ashtotra%20correction")!) {
                        Label("Suggest a correction", systemImage: "envelope")
                    }
                    Link(destination: URL(string: "https://shruezee.github.io/Ashtotra-App/privacy.html")!) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    Text("No ads, no accounts, no tracking. Your progress stays on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
