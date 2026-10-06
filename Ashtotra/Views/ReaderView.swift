import SwiftUI

struct ReaderView: View {
    @Environment(PracticeLog.self) private var log
    @AppStorage("script") private var script: Script = .simple
    @AppStorage("showOmNamah") private var showOmNamah = true
    @State private var chantStart: ChantStart?

    let collection: NameCollection
    private let library = Library.shared

    struct ChantStart: Identifiable {
        let index: Int
        var id: Int { index }
    }

    var body: some View {
        let bookmark = log.position(in: collection.id)

        ScrollViewReader { proxy in
            List {
                Section {
                    intro(bookmark: bookmark)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                Section {
                    ForEach(Array(collection.names.enumerated()), id: \.offset) { index, name in
                        Button {
                            chantStart = ChantStart(index: index)
                        } label: {
                            NameRow(number: index + 1,
                                    text: showOmNamah ? library.chantLine(name, script: script) : name.text(in: script),
                                    script: script,
                                    isBookmark: index == bookmark && bookmark > 0,
                                    tint: Theme.textTint(for: collection))
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .listRowBackground(Theme.card)
                        .accessibilityHint("Starts chanting from this name")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(collection.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ScriptMenu(script: $script)
                }
            }
            .fullScreenCover(item: $chantStart) { start in
                ChantView(collection: collection, startIndex: start.index)
            }
            .onAppear {
                if bookmark > 3 { proxy.scrollTo(bookmark, anchor: .center) }
                #if DEBUG
                // `-demoChant 11` opens chant mode at name 12 (screenshots).
                if let demo = UserDefaults.standard.object(forKey: "demoChant") as? String, let start = Int(demo) {
                    chantStart = ChantStart(index: start)
                }
                #endif
            }
        }
    }

    private func intro(bookmark: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(collection.nativeTitle, script: .devanagari)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textTint(for: collection))
            Text(collection.subtitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(collection.blurb)
                .font(.body)
            Button {
                chantStart = ChantStart(index: bookmark)
            } label: {
                Label(bookmark > 0 ? "Continue chanting at \(bookmark + 1)" : "Begin chanting",
                      systemImage: "hands.and.sparkles.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.tint(for: collection))
            .buttonBorderShape(.roundedRectangle(radius: 18))
            .padding(.top, 4)
            Text("Or tap any name to start from there.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct NameRow: View {
    let number: Int
    let text: String
    let script: Script
    let isBookmark: Bool
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(number)")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
                .frame(minWidth: 34, alignment: .trailing)
                .accessibilityLabel("Name \(number)")
            Text(text, script: script)
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if isBookmark {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(tint)
                    .accessibilityLabel("You stopped here")
            }
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct ScriptMenu: View {
    @Binding var script: Script

    var body: some View {
        Menu {
            Picker("Script", selection: $script) {
                ForEach(Script.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            Label("Script: \(script.label)", systemImage: "character.book.closed")
        }
    }
}
