package com.shruezee.ashtotra.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import java.time.LocalDate

/** Where the log is saved. The app uses SharedPreferences; tests use memory. */
interface KeyValueStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
}

class MemoryStore : KeyValueStore {
    private val values = mutableMapOf<String, String>()
    override fun getString(key: String) = values[key]
    override fun putString(key: String, value: String) { values[key] = value }
}

/**
 * Remembers where you are in each list, what you did each day, minutes meditated and favourites.
 * Stored on the device only.
 */
class PracticeLog(private val store: KeyValueStore) {
    @Serializable
    data class State(
        val position: Map<String, Int> = emptyMap(),
        val completions: Map<String, Int> = emptyMap(),
        val practiceDays: Set<String> = emptySet(),
        val favorites: Set<String> = emptySet(),
        /** Day key → what was done ("routine:morning", "prayer:gayatri", "chant:shiva", "meditation"). */
        val activities: Map<String, Set<String>> = emptyMap(),
        val meditationMinutes: Map<String, Int> = emptyMap(),
    )

    private val _state = MutableStateFlow(load())
    val state: StateFlow<State> = _state.asStateFlow()
    private val current get() = _state.value

    fun position(collectionId: String) = current.position[collectionId] ?: 0
    fun completions(collectionId: String) = current.completions[collectionId] ?: 0
    val totalCompletions get() = current.completions.values.sum()
    val totalMeditationMinutes get() = current.meditationMinutes.values.sum()
    val totalPracticeDays get() = current.practiceDays.size

    fun isFavorite(id: String) = id in current.favorites

    fun toggleFavorite(id: String) = update {
        copy(favorites = if (id in favorites) favorites - id else favorites + id)
    }

    fun setPosition(index: Int, collectionId: String) = update {
        copy(position = position + (collectionId to index.coerceIn(0, 107)))
    }

    /** Call when the 108th name has been offered. */
    fun complete(collectionId: String, on: LocalDate = LocalDate.now()) {
        update {
            copy(
                completions = completions + (collectionId to (completions[collectionId] ?: 0) + 1),
                position = position + (collectionId to 0),
            )
        }
        record("chant:$collectionId", on)
    }

    fun record(activity: String, on: LocalDate = LocalDate.now()) = update {
        val day = dayKey(on)
        copy(
            activities = activities + (day to (activities[day].orEmpty() + activity)),
            practiceDays = practiceDays + day,
        )
    }

    /** Undo a mark made by mistake. */
    fun unrecord(activity: String, on: LocalDate = LocalDate.now()) = update {
        val day = dayKey(on)
        val remaining = activities[day].orEmpty() - activity
        if (remaining.isEmpty() && (meditationMinutes[day] ?: 0) == 0) {
            copy(activities = activities - day, practiceDays = practiceDays - day)
        } else {
            copy(activities = activities + (day to remaining))
        }
    }

    fun did(activity: String, on: LocalDate = LocalDate.now()) = activity in activities(on)
    fun activities(on: LocalDate): Set<String> = current.activities[dayKey(on)].orEmpty()
    fun practiced(on: LocalDate = LocalDate.now()) = dayKey(on) in current.practiceDays

    fun addMeditation(minutes: Int, on: LocalDate = LocalDate.now()) {
        if (minutes <= 0) return
        update {
            val day = dayKey(on)
            copy(meditationMinutes = meditationMinutes + (day to (meditationMinutes[day] ?: 0) + minutes))
        }
        record(MEDITATION, on)
    }

    fun meditationMinutes(on: LocalDate) = current.meditationMinutes[dayKey(on)] ?: 0

    /** Consecutive days, ending today or yesterday, with any practice. */
    fun streak(today: LocalDate = LocalDate.now()): Int {
        var day = if (practiced(today)) today else today.minusDays(1)
        var count = 0
        while (practiced(day)) {
            count++
            day = day.minusDays(1)
        }
        return count
    }

    private fun update(change: State.() -> State) {
        _state.value = current.change()
        store.putString(KEY, AppJson.encodeToString(State.serializer(), current))
    }

    private fun load(): State = store.getString(KEY)?.let {
        runCatching { AppJson.decodeFromString(State.serializer(), it) }.getOrNull()
    } ?: State()

    companion object {
        const val MEDITATION = "meditation"
        private const val KEY = "practiceLog.v1"
        fun dayKey(date: LocalDate): String = date.toString() // yyyy-MM-dd
    }
}
