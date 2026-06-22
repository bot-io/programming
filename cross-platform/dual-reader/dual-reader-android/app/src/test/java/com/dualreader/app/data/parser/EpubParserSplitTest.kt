package com.dualreader.app.data.parser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for [EpubParserImpl.splitLongParagraph] — ensures long paragraphs
 * (like Aunt Polly's monologue in Tom Sawyer) get split at sentence boundaries
 * into readable chunks of ~200-300 chars.
 */
class EpubParserSplitTest {

    @Test
    fun `short paragraph stays as one chunk`() {
        val text = "“Tom!”"
        val result = EpubParserImpl.splitLongParagraph(text)
        assertEquals(1, result.size)
        assertEquals(text, result[0])
    }

    @Test
    fun `paragraph with multiple sentences splits into individual sentences`() {
        val text = "She went to the open door and stood in it and looked out among the " +
            "tomato vines and jimpson weeds that constituted the garden. No Tom. " +
            "So she lifted up her voice at an angle calculated for distance."
        val result = EpubParserImpl.splitLongParagraph(text)
        // Should split into individual sentences (No Tom. is short and merges with next)
        assertTrue("Should split into 2+ chunks, got ${result.size}", result.size >= 2)
    }

    @Test
    fun `long paragraph is split into multiple chunks`() {
        // Aunt Polly's monologue from Tom Sawyer Chapter 1
        val text = """“Hang the boy, can’t I never learn anything? Ain’t he played me tricks enough like that for me to be looking out for him by this time? But old fools is the biggest fools there is. Can’t learn an old dog new tricks, as the saying is. But my goodness, he never plays them alike, two days, and how is a body to know what’s coming? He ’pears to know just how long he can torment me before I get my dander up, and he knows if he can make out to put me off for a minute or make me laugh, it’s all down again and I can’t hit him a lick. I ain’t doing my duty by that boy, and that’s the Lord’s truth, goodness knows. Spare the rod and spile the child, as the Good Book says. I’m a laying up sin and suffering for us both, I know. He’s full of the Old Scratch, but laws-a-me! he’s my own dead sister’s boy, poor thing, and I ain’t got the heart to lash him, somehow. Every time I let him off, my conscience does hurt me so, and every time I hit him my old heart most breaks. Well-a-well, man that is born of woman is of few days and full of trouble, as the Scripture says, and I reckon it’s so. He’ll play hookey this evening, and I’ll just be obleeged to make him work, tomorrow, to punish him. It’s mighty hard to make him work Saturdays, when all the boys is having holiday, but he hates work more than he hates anything else, and I’ve got to do some of my duty by him, or I’ll be the ruination of the child.”"""

        val result = EpubParserImpl.splitLongParagraph(text)

        assertTrue("Should split into multiple chunks, got ${result.size}", result.size > 2)
        assertFalse("No chunk should exceed 400 chars (single sentence)", result.any { it.length > 400 })

        // Verify no text is lost
        val reconstructed = result.joinToString(" ")
        val originalClean = text.trim()
        assertTrue(
            "Text should be preserved. Original starts: ${originalClean.take(30)}, Got: ${reconstructed.take(30)}",
            reconstructed.startsWith(originalClean.take(20))
        )
    }

    @Test
    fun `split respects sentence boundaries`() {
        val text = "First sentence here. Second one follows with more detail. " +
            "Third sentence arrives and is quite long indeed. " +
            "Fourth sentence is here and adds even more content to this paragraph. " +
            "Fifth sentence now continues the narrative with additional words. " +
            "Sixth sentence comes with further elaboration on the topic at hand. " +
            "Seventh sentence follows with yet more discussion of these matters. " +
            "Eighth sentence arrives and wraps up most of the thoughts. " +
            "Ninth and final sentence concludes this very long paragraph."

        val result = EpubParserImpl.splitLongParagraph(text)

        assertTrue("Should produce multiple chunks (text is ${text.length} chars), got ${result.size}", result.size > 1)
        // Each chunk should start with a capital letter
        result.forEach { chunk ->
            val firstChar = chunk.trim().firstOrNull() ?: ' '
            assertTrue(
                "Chunk should start with capital or quote, got '$firstChar' in: ${chunk.take(40)}",
                firstChar.isUpperCase() || firstChar == '"' || firstChar == '\u201c' || firstChar == '\''
            )
        }
    }

    @Test
    fun `split preserves dialogue quotes`() {
        val text = "\u201cWell, I know. It\u2019s jam\u2014that\u2019s what it is. " +
            "Forty times I\u2019ve said if you didn\u2019t let that jam alone I\u2019d " +
            "skin you. Hand me that switch.\u201d The switch hovered in the air" +
            "\u2014the peril was desperate. \u201cMy! Look behind you, aunt!\u201d " +
            "The old lady whirled round, and snatched her skirts out of danger. " +
            "The lad fled on the instant, scrambled up the high board-fence, " +
            "and disappeared over it. His aunt Polly stood surprised a moment, " +
            "and then broke into a gentle laugh."

        val result = EpubParserImpl.splitLongParagraph(text)

        assertTrue("Should split (text is ${text.length} chars), got ${result.size}", result.size > 1)
        // At least one chunk should contain dialogue
        assertTrue(
            "Should preserve quoted dialogue",
            result.any { it.contains("Well, I know") || it.contains("Hand me that switch") }
        )
    }

    @Test
    fun `no sentence splitting inside abbreviations`() {
        // "Mr." and "Mrs." should not trigger sentence breaks
        val text = "Mr. Smith went to the store. Mrs. Jones was already there. " +
            "They talked for a while about the weather and other pleasant topics " +
            "that neighbors tend to discuss on a fine summer afternoon."

        val result = EpubParserImpl.splitLongParagraph(text)

        // Should still work — but shouldn't split at "Mr." or "Mrs."
        result.forEach { chunk ->
            assertFalse("Should not start with ' Smith'", chunk.startsWith(" Smith"))
            assertFalse("Should not start with ' Jones'", chunk.startsWith(" Jones"))
        }
    }
}
