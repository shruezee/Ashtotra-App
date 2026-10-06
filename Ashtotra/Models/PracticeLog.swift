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
        /// Day key → what was done that day ("routine:morning", "prayer:gayatri", "chant:shiva", "meditation").
        var activities: [String: Set<String>] = [:]
        /// Day key → minutes meditated.
        var meditationMinutes: [String: Int] = [:]

        init() {}

        // Decode older saves that predate favourites.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            position = try c.decodeIfPresent([String: Int].self, forKey: .position) ?? [:]
            completions = try c.decodeIfPresent([String: Int].self, forKey: .completions) ?? [:]
            practiceDays = try c.decodeIfPresent(Set<String>.self, forKey: .practiceDays) ?? []
            favorites = try c.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
            activities = try c.decodeIfPresent([String: Set<String>].self, forKey: .activities) ?? [:]
            meditationMinutes = try c.decodeIfPresent([String: Int].self, forKey: .meditationMinutes) ?? [:]
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

    /// Records something done today; any activity makes it a day of practice.
    func record(_ activity: String, on date: Date = .now) {
        let day = Self.dayKey(date)
        state.activities[day, default: []].insert(activity)
        state.practiceDays.insert(day)
        save()
    }

    /// Undo a mark made by mistake from the daily checklist.
    func unrecord(_ activity: String, on date: Date = .now) {
        let day = Self.dayKey(date)
        state.activities[day]?.remove(activity)
        if state.activities[day]?.isEmpty ?? true, (state.meditationMinutes[day] ?? 0) == 0 {
            state.activities[day] = nil
            state.practiceDays.remove(day)
        }
        save()
    }

    func did(_ activity: String, on date: Date = .now) -> Bool {
        state.activities[Self.dayKey(date)]?.contains(activity) ?? false
    }

    func activities(on date: Date) -> Set<String> {
        state.activities[Self.dayKey(date)] ?? []
    }

    func practiced(on date: Date = .now) -> Bool {
        state.practiceDays.contains(Self.dayKey(date))
    }

    func addMeditation(minutes: Int, on date: Date = .now) {
        guard minutes > 0 else { return }
        state.meditationMinutes[Self.dayKey(date), default: 0] += minutes
        record(Self.meditation, on: date)
    }

    func meditationMinutes(on date: Date) -> Int {
        state.meditationMinutes[Self.dayKey(date)] ?? 0
    }

    var totalMeditationMinutes: Int { state.meditationMinutes.values.reduce(0, +) }
    var totalPracticeDays: Int { state.practiceDays.count }

    static let meditation = "meditation"

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
        record("chant:\(collectionID)", on: date)
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
