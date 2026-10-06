import Foundation
import Testing
@testable import Ashtotra

struct LibraryTests {
    let library = Library.shared

    @Test func everyCollectionHasExactly108Names() {
        #expect(library.collections.map(\.id) == ["ganesha", "shiva", "lakshmi", "saraswati"])
        for collection in library.collections {
            #expect(collection.names.count == 108, "\(collection.title)")
        }
    }

    @Test(arguments: Script.allCases)
    func everyNameExistsInEveryScript(script: Script) {
        for collection in library.collections {
            for name in collection.names {
                #expect(!name.text(in: script).trimmingCharacters(in: .whitespaces).isEmpty)
            }
            #expect(library.om[script.rawValue] != nil)
            #expect(library.namah[script.rawValue] != nil)
        }
    }

    @Test func indicScriptsContainNoLatinLetters() {
        let latin = CharacterSet.letters.intersection(CharacterSet(charactersIn: "a"..."z").union(CharacterSet(charactersIn: "A"..."Z")))
        for collection in library.collections {
            for name in collection.names {
                for script in [Script.devanagari, .telugu, .kannada, .gujarati] {
                    #expect(name.text(in: script).unicodeScalars.allSatisfy { !latin.contains($0) },
                            "\(collection.title): \(name.text(in: script))")
                }
            }
        }
    }

    @Test func chantLineWrapsNameWithOmAndNamah() {
        let first = library.collections[0].names[0]
        #expect(library.chantLine(first, script: .devanagari) == "ॐ गजाननाय नमः")
        #expect(library.chantLine(first, script: .simple) == "Om gajaananaaya namaha")
    }
}

struct PracticeLogTests {
    private func freshLog() -> PracticeLog {
        let defaults = UserDefaults(suiteName: "PracticeLogTests.\(UUID().uuidString)")!
        return PracticeLog(defaults: defaults)
    }

    @Test func completingResetsPositionAndCounts() {
        let log = freshLog()
        log.setPosition(107, in: "shiva")
        log.complete("shiva")
        #expect(log.position(in: "shiva") == 0)
        #expect(log.completions(of: "shiva") == 1)
        #expect(log.totalCompletions == 1)
    }

    @Test func positionIsClampedTo108Names() {
        let log = freshLog()
        log.setPosition(500, in: "ganesha")
        #expect(log.position(in: "ganesha") == 107)
        log.setPosition(-3, in: "ganesha")
        #expect(log.position(in: "ganesha") == 0)
    }

    @Test func streakCountsConsecutiveDaysEndingYesterdayOrToday() {
        let log = freshLog()
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 9))!
        for offset in [1, 2, 3] {
            log.complete("lakshmi", on: calendar.date(byAdding: .day, value: -offset, to: today)!)
        }
        #expect(log.streak(today: today, calendar: calendar) == 3)
        log.complete("lakshmi", on: today)
        #expect(log.streak(today: today, calendar: calendar) == 4)
        let later = calendar.date(byAdding: .day, value: 3, to: today)!
        #expect(log.streak(today: later, calendar: calendar) == 0)
    }

    @Test func progressSurvivesRelaunch() {
        let defaults = UserDefaults(suiteName: "PracticeLogTests.\(UUID().uuidString)")!
        PracticeLog(defaults: defaults).setPosition(41, in: "saraswati")
        #expect(PracticeLog(defaults: defaults).position(in: "saraswati") == 41)
    }
}

struct PrayerBookTests {
    let book = PrayerBook.shared

    @Test func everyPrayerHasTextInEveryScript() {
        #expect(book.prayers.count >= 20)
        for prayer in book.prayers {
            #expect(!prayer.verses.isEmpty, "\(prayer.id)")
            for line in prayer.verses.flatMap(\.lines) {
                for script in Script.allCases {
                    #expect(!line.text(in: script).trimmingCharacters(in: .whitespaces).isEmpty, "\(prayer.id) \(script)")
                }
            }
        }
    }

    @Test func prayerIDsAreUnique() {
        #expect(Set(book.prayers.map(\.id)).count == book.prayers.count)
    }

    @Test func routinesOnlyReferToRealPrayers() {
        for routine in book.routines {
            #expect(book.prayers(in: routine).count == routine.prayers.count, "\(routine.id)")
        }
    }

    @Test func hanumanChalisaHasFortyNumberedChaupais() {
        let chalisa = book.prayer(id: "hanuman-chalisa")!
        #expect(chalisa.verses.compactMap(\.number) == Array(1...40))
    }

    @Test func adityaHrudayamHasThirtyOneShlokas() {
        let hymn = book.prayer(id: "aditya-hrudayam")!
        #expect(hymn.verses.compactMap(\.number).count == 31)
    }

    @Test func indicScriptsJoinWordsAfterAHalant() {
        // "gurur brahmā" is written गुरुर्ब्रह्मा, never with a space after the halant.
        let line = book.prayer(id: "guru-brahma")!.verses[0].lines[0]
        #expect(line.devanagari.hasPrefix("गुरुर्ब्रह्मा"))
        for prayer in book.prayers {
            for line in prayer.verses.flatMap(\.lines) {
                #expect(!line.devanagari.contains("् "), "\(prayer.id): \(line.devanagari)")
            }
        }
    }

    @Test(arguments: 1...7)
    func everyWeekdayHasADevotion(weekday: Int) {
        let devotion = Weekday.devotion(for: weekday)
        #expect(book.prayer(id: devotion.prayerID) != nil)
        if let names = devotion.namesID {
            #expect(Library.shared.collection(id: names) != nil)
        }
    }

    @Test func routineFollowsTheTimeOfDay() {
        let calendar = Calendar(identifier: .gregorian)
        func at(_ hour: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: hour))! }
        #expect(book.routine(for: at(6), calendar: calendar).id == "morning")
        #expect(book.routine(for: at(19), calendar: calendar).id == "evening")
        #expect(book.routine(for: at(23), calendar: calendar).id == "night")
    }

    @Test func speakableTextSpellsOutOm() {
        #expect(Reciter.speakable("ॐ नमः शिवाय॥") == "ओम् नमः शिवाय।")
    }
}

struct FavoritesTests {
    @Test func favoritesToggleAndPersist() {
        let defaults = UserDefaults(suiteName: "FavoritesTests.\(UUID().uuidString)")!
        let log = PracticeLog(defaults: defaults)
        log.toggleFavorite("gayatri")
        #expect(PracticeLog(defaults: defaults).isFavorite("gayatri"))
        log.toggleFavorite("gayatri")
        #expect(!PracticeLog(defaults: defaults).isFavorite("gayatri"))
    }

    @Test func recordingPracticeCountsTowardsTheStreak() {
        let defaults = UserDefaults(suiteName: "FavoritesTests.\(UUID().uuidString)")!
        let log = PracticeLog(defaults: defaults)
        #expect(!log.practiced())
        log.record("prayer:gayatri")
        #expect(log.practiced())
        #expect(log.streak() == 1)
    }
}

struct MeditationTests {
    @Test func calmBreathCyclesThroughInHoldOut() {
        let calm = BreathPattern.calm   // in 4, hold 2, out 6
        #expect(calm.cycle == 12)
        #expect(calm.phase(at: 1).phase == .inhale)
        #expect(calm.phase(at: 2).progress == 0.5)
        #expect(calm.phase(at: 5).phase == .hold)
        #expect(calm.phase(at: 7).phase == .exhale)
        #expect(calm.phase(at: 13).phase == .inhale)   // wraps into the next breath
    }

    @Test func patternWithoutHoldSkipsIt() {
        #expect(BreathPattern.gentle.phase(at: 4.5).phase == .exhale)
        #expect(BreathPattern.gentle.summary == "In 4 · out 4")
    }

    @Test func lengthDefaultsToTwoMinutesWithinOneToTwenty() {
        #expect(MeditationLength.defaultMinutes == 2)
        #expect(MeditationLength.range == 1...20)
    }

    @Test func meditationMinutesAddUpAndCountAsPractice() {
        let log = PracticeLog(defaults: UserDefaults(suiteName: "MeditationTests.\(UUID().uuidString)")!)
        log.addMeditation(minutes: 2)
        log.addMeditation(minutes: 5)
        #expect(log.meditationMinutes(on: .now) == 7)
        #expect(log.totalMeditationMinutes == 7)
        #expect(log.did(PracticeLog.meditation))
        #expect(log.practiced())
    }
}

struct DailyChecklistTests {
    let calendar = Calendar(identifier: .gregorian)
    var tuesday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 8))! }

    @Test func checklistHasMorningDevotionMeditationAndEvening() {
        let list = DailyChecklist(date: tuesday, calendar: calendar)
        #expect(list.items.map(\.id) == ["morning", "devotion", "meditation", "evening"])
        #expect(list.items[1].activity == "prayer:hanuman-chalisa")
    }

    @Test func progressFillsAsPracticesAreDone() {
        let list = DailyChecklist(date: tuesday, calendar: calendar)
        #expect(list.progress(in: []) == 0)
        #expect(list.doneCount(in: ["routine:morning", "meditation"]) == 2)
        #expect(list.progress(in: ["routine:morning", "prayer:hanuman-chalisa", "meditation", "routine:evening"]) == 1)
    }

    @Test func chantingTheDaysNamesCountsAsTheDevotion() {
        let monday = calendar.date(byAdding: .day, value: -1, to: tuesday)!
        let list = DailyChecklist(date: monday, calendar: calendar)
        let devotion = list.items.first { $0.id == "devotion" }!
        #expect(DailyChecklist.isDone(devotion, in: ["chant:shiva"]))
    }

    @Test func unmarkingTheOnlyActivityClearsTheDay() {
        let log = PracticeLog(defaults: UserDefaults(suiteName: "DailyChecklistTests.\(UUID().uuidString)")!)
        log.record("routine:morning")
        #expect(log.practiced())
        log.unrecord("routine:morning")
        #expect(!log.practiced())
        #expect(log.activities(on: .now).isEmpty)
    }

    @Test func journeyDescribesActivities() {
        #expect(JourneyView.describe("routine:evening", minutes: 0) == "Evening lamp")
        #expect(JourneyView.describe("prayer:gayatri", minutes: 0) == "Gayatri Mantra")
        #expect(JourneyView.describe("chant:lakshmi", minutes: 0) == "108 names of Lakshmi")
        #expect(JourneyView.describe("meditation", minutes: 1) == "Meditated 1 minute")
    }
}
