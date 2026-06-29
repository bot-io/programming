package com.dualreader.app.domain.services

/**
 * Text-to-Speech service for reading translated paragraphs aloud.
 *
 * Uses Android's built-in TextToSpeech engine. Zero API cost.
 */
interface TtsService {

    /** Whether the TTS engine is initialized and ready. */
    val isReady: Boolean

    /** Whether TTS initialization has failed and needs retry. */
    val isInitFailed: Boolean

    /** Whether TTS is currently speaking. */
    val isSpeaking: Boolean

    /** Current paragraph index being spoken, or -1 if idle. */
    val currentParagraphIndex: Int

    /** Whether a TTS engine is available for the given language code. */
    fun isLanguageAvailable(langCode: String): Boolean

    /**
     * Attempt to reinitialize the TTS engine if it previously failed.
     * Returns true if reinit was triggered, false if engine is already ready.
     */
    fun reinitialize(): Boolean

    /**
     * Speak a list of paragraphs sequentially.
     * Each paragraph is spoken in order; [onParagraphStarted] is called
     * when each paragraph begins (for UI highlighting).
     */
    fun speak(
        paragraphs: List<String>,
        langCode: String,
        startIndex: Int = 0,
        onParagraphStarted: (index: Int) -> Unit,
        onCompleted: () -> Unit,
        onError: (message: String) -> Unit,
    )

    /** Stop any current playback. */
    fun stop()

    /** Pause current playback (stops engine; resume restarts current paragraph). */
    fun pause()

    /** Set speech rate (0.5 = slow, 1.0 = normal, 2.0 = fast). */
    fun setSpeechRate(rate: Float)

    /** Get the current speech rate. */
    fun getSpeechRate(): Float

    /** Release TTS resources. Call when leaving the reader screen. */
    fun release()
}
