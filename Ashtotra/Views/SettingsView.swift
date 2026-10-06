import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("script") private var script: Script = .simple
    @AppStorage("showOmNamah") private var showOmNamah = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 6 * 60 + 30
    @State private var notificationsDenied = false

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
