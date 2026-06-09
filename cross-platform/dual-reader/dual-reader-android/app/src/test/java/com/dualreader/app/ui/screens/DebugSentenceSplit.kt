package com.dualreader.app.ui.screens

import org.junit.Test

class DebugSentenceSplit {

    @Test
    fun debugSplit() {
        val regex = Regex("""(?<=[.!?…]["'"»'')\]]*\s+)""")
        val texts = listOf(
            "First sentence. Second sentence.",
            "Hello! World!",
            "What? Why?",
        )
        for (text in texts) {
            val parts = text.split(regex).filter { it.isNotBlank() }
            println("'$text' -> ${parts.size} parts: $parts")
        }
    }
}
