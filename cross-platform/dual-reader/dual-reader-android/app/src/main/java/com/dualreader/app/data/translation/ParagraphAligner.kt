package com.dualreader.app.data.translation

/**
 * Cleans paragraph markers from translated text (DR-263).
 *
 * ## History — why this object exists
 *
 * v1.0.94–1.0.101 used **marker-based batch stitching**: paragraphs were
 * joined with numbered markers into one text blob, translated as a single
 * request, then split back by the markers. This broke repeatedly:
 *
 * - v1 markers `⟦N⟧` (U+27E6/U+27E7): stripped by ML Kit, occasionally by cloud
 * - v2 markers `@@N@@`: better, but still mangled/merged often enough that
 *   translation segments mismatched their originals (reported twice by the
 *   user: adjacent dialogue fragments merged into one translation box).
 *
 * DR-263 removed marker stitching entirely: batches now use the **array-based**
 * `translatePages` endpoint (JSON array in, index-keyed translations out),
 * which guarantees 1:1 segment alignment regardless of translation service.
 *
 * The ONLY remaining responsibility of this object is defensive: old cache
 * entries (written before DR-263) may still contain markers of either format.
 * [stripMarkers] removes them before display; [hasMarkers] detects them.
 *
 * **Do NOT reintroduce marker-based stitching.** See
 * `TranslatePageMarkerBatchTest` for the regression tests that enforce the
 * array-based approach.
 */
object ParagraphAligner {

    // ── Marker constants ───────────────────────────────────────────────────────

    /** Regex matching v2 paragraph markers: @@N@@ where N is a positive integer. */
    private val MARKER_REGEX = Regex("""@@(\d+)@@""")

    /** Regex matching v2 markers plus trailing whitespace (for stripping). */
    private val MARKER_STRIP_REGEX = Regex("""@@\d+@@\s*""")

    /**
     * Regex matching legacy v1 markers: ⟦N⟧ (U+27E6/U+27E7) plus trailing
     * whitespace. Pre-DR-263 cache entries may contain these.
     */
    private val LEGACY_MARKER_REGEX = Regex("[\\u27E6]\\d+[\\u27E7]\\s*")

    // ── Detection ──────────────────────────────────────────────────────────────

    /**
     * Returns true if [text] contains v2 (`@@N@@`) paragraph markers.
     * Legacy `⟦N⟧` markers are NOT detected — they predate DR-263 and are
     * only expected in old cache entries, which are always passed through
     * [stripMarkers].
     */
    fun hasMarkers(text: String): Boolean = MARKER_REGEX.containsMatchIn(text)

    // ── Stripping ──────────────────────────────────────────────────────────────

    /**
     * Strips paragraph markers from text — both the v2 `@@N@@` format and
     * the legacy v1 `⟦N⟧` format. Old cache entries may contain either,
     * so both must be removed before display.
     *
     * @return Text with all markers (and whitespace immediately after them)
     *         removed, trimmed.
     */
    fun stripMarkers(text: String): String {
        if (!MARKER_STRIP_REGEX.containsMatchIn(text) && !LEGACY_MARKER_REGEX.containsMatchIn(text)) {
            return text.trim()
        }
        return text
            .replace(LEGACY_MARKER_REGEX, "")
            .replace(MARKER_STRIP_REGEX, "")
            .trim()
    }
}
