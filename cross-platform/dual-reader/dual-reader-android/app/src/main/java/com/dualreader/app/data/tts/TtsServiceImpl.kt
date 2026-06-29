package com.dualreader.app.data.tts

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.dualreader.app.domain.services.TtsService
import com.dualreader.app.util.AppLogger
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Android TextToSpeech wrapper implementing TtsService.
 *
 * Lifecycle: created as a Singleton (tied to Application context).
 * The engine is initialized lazily on first use and reused across screens.
 *
 * Paragraph queue is managed internally — each paragraph gets a unique
 * utterance ID, and UtteranceProgressListener tracks which one is speaking.
 */
@Singleton
class TtsServiceImpl @Inject constructor(
    @ApplicationContext private val context: Context,
) : TtsService, TextToSpeech.OnInitListener {

    private var tts: TextToSpeech? = null
    private var initialized = AtomicBoolean(false)
    private var initFailed = AtomicBoolean(false)
    private var initInProgress = AtomicBoolean(false)

    private val _isSpeaking = AtomicBoolean(false)
    override val isSpeaking: Boolean get() = _isSpeaking.get()

    private val _currentParagraphIndex = AtomicInteger(-1)
    override val currentParagraphIndex: Int get() = _currentParagraphIndex.get()

    @Volatile
    private var speechRate: Float = 1.0f

    // Callbacks for current playback session
    // @Volatile ensures visibility across threads (main thread sets, TTS callback thread reads)
    @Volatile
    private var onParagraphStarted: ((Int) -> Unit)? = null
    @Volatile
    private var onCompletedCallback: (() -> Unit)? = null
    @Volatile
    private var onErrorCallback: ((String) -> Unit)? = null

    // Queue state (written by main thread, read by TTS callback thread)
    @Volatile
    private var currentParagraphs: List<String> = emptyList()
    @Volatile
    private var currentStartIndex: Int = 0

    override val isReady: Boolean
        get() = initialized.get() && tts != null

    override val isInitFailed: Boolean
        get() = initFailed.get() && !initialized.get() && !initInProgress.get()

    init {
        tts = TextToSpeech(context, this)
    }

    override fun reinitialize(): Boolean {
        if (isReady) {
            AppLogger.i("TtsServiceImpl: Already ready, no reinit needed")
            return false
        }
        if (initInProgress.get()) {
            AppLogger.i("TtsServiceImpl: Init already in progress")
            return false
        }

        AppLogger.i("TtsServiceImpl: Attempting reinitialization")
        initInProgress.set(true)

        // Shutdown existing instance if any
        // DR-112: Handle CancellationException separately for defensive consistency
        try {
            tts?.shutdown()
        } catch (e: kotlinx.coroutines.CancellationException) {
            // DR-112: Re-throw cancellation immediately (though unlikely in non-coroutine function)
            throw e
        } catch (e: Exception) {
            AppLogger.w("TtsServiceImpl: Failed to shutdown previous TTS instance: ${e.message}")
        }
        tts = null
        initFailed.set(false)
        initialized.set(false)

        // Create new instance
        tts = TextToSpeech(context, this)
        return true
    }

    override fun onInit(status: Int) {
        initInProgress.set(false)
        if (status == TextToSpeech.SUCCESS) {
            initialized.set(true)
            initFailed.set(false)
            AppLogger.i("TtsServiceImpl: TTS engine initialized successfully")
        } else {
            initialized.set(false)
            initFailed.set(true)
            AppLogger.e("TtsServiceImpl: TTS engine init failed (status=$status). Call reinitialize() to retry.")
        }
    }

    override fun isLanguageAvailable(langCode: String): Boolean {
        if (!isReady) return false
        val candidates = LocaleMapper.toLocaleCandidates(langCode)
        for (locale in candidates) {
            val result = tts?.setLanguage(locale) ?: TextToSpeech.LANG_NOT_SUPPORTED
            if (result != TextToSpeech.LANG_MISSING_DATA && result != TextToSpeech.LANG_NOT_SUPPORTED) {
                return true
            }
        }
        return false
    }

    override fun speak(
        paragraphs: List<String>,
        langCode: String,
        startIndex: Int,
        onParagraphStarted: (Int) -> Unit,
        onCompleted: () -> Unit,
        onError: (String) -> Unit,
    ) {
        if (!isReady) {
            onError("TTS engine not ready")
            return
        }

        if (paragraphs.isEmpty()) {
            onCompleted()
            return
        }

        // Stop any current playback
        stop()

        // Set language
        val locale = LocaleMapper.toLocale(langCode)
        val langResult = tts?.setLanguage(locale)
        if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
            // Try candidates
            val candidates = LocaleMapper.toLocaleCandidates(langCode)
            var found = false
            for (cand in candidates) {
                val r = tts?.setLanguage(cand)
                if (r != TextToSpeech.LANG_MISSING_DATA && r != TextToSpeech.LANG_NOT_SUPPORTED) {
                    found = true
                    break
                }
            }
            if (!found) {
                onError("No TTS voice available for language: $langCode")
                return
            }
        }

        // Set speech rate
        tts?.setSpeechRate(speechRate)

        // Store callbacks
        this.onParagraphStarted = onParagraphStarted
        this.onCompletedCallback = onCompleted
        this.onErrorCallback = onError
        this.currentParagraphs = paragraphs
        this.currentStartIndex = startIndex

        // Set up progress listener
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                val idx = utteranceId?.toIntOrNull() ?: return
                _currentParagraphIndex.set(idx)
                _isSpeaking.set(true)
                onParagraphStarted?.invoke(idx)
            }

            override fun onDone(utteranceId: String?) {
                val idx = utteranceId?.toIntOrNull() ?: return
                val nextIdx = idx + 1
                if (nextIdx < currentParagraphs.size) {
                    // Speak next paragraph
                    speakParagraph(nextIdx)
                } else {
                    // All done
                    _isSpeaking.set(false)
                    _currentParagraphIndex.set(-1)
                    onCompletedCallback?.invoke()
                    clearCallbacks()
                }
            }

            override fun onError(utteranceId: String?) {
                _isSpeaking.set(false)
                _currentParagraphIndex.set(-1)
                onErrorCallback?.invoke("TTS playback error")
                clearCallbacks()
            }
        })

        // Start from requested index
        speakParagraph(startIndex)
    }

    private fun speakParagraph(index: Int) {
        if (index < 0 || index >= currentParagraphs.size) {
            // DR-058: Reached the end (possibly by skipping blank paragraphs).
            // Must signal completion — otherwise the UI thinks TTS is still active.
            _isSpeaking.set(false)
            _currentParagraphIndex.set(-1)
            onCompletedCallback?.invoke()
            clearCallbacks()
            return
        }
        val text = currentParagraphs[index]
        if (text.isBlank()) {
            // Skip empty paragraphs
            speakParagraph(index + 1)
            return
        }

        val params = android.os.Bundle()
        tts?.speak(
            text,
            TextToSpeech.QUEUE_FLUSH,
            params,
            index.toString(), // utteranceId = paragraph index
        )
    }

    override fun stop() {
        // DR-059: Clear callbacks BEFORE calling tts?.stop() to prevent stale
        // onError callbacks (triggered asynchronously by stop) from leaking
        // into the next playback session. Mirrors the pause() fix.
        clearCallbacks()
        tts?.stop()
        _isSpeaking.set(false)
        _currentParagraphIndex.set(-1)
    }

    override fun pause() {
        // Clear callbacks BEFORE calling stop() so the UtteranceProgressListener's
        // onError (fired by stop) doesn't propagate to the caller as a false error.
        clearCallbacks()
        tts?.stop()
        _isSpeaking.set(false)
        // Don't reset currentParagraphIndex — allows resume from same position
    }

    override fun setSpeechRate(rate: Float) {
        speechRate = rate.coerceIn(0.5f, 2.0f)
        if (isReady) {
            tts?.setSpeechRate(speechRate)
        }
    }

    override fun getSpeechRate(): Float = speechRate

    override fun release() {
        stop()
        tts?.shutdown()
        tts = null
        initialized.set(false)
        initFailed.set(false)
        initInProgress.set(false)
    }

    private fun clearCallbacks() {
        onParagraphStarted = null
        onCompletedCallback = null
        onErrorCallback = null
    }
}
