fun main() {
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
