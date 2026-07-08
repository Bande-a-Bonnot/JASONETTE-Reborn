package com.jasonette.rendering

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Base64
import androidx.core.content.FileProvider
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Minimal production bridge for `$util.share`. */
class AndroidShareHandler(private val context: Context) {
    suspend fun share(items: List<ActionDispatcher.ShareItem>) = withContext(Dispatchers.Main) {
        val text = items.mapNotNull { item -> item.text ?: textUrl(item) }.joinToString("\n").ifBlank { null }
        val streamUris = items.mapNotNull { streamUri(it) }
        val intent = when {
            streamUris.size > 1 -> Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(streamUris))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            streamUris.size == 1 -> Intent(Intent.ACTION_SEND).apply {
                putExtra(Intent.EXTRA_STREAM, streamUris.single())
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            else -> Intent(Intent.ACTION_SEND)
        }
        intent.type = shareMimeType(items, streamUris.isNotEmpty())
        text?.let { intent.putExtra(Intent.EXTRA_TEXT, it) }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(Intent.createChooser(intent, "Share").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun textUrl(item: ActionDispatcher.ShareItem): String? = item.url

    private fun streamUri(item: ActionDispatcher.ShareItem): Uri? = when {
        item.data != null -> dataUri(item)
        item.fileUrl != null -> fileUrlToContentUri(item.fileUrl)
        item.type.equals("image", ignoreCase = true) && item.url?.startsWith("content://") == true -> Uri.parse(item.url)
        else -> null
    }

    private fun dataUri(item: ActionDispatcher.ShareItem): Uri {
        val bytes = decodeBase64Data(item.data ?: "")
        val extension = when (item.contentType?.lowercase()) {
            "image/png" -> "png"
            "image/jpeg", "image/jpg" -> "jpg"
            "image/gif" -> "gif"
            "audio/m4a" -> "m4a"
            else -> when (item.type.lowercase()) {
                "image" -> "png"
                "audio" -> "m4a"
                "video" -> "mp4"
                else -> "bin"
            }
        }
        val file = File(shareCacheDir(), "share-${System.nanoTime()}.$extension")
        file.writeBytes(bytes)
        return FileProvider.getUriForFile(context, providerAuthority(), file)
    }

    private fun fileUrlToContentUri(value: String): Uri? {
        val uri = Uri.parse(value)
        return when (uri.scheme?.lowercase()) {
            "content" -> uri
            "file" -> {
                val file = File(uri.path ?: throw ActionDispatcher.ActionException("Invalid file URL"))
                FileProvider.getUriForFile(context, providerAuthority(), file)
            }
            else -> throw ActionDispatcher.ActionException("Unsupported share URI scheme")
        }
    }

    private fun decodeBase64Data(value: String): ByteArray {
        val base64 = value.substringAfter(",", value)
        return Base64.decode(base64, Base64.DEFAULT)
    }

    private fun shareCacheDir(): File = File(context.cacheDir, "share").apply { mkdirs() }

    private fun providerAuthority(): String = "${context.packageName}.fileprovider"

    private fun shareMimeType(items: List<ActionDispatcher.ShareItem>, hasStreams: Boolean): String = when {
        !hasStreams -> "text/plain"
        items.any { it.type.equals("image", ignoreCase = true) } -> "image/*"
        items.any { it.type.equals("video", ignoreCase = true) } -> "video/*"
        items.any { it.type.equals("audio", ignoreCase = true) } -> "audio/*"
        else -> "text/plain"
    }
}
