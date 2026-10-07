package com.shruezee.ashtotra.audio

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

/**
 * Reads lines aloud with the phone's Hindi text-to-speech voice, one after another, and
 * publishes which line is being spoken so screens can highlight and follow along.
 */
class Reciter(context: Context) {
    data class Status(
        val owner: String? = null,
        val index: Int? = null,
        val playing: Boolean = false,
        /** Increments each time a recitation reaches its last line. */
        val finished: Int = 0,
    )

    private val _status = MutableStateFlow(Status())
    val status: StateFlow<Status> = _status.asStateFlow()

    private val _hasVoice = MutableStateFlow(false)
    val hasVoice: StateFlow<Boolean> = _hasVoice.asStateFlow()

    /** 0.6 slow, 0.8 calm, 1.0 normal. */
    var pace = 0.8f

    private var lines: List<String> = emptyList()
    private val hindi = Locale.forLanguageTag("hi-IN")

    private val tts: TextToSpeech = TextToSpeech(context.applicationContext) { result ->
        if (result == TextToSpeech.SUCCESS) {
            val support = engine.isLanguageAvailable(hindi)
            _hasVoice.value = support >= TextToSpeech.LANG_AVAILABLE
            if (_hasVoice.value) engine.language = hindi
        }
    }
    private val engine get() = tts

    init {
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String) {
                val index = utteranceId.substringAfterLast(':').toIntOrNull() ?: return
                _status.value = _status.value.copy(index = index)
            }

            override fun onDone(utteranceId: String) {
                val index = utteranceId.substringAfterLast(':').toIntOrNull() ?: return
                if (index == lines.lastIndex && _status.value.playing) {
                    _status.value = Status(finished = _status.value.finished + 1)
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String) = stop()
        })
    }

    fun isPlaying(owner: String) = _status.value.playing && _status.value.owner == owner

    /** Start reading [lines] (Devanagari) from [from]. */
    fun play(lines: List<String>, from: Int = 0, owner: String) {
        stop()
        if (from !in lines.indices || !_hasVoice.value) return
        this.lines = lines
        tts.setSpeechRate(pace)
        _status.value = _status.value.copy(owner = owner, index = from, playing = true)
        for (i in from..lines.lastIndex) {
            tts.speak(speakable(lines[i]), TextToSpeech.QUEUE_ADD, null, "$owner:$i")
            tts.playSilentUtterance(350, TextToSpeech.QUEUE_ADD, "pause:$i")
        }
    }

    fun stop() {
        tts.stop()
        _status.value = Status(finished = _status.value.finished)
    }

    fun shutdown() = tts.shutdown()

    companion object {
        /** The Om sign and verse marks are not spoken well by Hindi voices. */
        fun speakable(text: String) = text.replace("ॐ", "ओम्").replace("ऽ", "").replace("॥", "।")
    }
}
