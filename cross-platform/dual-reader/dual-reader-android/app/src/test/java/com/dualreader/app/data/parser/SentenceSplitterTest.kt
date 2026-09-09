package com.dualreader.app.data.parser

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for SentenceSplitter utility.
 */
class SentenceSplitterTest {

    @Test
    fun `splitSentences - empty text returns empty list`() {
        val result = SentenceSplitter.splitSentences("")
        assertTrue(result.isEmpty())
    }

    @Test
    fun `splitSentences - whitespace only returns empty list`() {
        val result = SentenceSplitter.splitSentences("   \n\t  \n  ")
        assertTrue(result.isEmpty())
    }

    @Test
    fun `splitSentences - single character returns as is`() {
        val result = SentenceSplitter.splitSentences("a")
        assertEquals(1, result.size)
        assertEquals("a", result[0])
    }

    @Test
    fun `splitSentences - basic sentence splitting works`() {
        val text = "Hello world. How are you? I am fine."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(3, result.size)
        assertEquals("Hello world.", result[0])
        assertEquals("How are you?", result[1])
        assertEquals("I am fine.", result[2])
    }

    @Test
    fun `splitSentences - dr abbreviation is not sentence boundary`() {
        val text = "Dr. Smith is here. Hello."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("Dr. Smith is here.", result[0])
        assertEquals("Hello.", result[1])
    }

    @Test
    fun `splitSentences - mr abbreviation is not sentence boundary`() {
        val text = "Mr. Jones arrived. Good morning."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("Mr. Jones arrived.", result[0])
        assertEquals("Good morning.", result[1])
    }

    @Test
    fun `splitSentences - mrs abbreviation is not sentence boundary`() {
        val text = "Mrs. Anderson waved. Welcome back."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("Mrs. Anderson waved.", result[0])
        assertEquals("Welcome back.", result[1])
    }

    @Test
    fun `splitSentences - prof abbreviation is not sentence boundary`() {
        val text = "Prof. Brown spoke. We listened."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("Prof. Brown spoke.", result[0])
        assertEquals("We listened.", result[1])
    }

    @Test
    fun `splitSentences - single uppercase initial is ignored`() {
        val text = "J. K. Rowling wrote Harry Potter. The series is famous."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("J. K. Rowling wrote Harry Potter.", result[0])
        assertEquals("The series is famous.", result[1])
    }

    @Test
    fun `splitSentences - Cyrillic initial is ignored`() {
        val text = "А. Пушкин is a famous poet. He wrote great works."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("А. Пушкин is a famous poet.", result[0])
        assertEquals("He wrote great works.", result[1])
    }

    @Test
    fun `splitSentences - question mark is boundary`() {
        val text = "Is it done? Yes."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("Is it done?", result[0])
        assertEquals("Yes.", result[1])
    }

    @Test
    fun `splitSentences - exclamation mark is boundary`() {
        val text = "Stop! Wait here."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("Stop!", result[0])
        assertEquals("Wait here.", result[1])
    }

    @Test
    fun `splitSentences - quotes after punctuation are handled`() {
        val text = "He said \"Hello.\" She replied \"Hi.\""
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("He said \"Hello.\"", result[0])
        assertEquals("She replied \"Hi.\"", result[1])
    }

    @Test
    fun `splitSentences - trailing whitespace is trimmed`() {
        val text = "First sentence.   Second sentence.  Third. "
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(3, result.size)
        assertEquals("First sentence.", result[0])
        assertEquals("Second sentence.", result[1])
        assertEquals("Third.", result[2])
    }

    @Test
    fun `splitSentences - ellipsis is boundary`() {
        val text = "Wait for it... Now go. Run."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(3, result.size)
        assertEquals("Wait for it...", result[0])
        assertEquals("Now go.", result[1])
        assertEquals("Run.", result[2])
    }

    @Test
    fun `splitSentences - etc abbreviation is not sentence boundary`() {
        val text = "etc. is an abbreviation. Good to know."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("etc. is an abbreviation.", result[0])
        assertEquals("Good to know.", result[1])
    }

    @Test
    fun `splitSentences - no punctuation returns single sentence`() {
        val text = "This is just one long sentence without any punctuation marks"
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(1, result.size)
        assertEquals(text, result[0])
    }

    @Test
    fun `splitSentences - multiple spaces between sentences`() {
        val text = "First.    Second.     Third."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(3, result.size)
        assertEquals("First.", result[0])
        assertEquals("Second.", result[1])
        assertEquals("Third.", result[2])
    }

    @Test
    fun `splitSentences - very long text splits correctly`() {
        val text = "This is the first sentence of a very long paragraph. " +
                   "This is the second sentence with more content. " +
                   "This is the third sentence continuing the text. " +
                   "This is the fourth sentence adding more. " +
                   "This is the fifth and final sentence."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(5, result.size)
        assertTrue(result[0].startsWith("This is the first"))
        assertTrue(result[4].endsWith("final sentence."))
    }

    @Test
    fun `splitSentences - brackets after punctuation are handled`() {
        val text = "He said \"test\".) She nodded.)"
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("He said \"test\".)", result[0])
        assertEquals("She nodded.)", result[1])
    }

    @Test
    fun `splitSentences - inc abbreviation is not sentence boundary`() {
        val text = "Apple Inc. is a company. It makes phones."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("Apple Inc. is a company.", result[0])
        assertEquals("It makes phones.", result[1])
    }

    @Test
    fun `splitSentences - co abbreviation is not sentence boundary`() {
        val text = "H. & Co. is a firm. They do business."
        val result = SentenceSplitter.splitSentences(text)
        assertEquals(2, result.size)
        assertEquals("H. & Co. is a firm.", result[0])
        assertEquals("They do business.", result[1])
    }
}