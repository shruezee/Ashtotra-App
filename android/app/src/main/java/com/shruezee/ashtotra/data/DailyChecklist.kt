package com.shruezee.ashtotra.data

import java.time.LocalDate

/**
 * The four small things that make a day of practice: morning prayers, the day's devotion,
 * a few minutes of stillness, and the evening lamp.
 */
class DailyChecklist(date: LocalDate, book: PrayerBook) {
    sealed interface Destination {
        data class OpenRoutine(val routine: Routine) : Destination
        data class OpenPrayer(val prayer: Prayer) : Destination
        data object Meditate : Destination
    }

    data class Item(
        val id: String,
        val title: String,
        val detail: String,
        /** The activity recorded in [PracticeLog] when this is done. */
        val activity: String,
        /** Other activities that also count (chanting the day's 108 names counts as the devotion). */
        val alsoCounts: List<String>,
        val destination: Destination,
    )

    val items: List<Item> = buildList {
        val devotion = Weekday.devotion(date.dayOfWeek)
        book.routine("morning")?.let {
            add(Item("morning", "Morning prayers", "${it.prayers.size} short mantras", "routine:morning",
                emptyList(), Destination.OpenRoutine(it)))
        }
        book.prayer(devotion.prayerId)?.let {
            add(Item("devotion", it.title, devotion.note, "prayer:${it.id}",
                listOfNotNull(devotion.namesId?.let { names -> "chant:$names" }), Destination.OpenPrayer(it)))
        }
        add(Item("meditation", "Meditate", "A few minutes of stillness", PracticeLog.MEDITATION,
            emptyList(), Destination.Meditate))
        book.routine("evening")?.let {
            add(Item("evening", "Evening lamp", "Light the diya and pray", "routine:evening",
                emptyList(), Destination.OpenRoutine(it)))
        }
    }

    fun doneCount(activities: Set<String>) = items.count { isDone(it, activities) }

    /** 0…1, for the week strip and calendar rings. */
    fun progress(activities: Set<String>) =
        if (items.isEmpty()) 0f else doneCount(activities).toFloat() / items.size

    companion object {
        fun isDone(item: Item, activities: Set<String>) =
            item.activity in activities || item.alsoCounts.any { it in activities }
    }
}
