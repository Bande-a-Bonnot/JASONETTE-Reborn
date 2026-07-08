package com.jasonette.rendering

import android.content.Context
import android.content.Intent
import android.net.Uri

/** Minimal production launcher for `$media.play` video URL playback. */
class AndroidMediaPlayback(private val context: Context) {
    suspend fun play(url: String) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(url), "video/mp4")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            throw ActionDispatcher.ActionException(e.message ?: "Video playback unavailable")
        }
    }
}
