package com.dualreader.app.ui

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Tests for the splash screen configuration.
 *
 * Validates that:
 * - Splash theme resources resolve correctly
 * - Splash background color is defined and matches the expected deep dark theme
 * - Launcher icon resource exists (used as splash animated icon)
 * - MainActivity can be created with the splash theme without crashing
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SplashScreenTest {

    private val context
        get() = RuntimeEnvironment.getApplication()

    @Test
    fun `splash background color resource exists`() {
        val color = context.resources.getColor(
            com.dualreader.app.R.color.splash_background,
            context.theme
        )
        // Should be a valid color (non-zero), specifically our deep dark #1A1A2E
        assertThat(color).isNotEqualTo(0)
    }

    @Test
    fun `splash background color matches expected value`() {
        val expectedColor = 0xFF1A1A2E.toInt()
        val color = context.resources.getColor(
            com.dualreader.app.R.color.splash_background,
            context.theme
        )
        assertThat(color).isEqualTo(expectedColor)
    }

    @Test
    fun `launcher icon resource exists`() {
        // The splash screen uses ic_launcher as its animated icon
        val drawable = context.resources.getDrawable(
            com.dualreader.app.R.mipmap.ic_launcher,
            context.theme
        )
        assertThat(drawable).isNotNull()
    }

    @Test
    fun `main activity creates without crashing`() {
        val activity = Robolectric.buildActivity(MainActivity::class.java)
            .setup()

        assertThat(activity.get()).isNotNull()
        assertThat(activity.get().isFinishing).isFalse()
    }

    @Test
    fun `main activity theme resolves correctly`() {
        val activity = Robolectric.buildActivity(MainActivity::class.java)
            .setup()
            .get()

        val theme = activity.theme
        assertThat(theme).isNotNull()
    }
}
