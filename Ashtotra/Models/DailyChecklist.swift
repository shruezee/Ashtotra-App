import Foundation

/// The four small things that make a day of practice: morning prayers, the day's
/// devotion, a few minutes of stillness, and the evening lamp.
struct DailyChecklist {
    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        /// The activity string recorded in `PracticeLog` when this is done.
        let activity: String
        /// Other activities that also count (finishing the day's 108 names counts as the devotion).
        let alsoCounts: [String]
        let destination: Destination

        enum Destination: Hashable {
            case routine(Routine)
            case prayer(Prayer)
            case meditate
        }
    }

    let items: [Item]

    init(date: Date, book: PrayerBook = .shared, calendar: Calendar = .current) {
        let devotion = Weekday.devotion(for: calendar.component(.weekday, from: date))
        var items: [Item] = []
        if let morning = book.routines.first(where: { $0.id == "morning" }) {
            items.append(Item(id: "morning", title: "Morning prayers", detail: "\(morning.prayers.count) short mantras",
                              symbol: "sunrise.fill", activity: "routine:morning", alsoCounts: [], destination: .routine(morning)))
        }
        if let prayer = book.prayer(id: devotion.prayerID) {
            items.append(Item(id: "devotion", title: prayer.title, detail: devotion.note,
                              symbol: "sparkles", activity: "prayer:\(prayer.id)",
                              alsoCounts: devotion.namesID.map { ["chant:\($0)"] } ?? [],
                              destination: .prayer(prayer)))
        }
        items.append(Item(id: "meditation", title: "Meditate", detail: "A few minutes of stillness",
                          symbol: "leaf.fill", activity: PracticeLog.meditation, alsoCounts: [], destination: .meditate))
        if let evening = book.routines.first(where: { $0.id == "evening" }) {
            items.append(Item(id: "evening", title: "Evening lamp", detail: "Light the diya and pray",
                              symbol: "flame.fill", activity: "routine:evening", alsoCounts: [], destination: .routine(evening)))
        }
        self.items = items
    }

    static func isDone(_ item: Item, in activities: Set<String>) -> Bool {
        activities.contains(item.activity) || item.alsoCounts.contains(where: activities.contains)
    }

    func doneCount(in activities: Set<String>) -> Int {
        items.filter { Self.isDone($0, in: activities) }.count
    }

    /// 0…1, for the week strip and calendar rings.
    func progress(in activities: Set<String>) -> Double {
        items.isEmpty ? 0 : Double(doneCount(in: activities)) / Double(items.count)
    }
}
