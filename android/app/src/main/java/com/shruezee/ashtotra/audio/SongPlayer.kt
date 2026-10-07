package com.shruezee.ashtotra.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri

/**
 * Plays the devotional song the user chose from their own files (via the system picker).
 * Ashtotra only keeps the link the picker granted; it never copies or uploads the file.
 */
class SongPlayer(private val context: Context) {
    private var player: MediaPlayer? = null

    /** Returns false if the song can no longer be opened (moved or deleted). */
    fun play(uri: String): Boolean {
        stop()
        if (uri.isBlank()) return false
        return runCatching {
            player = MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                setDataSource(context, Uri.parse(uri))
                isLooping = true
                prepare()
                start()
            }
        }.isSuccess
    }

    fun stop() {
        player?.runCatching { stop(); release() }
        player = null
    }
}
