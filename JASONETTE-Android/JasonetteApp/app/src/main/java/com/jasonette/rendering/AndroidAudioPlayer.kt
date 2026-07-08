package com.jasonette.rendering

import android.media.AudioAttributes
import android.media.MediaPlayer
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Minimal production player for `$audio.play` URL playback. */
class AndroidAudioPlayer {
    private var player: MediaPlayer? = null
    private var activeContinuation: CancellableContinuation<Unit>? = null

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

        finishActive(ActionDispatcher.ActionException("Audio playback superseded"))
        player?.release()
        player = next

        suspendCancellableCoroutine { continuation ->
            activeContinuation = continuation
            next.setOnPreparedListener { mediaPlayer ->
                if (player !== mediaPlayer) {
                    if (continuation.isActive) {
                        continuation.resumeWithException(ActionDispatcher.ActionException("Audio playback superseded"))
                    }
                    return@setOnPreparedListener
                }
                try {
                    mediaPlayer.start()
                    if (continuation.isActive) {
                        activeContinuation = null
                        continuation.resume(Unit)
                    }
                } catch (e: Exception) {
                    mediaPlayer.release()
                    if (player === mediaPlayer) player = null
                    if (continuation.isActive) {
                        activeContinuation = null
                        continuation.resumeWithException(e)
                    }
                }
            }
            next.setOnErrorListener { mediaPlayer, _, _ ->
                mediaPlayer.release()
                if (player === mediaPlayer) player = null
                if (continuation.isActive) {
                    activeContinuation = null
                    continuation.resumeWithException(ActionDispatcher.ActionException("Audio playback failed"))
                }
                true
            }
            continuation.invokeOnCancellation {
                if (activeContinuation === continuation) activeContinuation = null
                if (player === next) player = null
                next.release()
            }
            try {
                next.prepareAsync()
            } catch (e: Exception) {
                next.release()
                if (player === next) player = null
                if (continuation.isActive) {
                    activeContinuation = null
                    continuation.resumeWithException(e)
                }
            }
        }
    }

    suspend fun pause(): Unit = withContext(Dispatchers.Main) {
        try {
            player?.pause()
        } catch (_: IllegalStateException) {
            // Ignore pause requests before playback reaches a pausable state.
        }
    }

    suspend fun stop(): Unit = withContext(Dispatchers.Main) {
        stopInternal(ActionDispatcher.ActionException("Audio playback stopped"))
    }

    fun release() {
        stopInternal(ActionDispatcher.ActionException("Audio playback released"))
    }

    private fun stopInternal(reason: Exception) {
        finishActive(reason)
        player?.release()
        player = null
    }

    private fun finishActive(reason: Exception) {
        activeContinuation?.let { continuation ->
            activeContinuation = null
            if (continuation.isActive) continuation.resumeWithException(reason)
        }
    }
}
