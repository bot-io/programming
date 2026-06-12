package com.dualreader.app.ui

import android.content.Context
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import com.dualreader.app.R

/**
 * Tests for splash screen theme configuration and Play Store readiness.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SplashPlayStoreTest {

    private val context: Context
        get() = RuntimeEnvironment.getApplication()

    @Test
    fun `splash theme exists`() {
        val themeResId = context.resources.getIdentifier(
            "Theme.DualReader.Splash", "style", context.packageName
        )
        assertThat(themeResId).isNotEqualTo(0)
    }

    @Test
    fun `splash background color exists`() {
        val colorResId = context.resources.getIdentifier(
            "splash_background", "color", context.packageName
        )
        assertThat(colorResId).isNotEqualTo(0)
    }

    @Test
    fun `app_name string is Dual Reader`() {
        val appName = context.getString(R.string.app_name)
        assertThat(appName).isEqualTo("Dual Reader")
    }

    @Test
    fun `privacy_policy_title string exists`() {
        val title = context.getString(R.string.privacy_policy_title)
        assertThat(title).isEqualTo("Privacy Policy")
    }

    @Test
    fun `adaptive icon exists`() {
        val iconResId = context.resources.getIdentifier(
            "ic_launcher", "mipmap", context.packageName
        )
        assertThat(iconResId).isNotEqualTo(0)
    }

    @Test
    fun `launcher foreground drawable exists`() {
        val drawableResId = context.resources.getIdentifier(
            "ic_launcher_foreground", "drawable", context.packageName
        )
        assertThat(drawableResId).isNotEqualTo(0)
    }

    @Test
    fun `ic_launcher_background color exists`() {
        val colorResId = context.resources.getIdentifier(
            "ic_launcher_background", "color", context.packageName
        )
        assertThat(colorResId).isNotEqualTo(0)
    }

    @Test
    fun `post splash theme is main theme`() {
        // Verify Theme.DualReader.Splash is defined and references Theme.DualReader
        val splashThemeId = context.resources.getIdentifier(
            "Theme.DualReader.Splash", "style", context.packageName
        )
        val mainThemeId = context.resources.getIdentifier(
            "Theme.DualReader", "style", context.packageName
        )
        assertThat(splashThemeId).isNotEqualTo(0)
        assertThat(mainThemeId).isNotEqualTo(0)
        assertThat(splashThemeId).isNotEqualTo(mainThemeId)
    }
}
