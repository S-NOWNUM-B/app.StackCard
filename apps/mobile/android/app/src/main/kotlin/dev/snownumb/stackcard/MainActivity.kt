package dev.snownumb.stackcard

import android.content.ActivityNotFoundException
import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.URI
import java.net.URISyntaxException

class MainActivity : FlutterActivity() {
    private var documentLinksChannel: MethodChannel? = null
    private var pendingPdfResult: MethodChannel.Result? = null
    private var pendingPdfBytes: ByteArray? = null

    private companion object {
        const val SAVE_PDF_REQUEST = 51848
        const val MAXIMUM_PDF_BYTES = 20 * 1024 * 1024
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        documentLinksChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stackcard/document_links",
        ).also { channel ->
            channel.setMethodCallHandler(::handleDocumentLink)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pendingPdfResult?.error("unavailable", "The file dialog was interrupted.", null)
        pendingPdfResult = null
        pendingPdfBytes = null
        documentLinksChannel?.setMethodCallHandler(null)
        documentLinksChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleDocumentLink(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "savePdf") {
            savePdf(call, result)
            return
        }
        if (call.method != "open" && call.method != "share") {
            result.notImplemented()
            return
        }
        val rawUrl = (call.arguments as? Map<*, *>)?.get("url") as? String
        val url = validatedDocumentUrl(rawUrl, allowContacts = call.method == "open")
        if (url == null) {
            result.error("invalid_url", "A public HTTP(S) URL is required.", null)
            return
        }
        if (isFinishing || isDestroyed) {
            result.error("unavailable", "The current activity is unavailable.", null)
            return
        }
        val intent = if (call.method == "open") {
            Intent(Intent.ACTION_VIEW, url).addCategory(Intent.CATEGORY_BROWSABLE)
        } else {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, rawUrl)
            }
            Intent.createChooser(sendIntent, null)
        }
        try {
            startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error("unavailable", "No application can perform this action.", null)
        } catch (_: SecurityException) {
            result.error("action_failed", "The system rejected the action.", null)
        } catch (_: IllegalArgumentException) {
            result.error("action_failed", "The system rejected the action.", null)
        }
    }

    private fun savePdf(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val bytes = arguments?.get("bytes") as? ByteArray
        val filename = arguments?.get("filename") as? String
        if (bytes == null || bytes.size !in 5..MAXIMUM_PDF_BYTES ||
            !bytes.copyOfRange(0, 5).contentEquals("%PDF-".toByteArray(Charsets.US_ASCII)) ||
            filename == null || !Regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}\\.pdf$").matches(filename)
        ) {
            result.error("invalid_pdf", "A bounded PDF and safe filename are required.", null)
            return
        }
        if (isFinishing || isDestroyed || pendingPdfResult != null) {
            result.error("unavailable", "The file dialog is unavailable.", null)
            return
        }
        pendingPdfResult = result
        pendingPdfBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
            putExtra(Intent.EXTRA_TITLE, filename)
        }
        try {
            startActivityForResult(intent, SAVE_PDF_REQUEST)
        } catch (_: Exception) {
            pendingPdfResult = null
            pendingPdfBytes = null
            result.error("unavailable", "The system file dialog could not be opened.", null)
        }
    }

    @Deprecated("Required by FlutterActivity's activity-result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_PDF_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPdfResult ?: return
        val bytes = pendingPdfBytes
        pendingPdfResult = null
        pendingPdfBytes = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(false)
            return
        }
        val uri = data?.data
        if (uri == null || bytes == null) {
            result.error("action_failed", "The selected file is unavailable.", null)
            return
        }
        Thread {
            try {
                val output = contentResolver.openOutputStream(uri, "w")
                    ?: throw IllegalStateException("No writable document stream")
                output.use { it.write(bytes) }
                runOnUiThread { result.success(true) }
            } catch (_: Exception) {
                runOnUiThread {
                    result.error("action_failed", "The PDF could not be saved.", null)
                }
            }
        }.start()
    }

    private fun validatedDocumentUrl(rawUrl: String?, allowContacts: Boolean): Uri? {
        if (rawUrl.isNullOrEmpty()) return null
        if (allowContacts && (
            Regex("^mailto:[a-zA-Z0-9.!$&'*+/=_^`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)+$").matches(rawUrl) ||
            Regex("^tel:\\+[0-9]{7,15}$").matches(rawUrl)
        )) return Uri.parse(rawUrl)
        return try {
            val url = URI(rawUrl)
            val scheme = url.scheme?.lowercase()
            if ((scheme != "https" && scheme != "http") ||
                url.isOpaque || url.host.isNullOrEmpty() ||
                url.rawUserInfo != null || url.port !in -1..65535
            ) {
                null
            } else {
                Uri.parse(rawUrl)
            }
        } catch (_: URISyntaxException) {
            null
        }
    }
}
