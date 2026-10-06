import Foundation

/// Mantras, stotras and aartis, plus the daily routines that group them.
struct PrayerBook: Codable {
    let prayers: [Prayer]
    let routines: [Routine]

    static let shared: PrayerBook = {
        guard let url = Bundle.main.url(forResource: "Prayers", withExtension: "json") else {
            fatalError("Prayers.json is missing from the app bundle")
        }
        do {
            return try JSONDecoder().decode(PrayerBook.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Could not read Prayers.json: \(error)")
        }
    }()

    func prayer(id: String) -> Prayer? {
        prayers.first { $0.id == id }
    }

    func prayers(of kind: Prayer.Kind) -> [Prayer] {
        prayers.filter { $0.kind == kind }
    }

    func prayers(in routine: Routine) -> [Prayer] {
        routine.prayers.compactMap(prayer(id:))
    }

    /// The routine that suits the time of day.
    func routine(for date: Date, calendar: Calendar = .current) -> Routine {
        let hour = calendar.component(.hour, from: date)
        let id = switch hour {
        case 4..<11: "morning"
        case 11..<15: "meal"
        case 15..<17: "study"
        case 17..<21: "evening"
        default: "night"
        }
        return routines.first { $0.id == id } ?? routines[0]
    }
}

struct Prayer: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case mantra, stotra, aarti

        var title: String {
            switch self {
            case .mantra: "Daily mantras"
            case .stotra: "Stotras & Chalisa"
            case .aarti: "Aarti"
            }
        }
    }

    let id: String
    let title: String
    let nativeTitle: String
    /// Colour key shared with the 108-name collections (orange, indigo, pink, teal, gold, blue, saffron).
    let deity: String
    let kind: Kind
    let about: String
    let meaning: String?
    let verses: [Verse]

    var lineCount: Int { verses.reduce(0) { $0 + $1.lines.count } }
}

struct Verse: Codable, Hashable {
    /// A section heading such as "Dohā" or "Phalaśruti".
    let label: String?
    let number: Int?
    let lines: [ScriptText]
}

struct Routine: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let prayers: [String]
}

/// Something to open from the Today screen.
enum Practice: Hashable {
    case prayer(Prayer)
    case names(NameCollection)
    case routine(Routine)

    var title: String {
        switch self {
        case .prayer(let prayer): prayer.title
        case .names(let collection): "108 names of \(collection.title)"
        case .routine(let routine): routine.title
        }
    }
}

/// Traditional day-of-the-week devotions.
enum Weekday {
    struct Devotion {
        let deity: String
        let note: String
        let prayerID: String
        let namesID: String?
    }

    /// `weekday` follows `Calendar`: 1 is Sunday.
    static func devotion(for weekday: Int) -> Devotion {
        switch weekday {
        case 1: Devotion(deity: "Surya", note: "Sunday is the Sun's day.", prayerID: "aditya-hrudayam", namesID: nil)
        case 2: Devotion(deity: "Shiva", note: "Monday is dear to Shiva.", prayerID: "mahamrityunjaya", namesID: "shiva")
        case 3: Devotion(deity: "Hanuman", note: "Tuesday is Hanuman's day.", prayerID: "hanuman-chalisa", namesID: nil)
        case 4: Devotion(deity: "Ganesha", note: "Wednesday honours Ganesha.", prayerID: "ganesha-pancharatnam", namesID: "ganesha")
        case 5: Devotion(deity: "Vishnu", note: "Thursday honours Vishnu and the Guru.", prayerID: "narayana-suktam", namesID: "saraswati")
        case 6: Devotion(deity: "Lakshmi", note: "Friday is Lakshmi's day.", prayerID: "sri-suktam", namesID: "lakshmi")
        default: Devotion(deity: "Hanuman", note: "Saturday: Hanuman's protection.", prayerID: "hanuman-chalisa", namesID: nil)
        }
    }
}
