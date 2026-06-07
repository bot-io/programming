package com.dualreader.app.data.translation

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

/**
 * Retrofit interface for the Cloudflare Worker translation proxy.
 *
 * The proxy holds the Z.AI API key server-side, so the app never sees it.
 * Base URL should be set to the worker URL (e.g. https://dual-reader-translate.<account>.workers.dev/).
 */
interface ProxyTranslationApi {

    @POST("translate")
    suspend fun translate(@Body request: ProxyTranslateRequest): Response<ProxyTranslateResponse>
}

/** Request body sent to the Cloudflare Worker. */
@JsonClass(generateAdapter = true)
data class ProxyTranslateRequest(
    @Json(name = "text") val text: String,
    @Json(name = "source_lang") val sourceLang: String?,
    @Json(name = "target_lang") val targetLang: String,
)

/** Response body from the Cloudflare Worker. */
@JsonClass(generateAdapter = true)
data class ProxyTranslateResponse(
    @Json(name = "translated_text") val translatedText: String = "",
    @Json(name = "model") val model: String = "",
    @Json(name = "source_lang") val sourceLang: String = "",
    @Json(name = "target_lang") val targetLang: String = "",
    @Json(name = "error") val error: String? = null,
)
