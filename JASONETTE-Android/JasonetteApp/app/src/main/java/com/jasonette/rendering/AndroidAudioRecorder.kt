package com.jasonette.rendering

import android.content.Context
import android.media.MediaRecorder
import android.net.Uri
import android.util.Base64
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

fun createAndroidAudioRecordFile(context: Context): File {
    val directory = File(context.getExternalFilesDir(null) ?: context.filesDir, "audio").apply { mkdirs() }
    val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
    return File.createTempFile("${timestamp}_", ".m4a", directory)
}

@Suppress("DEPRECATION")
fun startAndroidAudioRecording(file: File): ActiveAndroidAudioRecording {
    val recorder = MediaRecorder()
    try {
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        recorder.setAudioChannels(2)
        recorder.setAudioSamplingRate(48_000)
        recorder.setOutputFile(file.absolutePath)
        recorder.prepare()
        recorder.start()
        return ActiveAndroidAudioRecording(file, recorder)
    } catch (error: Exception) {
        runCatching { recorder.reset() }
        runCatching { recorder.release() }
        file.delete()
        throw ActionDispatcher.ActionException(error.message ?: "Audio recorder failed to start")
    }
}

class ActiveAndroidAudioRecording(
    private val file: File,
    private val recorder: MediaRecorder
) {
    private var released = false

    fun stopPayload(): Map<String, Any> {
        val stopError = releaseRecorder(stop = true)
        if (stopError != null) {
            file.delete()
            throw ActionDispatcher.ActionException(stopError.message ?: "Audio recording failed")
        }
        val bytes = file.readBytes()
        if (bytes.isEmpty()) {
            file.delete()
            throw ActionDispatcher.ActionException("Audio recording was empty")
        }
        val dataUri = "data:audio/m4a;base64,${Base64.encodeToString(bytes, Base64.NO_WRAP)}"
        val fileUrl = Uri.fromFile(file).toString()
        return mapOf(
            "file_url" to fileUrl,
            "url" to fileUrl,
            "content_type" to "audio/m4a",
            "data_uri" to dataUri
        )
    }

    fun cancel(delete: Boolean = true) {
        releaseRecorder(stop = false)
        if (delete) file.delete()
    }

    private fun releaseRecorder(stop: Boolean): Throwable? {
        if (released) return null
        released = true
        val stopError = if (stop) runCatching { recorder.stop() }.exceptionOrNull() else null
        runCatching { recorder.reset() }
        runCatching { recorder.release() }
        return stopError
    }
}
