package com.dualreader.app.data.translation

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Query

/**
 * Retrofit interface for the Cloudflare Worker quota endpoint.
 * Same base URL as ProxyTranslationApi.
 */
interface QuotaApi {

    @GET("quota")
    suspend fun getQuota(@Query("installation_id") installationId: String): Response<QuotaResponse>
}

@JsonClass(generateAdapter = true)
data class QuotaResponse(
    @Json(name = "pages_used") val pagesUsed: Int = 0,
    @Json(name = "daily_limit") val dailyLimit: Int = 50,
    @Json(name = "remaining") val remaining: Int = 50,
    @Json(name = "reset_at") val resetAt: String = "",
)
