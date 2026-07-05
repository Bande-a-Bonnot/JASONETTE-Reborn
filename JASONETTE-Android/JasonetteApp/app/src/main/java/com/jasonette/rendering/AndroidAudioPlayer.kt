package com.jasonette.rendering

import android.media.AudioAttributes
import android.media.MediaPlayer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Minimal production player for `$audio.play` URL playback. */
class AndroidAudioPlayer {
    private var player: MediaPlayer? = null

    suspend fun play(url: String): Unit = withContext(Dispatchers.Main) {
        val next = MediaPlayer()
        try {
            next.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            next.setDataSource(url)
        } catch (e: Exception) {
            next.release()
            throw e
        }

        player?.release()
        player = next

        suspendCancellableCoroutine { continuation ->
            next.setOnPreparedListener { mediaPlayer ->
                if (player !== mediaPlayer) {
                    if (continuation.isActive) {
                        continuation.resumeWithException(ActionDispatcher.ActionException("Audio playback superseded"))
                    }
                    return@setOnPreparedListener
                }
                try {
                    mediaPlayer.start()
                    if (continuation.isActive) continuation.resume(Unit)
                } catch (e: Exception) {
                    mediaPlayer.release()
                    if (player === mediaPlayer) player = null
                    if (continuation.isActive) continuation.resumeWithException(e)
                }
            }
            next.setOnErrorListener { mediaPlayer, _, _ ->
                mediaPlayer.release()
                if (player === mediaPlayer) player = null
                if (continuation.isActive) {
                    continuation.resumeWithException(ActionDispatcher.ActionException("Audio playback failed"))
                }
                true
            }
            continuation.invokeOnCancellation {
                if (player === next) player = null
                next.release()
            }
            try {
                next.prepareAsync()
            } catch (e: Exception) {
                next.release()
                if (player === next) player = null
                if (continuation.isActive) continuation.resumeWithException(e)
            }
        }
    }

    fun release() {
        player?.release()
        player = null
    }
}
