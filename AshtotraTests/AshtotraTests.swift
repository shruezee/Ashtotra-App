import AVFoundation
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

struct SatsangTests {
    private let host = UUID(), guest = UUID(), stranger = UUID()

    @Test func onlyTheHostCanChangeWhatEveryoneSees() {
        var current = SatsangState()
        current.hostID = host
        current.revision = 3
        var update = current
        update.revision = 4
        update.content = .prayer(id: "gayatri")
        #expect(SatsangRules.accepts(update, from: host, current: current, present: [host, guest]))

        var hijack = update
        hijack.hostID = guest
        #expect(!SatsangRules.accepts(hijack, from: guest, current: current, present: [host, guest]))
        // A message claiming to be the host but sent by someone else is ignored.
        #expect(!SatsangRules.accepts(update, from: guest, current: current, present: [host, guest]))
    }

    @Test func staleHostMessagesAreIgnored() {
        var current = SatsangState()
        current.hostID = host
        current.revision = 10
        var old = current
        old.revision = 9
        #expect(!SatsangRules.accepts(old, from: host, current: current, present: [host]))
    }

    @Test func someoneCanLeadWhenTheHostLeaves() {
        var current = SatsangState()
        current.hostID = host
        var claim = current
        claim.hostID = guest
        #expect(SatsangRules.accepts(claim, from: guest, current: current, present: [guest, stranger]))
        // The first host of a new satsang is accepted too.
        var first = SatsangState()
        first.hostID = host
        #expect(SatsangRules.accepts(first, from: host, current: SatsangState(), present: [host, guest]))
    }

    @Test func mediaTimeAdvancesOnlyWhilePlaying() {
        let start = Date(timeIntervalSince1970: 1_000)
        var state = SatsangState()
        state.mediaTime = 30
        state.mediaUpdatedAt = start
        #expect(state.expectedMediaTime(at: start.addingTimeInterval(10)) == 30)
        state.mediaPlaying = true
        #expect(state.expectedMediaTime(at: start.addingTimeInterval(10)) == 40)
    }

    @Test func followersOnlyJumpWhenNoticeablyOut() {
        #expect(!SatsangRules.needsSeek(local: 40.8, expected: 40))
        #expect(SatsangRules.needsSeek(local: 43, expected: 40))
    }

    @Test(arguments: [
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://youtu.be/dQw4w9WgXcQ?si=abc",
        "youtube.com/shorts/dQw4w9WgXcQ",
        "https://m.youtube.com/watch?feature=share&v=dQw4w9WgXcQ",
        "https://www.youtube.com/live/dQw4w9WgXcQ",
        "https://www.youtube.com/embed/dQw4w9WgXcQ",
        "dQw4w9WgXcQ",
    ])
    func youtubeLinksAreRecognised(link: String) {
        #expect(YouTubeLink.videoID(from: link) == "dQw4w9WgXcQ")
    }

    @Test func nonYouTubeLinksAreRejected() {
        #expect(YouTubeLink.videoID(from: "https://vimeo.com/123456789") == nil)
        #expect(YouTubeLink.videoID(from: "hello") == nil)
    }

    @Test func stateSurvivesTheTripBetweenDevices() throws {
        var state = SatsangState()
        state.hostID = host
        state.content = .video(attachment: UUID(), title: "Aarti")
        state.mediaMutedForOthers = true
        let data = try JSONEncoder().encode(SatsangMessage.state(state))
        guard case .state(let decoded) = try JSONDecoder().decode(SatsangMessage.self, from: data) else {
            Issue.record("wrong message")
            return
        }
        #expect(decoded == state)
    }

    @Test func sharedFileKindsAreDetected() {
        #expect(SatsangFileInfo.kind(for: URL(fileURLWithPath: "/tmp/stotra.pdf")) == .pdf)
        #expect(SatsangFileInfo.kind(for: URL(fileURLWithPath: "/tmp/aarti.MP4")) == .video)
        #expect(SatsangFileInfo.kind(for: URL(fileURLWithPath: "/tmp/deity.heic")) == .image)
        #expect(SatsangFileInfo.kind(for: URL(fileURLWithPath: "/tmp/notes.txt")) == nil)
    }

    @MainActor @Test func firstSatsangIsFreeThenNeedsThePurchase() {
        let defaults = UserDefaults(suiteName: "SatsangTests.\(UUID().uuidString)")!
        let store = SatsangStore(defaults: defaults, observeTransactions: false)
        #expect(store.canHost)
        store.spendFreeSatsangIfNeeded()
        #expect(!store.canHost)
        #expect(!SatsangStore(defaults: defaults, observeTransactions: false).canHost)
    }
}

@MainActor
struct DevotionalSongTests {
    /// A short silent M4A, written for the test.
    private func makeAudioFile(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                                              AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1])
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)!
        buffer.frameLength = 44_100
        try file.write(from: buffer)
        return url
    }

    @Test func importedSongReplacesTheEarlierOneAndPlays() throws {
        let first = try makeAudioFile(named: "Om Namah Shivaya.m4a")
        let second = try makeAudioFile(named: "Hanuman Chalisa.m4a")

        let firstName = try DevotionalSong.importFile(from: first)
        #expect(firstName == "Om Namah Shivaya.m4a")
        let secondName = try DevotionalSong.importFile(from: second)
        let stored = try FileManager.default.contentsOfDirectory(atPath: DevotionalSong.folder.path)
        #expect(stored == [secondName])
        #expect(DevotionalSong.title(forFile: secondName) == "Hanuman Chalisa")

        let choice = DevotionalSong.Choice(source: .file, persistentID: "", fileName: secondName)
        #expect(choice.isChosen)
        #expect(DevotionalSong.play(choice))
        DevotionalSong.stop()
    }

    @Test func missingFileIsReportedNotPlayed() {
        let choice = DevotionalSong.Choice(source: .file, persistentID: "", fileName: "gone.mp3")
        #expect(!DevotionalSong.play(choice))
    }

    @Test func nothingChosenUntilASongIsPicked() {
        #expect(!DevotionalSong.Choice(source: .file, persistentID: "123", fileName: "").isChosen)
        #expect(!DevotionalSong.Choice(source: .music, persistentID: "", fileName: "a.mp3").isChosen)
        #expect(DevotionalSong.Choice(source: .music, persistentID: "123", fileName: "").isChosen)
    }

    @Test func mp3AndMp4AreAccepted() {
        #expect(DevotionalSong.fileTypes.contains(.mp3))
        #expect(DevotionalSong.fileTypes.contains(.mpeg4Movie))
        #expect(DevotionalSong.fileTypes.contains(.mpeg4Audio))
    }
}

struct SatsangChatTests {
    private let host = UUID(), guest = UUID()
    private var state: SatsangState {
        var s = SatsangState()
        s.hostID = host
        return s
    }

    @Test func guestsCanChatUnlessTheHostPausesIt() {
        let line = SatsangChat(senderID: guest, senderName: "Asha", text: "Jai Shri Ram 🙏")
        #expect(SatsangRules.acceptsChat(line, from: guest, state: state, hidden: []))
        var paused = state
        paused.chatEnabled = false
        #expect(!SatsangRules.acceptsChat(line, from: guest, state: paused, hidden: []))
        let fromHost = SatsangChat(senderID: host, senderName: "Host", text: "Next we chant Gayatri")
        #expect(SatsangRules.acceptsChat(fromHost, from: host, state: paused, hidden: []))
    }

    @Test func hiddenPeopleAndImpersonationAreIgnored() {
        let line = SatsangChat(senderID: guest, senderName: "Asha", text: "Hello")
        #expect(!SatsangRules.acceptsChat(line, from: guest, state: state, hidden: [guest]))
        // A message claiming to be from someone else is dropped.
        #expect(!SatsangRules.acceptsChat(line, from: host, state: state, hidden: []))
    }

    @Test func emptyOrTooLongMessagesAreRejected() {
        #expect(SatsangRules.cleaned("   \n ") == nil)
        #expect(SatsangRules.cleaned("  Om  ") == "Om")
        #expect(SatsangRules.cleaned(String(repeating: "a", count: 500))?.count == SatsangChat.maxLength)
        let long = SatsangChat(senderID: guest, senderName: "Asha", text: String(repeating: "a", count: 400))
        #expect(!SatsangRules.acceptsChat(long, from: guest, state: state, hidden: []))
    }

    @Test func onlyTheHostCanRemoveMessages() {
        #expect(SatsangRules.acceptsRemoval(from: host, state: state))
        #expect(!SatsangRules.acceptsRemoval(from: guest, state: state))
    }

    @Test func chatAndReactionsSurviveTheTrip() throws {
        let line = SatsangChat(senderID: guest, senderName: "Asha", text: "🌸")
        for message in [SatsangMessage.chat(line), .reaction(.lamp), .removeChat(line.id)] {
            let data = try JSONEncoder().encode(message)
            _ = try JSONDecoder().decode(SatsangMessage.self, from: data)
        }
        if case .chat(let decoded) = try JSONDecoder().decode(SatsangMessage.self, from: JSONEncoder().encode(SatsangMessage.chat(line))) {
            #expect(decoded == line)
        }
    }
}
