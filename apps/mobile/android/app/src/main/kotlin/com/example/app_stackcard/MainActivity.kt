package com.example.app_stackcard

import android.content.ActivityNotFoundException
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
        documentLinksChannel?.setMethodCallHandler(null)
        documentLinksChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleDocumentLink(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "open" && call.method != "share") {
            result.notImplemented()
            return
        }
        val rawUrl = (call.arguments as? Map<*, *>)?.get("url") as? String
        val url = validatedDocumentUrl(rawUrl)
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

    private fun validatedDocumentUrl(rawUrl: String?): Uri? {
        if (rawUrl.isNullOrEmpty()) return null
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
