package com.dualreader.app.ui

import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge

/**
 * Displays the in-app privacy policy loaded from assets.
 * Registered in AndroidManifest and linked from Settings.
 *
 * Uses a simple WebView to render the bundled HTML privacy policy.
 */
class PrivacyPolicyActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val webView = WebView(this).apply {
            webViewClient = WebViewClient()
            settings.loadWithOverviewMode = true
            settings.useWideViewPort = true
        }

        setContentView(webView)
        webView.loadUrl("file:///android_asset/privacy-policy.html")
    }

    override fun onBackPressed() {
        // No-op — finish the activity on back press
        finish()
    }
}
