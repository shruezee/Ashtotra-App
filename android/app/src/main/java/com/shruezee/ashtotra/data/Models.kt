package com.shruezee.ashtotra.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.DayOfWeek
import java.time.LocalDateTime

/** The ways a name or prayer line can be shown. Every text carries all of them. */
enum class Script(val key: String, val label: String, val detail: String, val languageTag: String?) {
    Simple("simple", "English", "Easy-to-read English letters", null),
    Iast("iast", "IAST", "Scholarly transliteration with accents", null),
    Devanagari("devanagari", "देवनागरी", "Sanskrit, Hindi, Marathi", "hi-IN"),
    Telugu("telugu", "తెలుగు", "Telugu", "te-IN"),
    Kannada("kannada", "ಕನ್ನಡ", "Kannada", "kn-IN"),
    Gujarati("gujarati", "ગુજરાતી", "Gujarati", "gu-IN");

    companion object {
        fun fromKey(key: String?): Script = entries.firstOrNull { it.key == key } ?: Simple
    }
}

@Serializable
data class ScriptText(
    val simple: String,
    val iast: String,
    val devanagari: String,
    val telugu: String,
    val kannada: String,
    val gujarati: String,
) {
    fun text(script: Script): String = when (script) {
        Script.Simple -> simple
        Script.Iast -> iast
        Script.Devanagari -> devanagari
        Script.Telugu -> telugu
        Script.Kannada -> kannada
        Script.Gujarati -> gujarati
    }
}

// ---- 108 names ----

@Serializable
data class NameCollection(
    val id: String,
    val title: String,
    val nativeTitle: String,
    val subtitle: String,
    val blurb: String,
    val color: String,
    val names: List<ScriptText>,
)

@Serializable
data class Library(
    val om: Map<String, String>,
    val namah: Map<String, String>,
    val collections: List<NameCollection>,
) {
    fun collection(id: String): NameCollection? = collections.firstOrNull { it.id == id }

    /** "ॐ गजाननाय नमः" style line for chanting. */
    fun chantLine(name: ScriptText, script: Script): String =
        "${om[script.key] ?: "Om"} ${name.text(script)} ${namah[script.key] ?: "namaha"}"

    companion object {
        fun parse(json: String): Library = AppJson.decodeFromString(serializer(), json)
    }
}

// ---- Prayers ----

@Serializable
enum class PrayerKind(val title: String) {
    @SerialName("mantra") Mantra("Daily mantras"),
    @SerialName("stotra") Stotra("Stotras & Chalisa"),
    @SerialName("aarti") Aarti("Aarti"),
}

@Serializable
data class Verse(val label: String? = null, val number: Int? = null, val lines: List<ScriptText>)

@Serializable
data class Prayer(
    val id: String,
    val title: String,
    val nativeTitle: String,
    /** Colour key shared with the 108-name collections. */
    val deity: String,
    val kind: PrayerKind,
    val about: String,
    val meaning: String? = null,
    val verses: List<Verse>,
    val tags: List<String> = emptyList(),
) {
    val lines: List<ScriptText> get() = verses.flatMap { it.lines }
}

@Serializable
data class Routine(
    val id: String,
    val title: String,
    val subtitle: String,
    /** SF Symbol name on iOS; mapped to a Material icon on Android. */
    val symbol: String,
    val prayers: List<String>,
)

@Serializable
data class PrayerBook(val prayers: List<Prayer>, val routines: List<Routine>) {
    fun prayer(id: String): Prayer? = prayers.firstOrNull { it.id == id }
    fun prayers(kind: PrayerKind): List<Prayer> = prayers.filter { it.kind == kind }
    fun prayersIn(routine: Routine): List<Prayer> = routine.prayers.mapNotNull(::prayer)
    fun routine(id: String): Routine? = routines.firstOrNull { it.id == id }

    /** The routine that suits the time of day. */
    fun routineFor(time: LocalDateTime): Routine {
        val id = when (time.hour) {
            in 4 until 11 -> "morning"
            in 11 until 15 -> "meal"
            in 15 until 17 -> "study"
            in 17 until 21 -> "evening"
            else -> "night"
        }
        return routine(id) ?: routines.first()
    }

    companion object {
        fun parse(json: String): PrayerBook = AppJson.decodeFromString(serializer(), json)
    }
}

/** Traditional day-of-the-week devotions. */
object Weekday {
    data class Devotion(val deity: String, val note: String, val prayerId: String, val namesId: String?)

    fun devotion(day: DayOfWeek): Devotion = when (day) {
        DayOfWeek.SUNDAY -> Devotion("Surya", "Sunday is the Sun's day.", "aditya-hrudayam", null)
        DayOfWeek.MONDAY -> Devotion("Shiva", "Monday is dear to Shiva.", "mahamrityunjaya", "shiva")
        DayOfWeek.TUESDAY -> Devotion("Hanuman", "Tuesday is Hanuman's day.", "hanuman-chalisa", null)
        DayOfWeek.WEDNESDAY -> Devotion("Ganesha", "Wednesday honours Ganesha.", "ganesha-pancharatnam", "ganesha")
        DayOfWeek.THURSDAY -> Devotion("Vishnu", "Thursday honours Vishnu and the Guru.", "narayana-suktam", "saraswati")
        DayOfWeek.FRIDAY -> Devotion("Lakshmi", "Friday is Lakshmi's day.", "sri-suktam", "lakshmi")
        DayOfWeek.SATURDAY -> Devotion("Hanuman", "Saturday: Hanuman's protection.", "hanuman-chalisa", null)
    }
}

val AppJson = Json { ignoreUnknownKeys = true }
