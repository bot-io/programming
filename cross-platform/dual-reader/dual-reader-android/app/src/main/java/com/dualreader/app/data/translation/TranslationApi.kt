package com.dualreader.app.data.translation

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.Header
import retrofit2.http.POST

/**
 * Retrofit interface for the GLM / Z.AI chat-completions API.
 *
 * Base URL should be set to "https://open.bigmodel.cn/api/paas/v4/"
 * when constructing the Retrofit instance.
 */
interface TranslationApi {

    @POST("chat/completions")
    suspend fun translate(
        @Header("Authorization") token: String,
        @Body request: GlmRequest
    ): Response<GlmResponse>
}
