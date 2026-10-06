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
