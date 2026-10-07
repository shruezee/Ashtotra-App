package com.shruezee.ashtotra

import com.shruezee.ashtotra.data.BreathPattern
import com.shruezee.ashtotra.data.DailyChecklist
import com.shruezee.ashtotra.data.Library
import com.shruezee.ashtotra.data.MeditationLength
import com.shruezee.ashtotra.data.MemoryStore
import com.shruezee.ashtotra.data.PracticeLog
import com.shruezee.ashtotra.data.PrayerBook
import com.shruezee.ashtotra.data.Script
import com.shruezee.ashtotra.data.Weekday
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime

private fun asset(name: String) =
    requireNotNull(DataTests::class.java.classLoader!!.getResource(name)) { "missing $name" }.readText()

class DataTests {
    private val library = Library.parse(asset("Ashtottara.json"))
    private val book = PrayerBook.parse(asset("Prayers.json"))

    @Test fun everyCollectionHas108Names() {
        assertEquals(listOf("ganesha", "shiva", "lakshmi", "saraswati"), library.collections.map { it.id })
        library.collections.forEach { assertEquals(it.title, 108, it.names.size) }
    }

    @Test fun everyTextExistsInEveryScript() {
        val texts = library.collections.flatMap { it.names } + book.prayers.flatMap { it.lines }
        for (text in texts) for (script in Script.entries) {
            assertTrue("$script empty", text.text(script).isNotBlank())
        }
    }

    @Test fun chantLineWrapsNameWithOmAndNamah() {
        val first = library.collections[0].names[0]
        assertEquals("ॐ गजाननाय नमः", library.chantLine(first, Script.Devanagari))
        assertEquals("Om gajaananaaya namaha", library.chantLine(first, Script.Simple))
    }

    @Test fun prayersAndRoutinesAreConsistent() {
        assertTrue(book.prayers.size >= 20)
        assertEquals(book.prayers.size, book.prayers.map { it.id }.toSet().size)
        for (routine in book.routines) assertEquals(routine.id, routine.prayers.size, book.prayersIn(routine).size)
        assertEquals((1..40).toList(), book.prayer("hanuman-chalisa")!!.verses.mapNotNull { it.number })
    }

    @Test fun everyWeekdayHasADevotion() {
        for (day in DayOfWeek.entries) {
            val devotion = Weekday.devotion(day)
            assertNotNull(book.prayer(devotion.prayerId))
            devotion.namesId?.let { assertNotNull(library.collection(it)) }
        }
    }

    @Test fun routineFollowsTimeOfDay() {
        fun at(hour: Int) = LocalDateTime.of(2026, 10, 6, hour, 0)
        assertEquals("morning", book.routineFor(at(6)).id)
        assertEquals("evening", book.routineFor(at(19)).id)
        assertEquals("night", book.routineFor(at(23)).id)
    }

    @Test fun checklistCountsDevotionByChantingTheDaysNames() {
        val monday = LocalDate.of(2026, 10, 5)
        val list = DailyChecklist(monday, book)
        assertEquals(listOf("morning", "devotion", "meditation", "evening"), list.items.map { it.id })
        assertEquals(1, list.doneCount(setOf("chant:shiva")))
        assertEquals(1f, list.progress(list.items.map { it.activity }.toSet()))
    }
}

class PracticeLogTests {
    private fun log() = PracticeLog(MemoryStore())

    @Test fun completingResetsPositionAndCountsAsChant() {
        val log = log()
        log.setPosition(107, "shiva")
        log.complete("shiva")
        assertEquals(0, log.position("shiva"))
        assertEquals(1, log.completions("shiva"))
        assertTrue(log.did("chant:shiva"))
    }

    @Test fun positionIsClamped() {
        val log = log()
        log.setPosition(500, "ganesha")
        assertEquals(107, log.position("ganesha"))
    }

    @Test fun streakEndsTodayOrYesterday() {
        val log = log()
        val today = LocalDate.of(2026, 10, 6)
        (1..3).forEach { log.record("routine:morning", today.minusDays(it.toLong())) }
        assertEquals(3, log.streak(today))
        log.record("meditation", today)
        assertEquals(4, log.streak(today))
        assertEquals(0, log.streak(today.plusDays(3)))
    }

    @Test fun unrecordingTheOnlyActivityClearsTheDay() {
        val log = log()
        log.record("routine:morning")
        log.unrecord("routine:morning")
        assertFalse(log.practiced())
    }

    @Test fun meditationAndFavouritesPersist() {
        val store = MemoryStore()
        PracticeLog(store).apply {
            addMeditation(2)
            addMeditation(5)
            toggleFavorite("gayatri")
        }
        val reloaded = PracticeLog(store)
        assertEquals(7, reloaded.meditationMinutes(LocalDate.now()))
        assertTrue(reloaded.did(PracticeLog.MEDITATION))
        assertTrue(reloaded.isFavorite("gayatri"))
    }
}

class MeditationTests {
    @Test fun calmBreathCycles() {
        val calm = BreathPattern.Calm
        assertEquals(12.0, calm.cycle, 0.0)
        assertEquals(BreathPattern.Phase.Inhale, calm.phaseAt(1.0).first)
        assertEquals(0.5, calm.phaseAt(2.0).second, 1e-9)
        assertEquals(BreathPattern.Phase.Hold, calm.phaseAt(5.0).first)
        assertEquals(BreathPattern.Phase.Exhale, calm.phaseAt(7.0).first)
        assertEquals(BreathPattern.Phase.Inhale, calm.phaseAt(13.0).first)
    }

    @Test fun gentleSkipsHold() {
        assertEquals(BreathPattern.Phase.Exhale, BreathPattern.Gentle.phaseAt(4.5).first)
        assertEquals("In 4 · out 4", BreathPattern.Gentle.summary)
    }

    @Test fun lengthDefaultsToTwoMinutes() {
        assertEquals(2, MeditationLength.DEFAULT_MINUTES)
        assertEquals(1..20, MeditationLength.range)
    }
}
