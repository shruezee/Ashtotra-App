package com.shruezee.ashtotra.audio

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.shruezee.ashtotra.data.BreathPattern

/**
 * A vibration you can follow with your eyes closed: it swells as you breathe in, is still
 * while you hold, and fades as you breathe out. Phones without amplitude control get a
 * gentle pulse that speeds up on the in-breath and slows on the out-breath instead.
 */
class BreathHaptics(context: Context) {
    private val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= 31) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    val isSupported get() = vibrator.hasVibrator()

    fun play(phase: BreathPattern.Phase, seconds: Double) {
        vibrator.cancel()
        val millis = (seconds * 1000).toLong()
        if (millis <= 0 || !isSupported) return
        val effect = when (phase) {
            BreathPattern.Phase.Inhale -> ramp(millis, from = 20, to = 190)
            BreathPattern.Phase.Exhale -> ramp(millis, from = 150, to = 0)
            BreathPattern.Phase.Hold, BreathPattern.Phase.Rest -> tap(60)
        }
        vibrator.vibrate(effect)
    }

    fun success() {
        vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 40, 210, 40, 210, 40), intArrayOf(0, 120, 0, 120, 0, 120), -1))
    }

    fun stop() = vibrator.cancel()

    private fun tap(amplitude: Int) = VibrationEffect.createOneShot(30, amplitude)

    /** A rising or falling hum made of 100 ms steps. */
    private fun ramp(millis: Long, from: Int, to: Int): VibrationEffect {
        val steps = (millis / 100).toInt().coerceAtLeast(1)
        if (!vibrator.hasAmplitudeControl()) {
            // Fallback: short buzzes whose spacing follows the breath.
            val timings = mutableListOf<Long>()
            var elapsed = 0L
            var i = 0
            while (elapsed < millis) {
                val progress = elapsed.toFloat() / millis
                val strength = from + (to - from) * progress
                val gap = (600 - strength * 2.5f).toLong().coerceIn(120, 600)
                timings += gap; timings += 25
                elapsed += gap + 25
                i++
            }
            return VibrationEffect.createWaveform(timings.toLongArray(), -1)
        }
        val timings = LongArray(steps) { 100 }
        val amplitudes = IntArray(steps) { i ->
            (from + (to - from) * (i + 1).toFloat() / steps).toInt().coerceIn(0, 255)
        }
        return VibrationEffect.createWaveform(timings, amplitudes, -1)
    }
}
