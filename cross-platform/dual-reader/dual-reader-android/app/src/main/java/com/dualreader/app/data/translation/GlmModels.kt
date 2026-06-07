package com.dualreader.app.data.translation

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * A single message in the GLM chat-completions request.
 */
@JsonClass(generateAdapter = true)
data class GlmMessage(
    @Json(name = "role") val role: String,
    @Json(name = "content") val content: String
)

/**
 * Request body for POST /chat/completions.
 */
@JsonClass(generateAdapter = true)
data class GlmRequest(
    @Json(name = "model") val model: String,
    @Json(name = "messages") val messages: List<GlmMessage>,
    @Json(name = "temperature") val temperature: Double = 0.3,
    @Json(name = "max_tokens") val maxTokens: Int = 4096
)

/**
 * A single choice returned in the GLM response.
 */
@JsonClass(generateAdapter = true)
data class GlmChoice(
    @Json(name = "message") val message: GlmMessage
)

/**
 * Top-level response body from /chat/completions.
 */
@JsonClass(generateAdapter = true)
data class GlmResponse(
    @Json(name = "choices") val choices: List<GlmChoice> = emptyList()
)
