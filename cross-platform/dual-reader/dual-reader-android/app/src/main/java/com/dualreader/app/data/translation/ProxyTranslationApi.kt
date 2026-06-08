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

    @POST("translate/batch")
    suspend fun translateBatch(@Body request: ProxyBatchTranslateRequest): Response<ProxyBatchTranslateResponse>
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

/** Batch request — multiple pages in a single API call. */
@JsonClass(generateAdapter = true)
data class ProxyBatchTranslateRequest(
    @Json(name = "pages") val pages: List<BatchPage>,
    @Json(name = "source_lang") val sourceLang: String?,
    @Json(name = "target_lang") val targetLang: String,
)

@JsonClass(generateAdapter = true)
data class BatchPage(
    @Json(name = "index") val index: Int,
    @Json(name = "text") val text: String,
)

/** Batch response — array of translations. */
@JsonClass(generateAdapter = true)
data class ProxyBatchTranslateResponse(
    @Json(name = "translations") val translations: List<BatchTranslation> = emptyList(),
    @Json(name = "model") val model: String = "",
    @Json(name = "source_lang") val sourceLang: String = "",
    @Json(name = "target_lang") val targetLang: String = "",
    @Json(name = "error") val error: String? = null,
)

@JsonClass(generateAdapter = true)
data class BatchTranslation(
    @Json(name = "index") val index: Int = 0,
    @Json(name = "translated_text") val translatedText: String = "",
)
