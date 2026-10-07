package com.shruezee.ashtotra.data

import android.content.SharedPreferences
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** User preferences, observable from Compose. Same keys as the iOS app where they overlap. */
class Settings(private val prefs: SharedPreferences) {
    private fun <T> pref(initial: T, write: SharedPreferences.Editor.(T) -> Unit): Pref<T> =
        Pref(initial) { value -> prefs.edit { write(value) } }

    val script = pref(Script.fromKey(prefs.getString("script", null))) { putString("script", it.key) }
    val showOmNamah = pref(prefs.getBoolean("showOmNamah", true)) { putBoolean("showOmNamah", it) }
    val haptics = pref(prefs.getBoolean("haptics", true)) { putBoolean("haptics", it) }
    val readerScale = pref(prefs.getFloat("readerScale", 1f)) { putFloat("readerScale", it) }
    val recitePace = pref(prefs.getFloat("recitePace", 0.8f)) { putFloat("recitePace", it) }
    val reminderOn = pref(prefs.getBoolean("reminderOn", false)) { putBoolean("reminderOn", it) }
    val reminderMinutes = pref(prefs.getInt("reminderMinutes", 6 * 60 + 30)) { putInt("reminderMinutes", it) }
    val meditationLength = pref(prefs.getInt("meditationLength", MeditationLength.DEFAULT_MINUTES)) {
        putInt("meditationLength", it)
    }
    val meditationSound = pref(MeditationSound.fromKey(prefs.getString("meditationSound", null))) {
        putString("meditationSound", it.key)
    }
    val breathPattern = pref(prefs.getString("breathPattern", BreathPattern.Calm.id)!!) { putString("breathPattern", it) }
    val breathHaptics = pref(prefs.getBoolean("breathHaptics", true)) { putBoolean("breathHaptics", it) }
    val songUri = pref(prefs.getString("meditationSongUri", "")!!) { putString("meditationSongUri", it) }
    val songTitle = pref(prefs.getString("meditationSongTitle", "")!!) { putString("meditationSongTitle", it) }
}

/** One preference: a StateFlow for the UI plus a setter that also saves it. */
class Pref<T>(initial: T, private val save: (T) -> Unit) {
    private val flow = MutableStateFlow(initial)
    val state: StateFlow<T> = flow.asStateFlow()
    var value: T
        get() = flow.value
        set(new) {
            flow.value = new
            save(new)
        }
}
