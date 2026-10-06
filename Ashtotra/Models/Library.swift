import Foundation

/// The ways a name can be shown. Every collection carries all of them.
enum Script: String, CaseIterable, Identifiable, Codable {
    case simple, iast, devanagari, telugu, kannada, gujarati

    var id: String { rawValue }

    /// Shown in the script picker, written in its own script.
    var label: String {
        switch self {
        case .simple: "English"
        case .iast: "IAST"
        case .devanagari: "देवनागरी"
        case .telugu: "తెలుగు"
        case .kannada: "ಕನ್ನಡ"
        case .gujarati: "ગુજરાતી"
        }
    }

    var detail: String {
        switch self {
        case .simple: "Easy-to-read English letters"
        case .iast: "Scholarly transliteration with accents"
        case .devanagari: "Sanskrit, Hindi, Marathi"
        case .telugu: "Telugu"
        case .kannada: "Kannada"
        case .gujarati: "Gujarati"
        }
    }

    /// Tells VoiceOver which voice to read the name with.
    var speechLanguage: String? {
        switch self {
        case .simple, .iast: nil
        case .devanagari: "hi-IN"
        case .telugu: "te-IN"
        case .kannada: "kn-IN"
        case .gujarati: "gu-IN"
        }
    }
}

struct DivineName: Codable, Hashable {
    let simple, iast, devanagari, telugu, kannada, gujarati: String

    func text(in script: Script) -> String {
        switch script {
        case .simple: simple
        case .iast: iast
        case .devanagari: devanagari
        case .telugu: telugu
        case .kannada: kannada
        case .gujarati: gujarati
        }
    }
}

struct NameCollection: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let nativeTitle: String
    let subtitle: String
    let blurb: String
    let color: String
    let names: [DivineName]
}

struct Library: Codable {
    let om: [String: String]
    let namah: [String: String]
    let collections: [NameCollection]

    static let shared: Library = {
        guard let url = Bundle.main.url(forResource: "Ashtottara", withExtension: "json") else {
            fatalError("Ashtottara.json is missing from the app bundle")
        }
        return load(from: url)
    }()

    static func load(from url: URL) -> Library {
        do {
            return try JSONDecoder().decode(Library.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Could not read \(url.lastPathComponent): \(error)")
        }
    }

    func collection(id: String) -> NameCollection? {
        collections.first { $0.id == id }
    }

    /// "ॐ गजाननाय नमः" style line for chanting.
    func chantLine(_ name: DivineName, script: Script) -> String {
        let om = om[script.rawValue] ?? "Om"
        let namah = namah[script.rawValue] ?? "namaha"
        return "\(om) \(name.text(in: script)) \(namah)"
    }
}
