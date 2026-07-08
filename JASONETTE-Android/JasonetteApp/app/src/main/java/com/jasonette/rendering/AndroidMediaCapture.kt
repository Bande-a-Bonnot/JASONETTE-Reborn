package com.jasonette.rendering

import android.content.Context
import android.net.Uri
import android.util.Base64
import androidx.core.content.FileProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

fun createAndroidMediaOutputUri(context: Context, mediaType: String): Uri {
    val extension = if (mediaType == "video") "mp4" else "jpg"
    val directory = File(context.getExternalFilesDir(null) ?: context.filesDir, "media").apply { mkdirs() }
    val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
    val file = File.createTempFile("${timestamp}_", ".$extension", directory)
    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}

fun androidMediaCapturePayload(
    context: Context,
    request: ActionDispatcher.MediaCaptureRequest,
    uri: Uri
): Map<String, Any> = if (request.mediaType == "video") {
    mapOf(
        "file_url" to uri.toString(),
        "content_type" to "video/mp4"
    )
} else {
    val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        ?: throw ActionDispatcher.ActionException("Unable to read captured image")
    val data = Base64.encodeToString(bytes, Base64.NO_WRAP)
    mapOf(
        "data" to data,
        "data_uri" to "data:image/jpeg;base64,$data",
        "content_type" to "image/jpeg"
    )
}
