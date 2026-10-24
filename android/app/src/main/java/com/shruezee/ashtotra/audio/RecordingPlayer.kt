package com.shruezee.ashtotra.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer

/** Plays a recording bundled in the app's assets (an mp3 named after a prayer's `audio` key). */
class RecordingPlayer(private val context: Context) {
    private var player: MediaPlayer? = null

    /** Returns false if the recording could not be opened. [onDone] runs when it finishes. */
    fun play(name: String, onDone: () -> Unit): Boolean {
        stop()
        return runCatching {
            context.assets.openFd("$name.mp3").use { fd ->
                player = MediaPlayer().apply {
                    setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                    setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                    setOnCompletionListener { stop(); onDone() }
                    prepare()
                    start()
                }
            }
        }.isSuccess
    }

    fun stop() {
        player?.runCatching { stop(); release() }
        player = null
    }
}
