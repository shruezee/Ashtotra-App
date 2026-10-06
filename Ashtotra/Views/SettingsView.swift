import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("script") private var script: Script = .simple
    @AppStorage("showOmNamah") private var showOmNamah = true
    @AppStorage("haptics") private var haptics = true

    private let sample = Library.shared.collections[0].names[0]

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
                    Text("Text follows your iPhone's text size. To make it bigger, go to Settings › Accessibility › Display & Text Size › Larger Text.")
                        .font(.callout)
                }

                Section("About") {
                    Text("The 108 names are traditional Sanskrit texts. They were carefully checked against more than one source. If you spot a mistake, please let us know.")
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
