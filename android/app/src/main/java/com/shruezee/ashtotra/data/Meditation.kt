package com.shruezee.ashtotra.data

/** A breathing rhythm, in seconds per phase. */
data class BreathPattern(
    val id: String,
    val name: String,
    val inhale: Double,
    val hold: Double,
    val exhale: Double,
    val rest: Double,
) {
    enum class Phase(val label: String) { Inhale("Breathe in"), Hold("Hold"), Exhale("Breathe out"), Rest("Rest") }

    val cycle get() = inhale + hold + exhale + rest

    val summary: String
        get() = buildList {
            add("In ${inhale.toInt()}")
            if (hold > 0) add("hold ${hold.toInt()}")
            add("out ${exhale.toInt()}")
            if (rest > 0) add("rest ${rest.toInt()}")
        }.joinToString(" · ")

    fun length(phase: Phase) = when (phase) {
        Phase.Inhale -> inhale
        Phase.Hold -> hold
        Phase.Exhale -> exhale
        Phase.Rest -> rest
    }

    /** Which phase [elapsed] seconds falls in, and how far through it (0…1). */
    fun phaseAt(elapsed: Double): Pair<Phase, Double> {
        var t = elapsed % cycle
        for (phase in Phase.entries) {
            val length = length(phase)
            if (length <= 0) continue
            if (t < length) return phase to t / length
            t -= length
        }
        return Phase.Inhale to 0.0
    }

    companion object {
        val Calm = BreathPattern("calm", "Calm", 4.0, 2.0, 6.0, 0.0)
        val Balanced = BreathPattern("balanced", "Balanced", 4.0, 4.0, 4.0, 4.0)
        val Gentle = BreathPattern("gentle", "Gentle", 4.0, 0.0, 4.0, 0.0)
        val all = listOf(Calm, Balanced, Gentle)
        fun named(id: String?) = all.firstOrNull { it.id == id } ?: Calm
    }
}

/** What plays while meditating. */
enum class MeditationSound(val key: String, val title: String) {
    Tanpura("tanpura", "Tanpura drone"),
    Bowl("bowl", "Singing bowl"),
    Silence("silence", "Silence"),
    MySong("myMusic", "My devotional song");

    companion object {
        fun fromKey(key: String?) = entries.firstOrNull { it.key == key } ?: Tanpura
    }
}

object MeditationLength {
    val range = 1..20
    const val DEFAULT_MINUTES = 2
}
