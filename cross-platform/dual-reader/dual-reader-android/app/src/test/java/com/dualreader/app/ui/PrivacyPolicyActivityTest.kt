package com.dualreader.app.ui

import android.content.Context
import android.content.Intent
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Tests for the PrivacyPolicyActivity and privacy policy infrastructure.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class PrivacyPolicyActivityTest {

    private val context: Context
        get() = RuntimeEnvironment.getApplication()

    private fun readPrivacyPolicyHtml(): String {
        val inputStream = context.assets.open("privacy-policy.html")
        val reader = BufferedReader(InputStreamReader(inputStream))
        val sb = StringBuilder()
        var line: String? = reader.readLine()
        while (line != null) {
            sb.append(line)
            line = reader.readLine()
        }
        reader.close()
        return sb.toString()
    }

    @Test
    fun `privacy policy activity is registered in manifest`() {
        val intent = Intent(context, PrivacyPolicyActivity::class.java)
        val resolveInfo = context.packageManager.resolveActivity(intent, 0)
        assertThat(resolveInfo).isNotNull()
    }

    @Test
    fun `privacy policy activity can be launched`() {
        val activity = Robolectric.buildActivity(PrivacyPolicyActivity::class.java)
            .create()
            .get()
        assertThat(activity).isNotNull()
        assertThat(activity.isFinishing).isFalse()
    }

    @Test
    fun `privacy policy html exists in assets`() {
        val assets = context.assets.list("")
        assertThat(assets).isNotNull()
        assertThat(assets).asList().contains("privacy-policy.html")
    }

    @Test
    fun `privacy policy html is non-empty and contains expected text`() {
        val html = readPrivacyPolicyHtml()
        assertThat(html).isNotEmpty()
        assertThat(html).contains("Privacy Policy")
        assertThat(html).contains("Dual Reader")
    }

    @Test
    fun `privacy policy mentions key sections`() {
        val html = readPrivacyPolicyHtml()
        assertThat(html).contains("Data We Collect")
        assertThat(html).contains("Translation")
        assertThat(html).contains("Local Storage")
        assertThat(html).contains("Contact")
    }

    @Test
    fun `privacy policy states no personal data collection`() {
        val html = readPrivacyPolicyHtml()
        assertThat(html).contains("do not collect")
    }

    @Test
    fun `privacy policy has contact email`() {
        val html = readPrivacyPolicyHtml()
        assertThat(html).contains("@gmail.com")
    }
}
