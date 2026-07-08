package com.jasonette.rendering

import android.content.Context
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning

/**
 * Small adapter around Google Play services' scanner UI.
 *
 * GMS Code Scanner owns the camera UI/permission surface, so the Jasonette app
 * does not need CameraX plumbing or a CAMERA permission for this baseline.
 */
fun startAndroidVisionScan(
    context: Context,
    request: ActionDispatcher.VisionScanRequest,
    onResult: (Map<String, Any>) -> Unit,
    onCancel: () -> Unit
) {
    val scanner = GmsBarcodeScanning.getClient(context, scannerOptions(request))
    scanner.startScan()
        .addOnSuccessListener { barcode ->
            val content = barcode.rawValue ?: barcode.displayValue
            if (content.isNullOrBlank()) {
                onCancel()
            } else {
                onResult(
                    mapOf(
                        "content" to content,
                        "type" to barcode.format,
                        "raw_type" to barcode.format,
                        "format" to barcodeFormatName(barcode.format)
                    )
                )
            }
        }
        .addOnCanceledListener { onCancel() }
        .addOnFailureListener { onCancel() }
}

private fun scannerOptions(request: ActionDispatcher.VisionScanRequest): GmsBarcodeScannerOptions {
    val builder = GmsBarcodeScannerOptions.Builder()
    if (request.type.equals("qr", ignoreCase = true) || request.type.equals("qrcode", ignoreCase = true)) {
        builder.setBarcodeFormats(Barcode.FORMAT_QR_CODE)
    }
    return builder.build()
}

private fun barcodeFormatName(format: Int): String = when (format) {
    Barcode.FORMAT_QR_CODE -> "qr"
    Barcode.FORMAT_AZTEC -> "aztec"
    Barcode.FORMAT_CODABAR -> "codabar"
    Barcode.FORMAT_CODE_39 -> "code_39"
    Barcode.FORMAT_CODE_93 -> "code_93"
    Barcode.FORMAT_CODE_128 -> "code_128"
    Barcode.FORMAT_DATA_MATRIX -> "data_matrix"
    Barcode.FORMAT_EAN_8 -> "ean_8"
    Barcode.FORMAT_EAN_13 -> "ean_13"
    Barcode.FORMAT_ITF -> "itf"
    Barcode.FORMAT_PDF417 -> "pdf417"
    Barcode.FORMAT_UPC_A -> "upc_a"
    Barcode.FORMAT_UPC_E -> "upc_e"
    else -> "unknown"
}
