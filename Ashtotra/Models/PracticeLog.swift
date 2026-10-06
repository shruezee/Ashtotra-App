import Foundation
import Observation

/// Remembers where you are in each collection and how often you have completed it.
/// Stored on the device only, in UserDefaults.
@Observable
final class PracticeLog {
    struct State: Codable, Equatable {
        var position: [String: Int] = [:]
        var completions: [String: Int] = [:]
        var practiceDays: Set<String> = []
        var favorites: Set<String> = []

        init() {}

        // Decode older saves that predate favourites.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            position = try c.decodeIfPresent([String: Int].self, forKey: .position) ?? [:]
            completions = try c.decodeIfPresent([String: Int].self, forKey: .completions) ?? [:]
            practiceDays = try c.decodeIfPresent(Set<String>.self, forKey: .practiceDays) ?? []
            favorites = try c.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
        }
    }

    private(set) var state: State
    private let defaults: UserDefaults
    private let key = "practiceLog.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = saved
        } else {
            state = State()
        }
    }

    func position(in collectionID: String) -> Int {
        state.position[collectionID] ?? 0
    }

    func completions(of collectionID: String) -> Int {
        state.completions[collectionID] ?? 0
    }

    func isFavorite(_ id: String) -> Bool {
        state.favorites.contains(id)
    }

    func toggleFavorite(_ id: String) {
        if state.favorites.remove(id) == nil { state.favorites.insert(id) }
        save()
    }

    /// Marks today as a day of practice (finishing a prayer or a routine counts).
    func recordPractice(on date: Date = .now) {
        state.practiceDays.insert(Self.dayKey(date))
        save()
    }

    func practiced(on date: Date = .now) -> Bool {
        state.practiceDays.contains(Self.dayKey(date))
    }

    var totalCompletions: Int {
        state.completions.values.reduce(0, +)
    }

    func setPosition(_ index: Int, in collectionID: String) {
        state.position[collectionID] = max(0, min(index, 107))
        save()
    }

    /// Call when the 108th name has been offered.
    func complete(_ collectionID: String, on date: Date = .now) {
        state.completions[collectionID, default: 0] += 1
        state.position[collectionID] = 0
        state.practiceDays.insert(Self.dayKey(date))
        save()
    }

    /// Consecutive days, ending today or yesterday, with at least one completion.
    func streak(today: Date = .now, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !state.practiceDays.contains(Self.dayKey(day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  state.practiceDays.contains(Self.dayKey(yesterday, calendar: calendar)) else { return 0 }
            day = yesterday
        }
        var count = 0
        while state.practiceDays.contains(Self.dayKey(day, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
    }
}
