package com.shruezee.ashtotra.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

/**
 * Calm meditation sounds generated on the device (same design as the iOS app): a four-string
 * tanpura drone, a singing bowl struck every few breaths, and a closing bell.
 */
class DroneSynth {
    enum class Kind { Tanpura, Bowl, None }

    private val sampleRate = 44_100
    @Volatile private var kind = Kind.None
    @Volatile private var targetGain = 0.0
    @Volatile private var bellRequested = false
    @Volatile private var running = false
    private var thread: Thread? = null

    fun start(kind: Kind) {
        this.kind = kind
        targetGain = if (kind == Kind.None) 0.0 else 1.0
        if (running) return
        running = true
        thread = Thread({ render() }, "drone-synth").apply { start() }
    }

    fun fadeOut() { targetGain = 0.0 }

    fun ringBell() { bellRequested = true }

    fun stop() {
        running = false
        thread?.join(500)
        thread = null
    }

    private fun render() {
        val minBuffer = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        val track = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            .setAudioFormat(AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setBufferSizeInBytes(maxOf(minBuffer, 8192))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        track.play()
        val voice = Voice(sampleRate.toDouble())
        val buffer = FloatArray(1024)
        while (running) {
            if (bellRequested) {
                bellRequested = false
                voice.bellStart = voice.time
            }
            for (i in buffer.indices) buffer[i] = voice.next(kind, targetGain)
            track.write(buffer, 0, buffer.size, AudioTrack.WRITE_BLOCKING)
        }
        track.stop()
        track.release()
    }

    /** Sample-by-sample synthesis state, used only on the render thread. */
    private class Voice(private val sampleRate: Double) {
        var time = 0.0
        var bellStart = -100.0
        private var gain = 0.0

        private val strings = doubleArrayOf(98.00, 130.81, 130.81, 65.41) // Pa, Sa', Sa', low Sa
        private val lastPluck = doubleArrayOf(-10.0, -10.0, -10.0, -10.0)
        private var nextString = 0
        private var nextPluck = 0.5
        private val pluckGap = 1.25
        private val harmonics = doubleArrayOf(1.0, 0.55, 0.62, 0.45, 0.38, 0.3, 0.24, 0.18, 0.12, 0.08)
        private val stringPhases = Array(4) { DoubleArray(10) }

        private val ratios = doubleArrayOf(1.0, 2.76, 5.40, 8.93)
        private val amps = doubleArrayOf(1.0, 0.45, 0.25, 0.1)
        private val decays = doubleArrayOf(14.0, 9.0, 5.0, 3.0)
        private var bowlStart = 0.3
        private val bowlPhases = DoubleArray(8)
        private val bellPhases = DoubleArray(8)

        fun next(kind: Kind, target: Double): Float {
            val dt = 1 / sampleRate
            time += dt
            gain += (target - gain) * minOf(1.0, dt / 1.2)
            var sample = 0.0
            if (gain > 0.0005) {
                sample = when (kind) {
                    Kind.Tanpura -> tanpura() * 0.16
                    Kind.Bowl -> {
                        if (time - bowlStart > 16) bowlStart = time
                        bowl(196.0, time - bowlStart, bowlPhases) * 0.22
                    }
                    Kind.None -> 0.0
                } * gain
            }
            if (time - bellStart < 12) sample += bowl(293.66, time - bellStart, bellPhases) * 0.3
            return sample.coerceIn(-1.0, 1.0).toFloat()
        }

        private fun tanpura(): Double {
            if (time >= nextPluck) {
                lastPluck[nextString] = time
                nextString = (nextString + 1) % strings.size
                nextPluck = time + if (nextString == 0) pluckGap * 1.6 else pluckGap
            }
            var sum = 0.0
            for (s in strings.indices) {
                val t = time - lastPluck[s]
                if (t >= 8) continue
                val attack = 1 - exp(-t * 60)
                for (h in harmonics.indices) {
                    val k = (h + 1).toDouble()
                    val env = exp(-t / (5.0 / (1 + 0.18 * k))) * (1 + 0.35 * sin(t * 1.7 + k))
                    stringPhases[s][h] += 2 * PI * strings[s] * k / sampleRate
                    if (stringPhases[s][h] > 2 * PI) stringPhases[s][h] -= 2 * PI
                    sum += harmonics[h] * env * attack * sin(stringPhases[s][h])
                }
            }
            return sum
        }

        private fun bowl(base: Double, t: Double, phases: DoubleArray): Double {
            if (t < 0) return 0.0
            val attack = 1 - exp(-t * 200)
            var sum = 0.0
            for (i in ratios.indices) {
                val env = amps[i] * exp(-t / decays[i]) * attack
                for (j in 0..1) {
                    val index = i * 2 + j
                    phases[index] += 2 * PI * (base * ratios[i] + if (j == 0) 0.0 else 0.6) / sampleRate
                    if (phases[index] > 2 * PI) phases[index] -= 2 * PI
                    sum += env * 0.5 * sin(phases[index])
                }
            }
            return sum
        }
    }
}
