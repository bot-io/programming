package com.dualreader.app.data.di

import android.content.Context
import android.net.ConnectivityManager
import com.dualreader.app.data.translation.CloudTranslationServiceImpl
import com.dualreader.app.data.translation.GlmTranslationServiceImpl
import com.dualreader.app.data.translation.MlKitTranslationServiceImpl
import com.dualreader.app.data.translation.ProxyTranslationApi
import com.dualreader.app.data.translation.TranslationApi
import com.dualreader.app.domain.services.TranslationService
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Named
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class TranslationModule {

    companion object {

        /**
         * Cloudflare Worker proxy URL.
         * After deploying the worker, update this to your workers.dev subdomain.
         * Format: https://dual-reader-translate.<your-account>.workers.dev/
         */
        private const val PROXY_BASE_URL = "https://dual-reader-translate.dualreader.workers.dev/"

        /** Legacy direct GLM API base URL (for "bring your own key" mode). */
        private const val GLM_DIRECT_BASE_URL = "https://open.bigmodel.cn/api/paas/v4/"

        @Provides
        @Singleton
        fun provideMoshi(): Moshi =
            Moshi.Builder()
                .addLast(KotlinJsonAdapterFactory())
                .build()

        @Provides
        @Singleton
        fun provideOkHttpClient(): OkHttpClient =
            OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build()

        @Provides
        @Singleton
        fun provideProxyTranslationApi(
            okHttpClient: OkHttpClient,
            moshi: Moshi
        ): ProxyTranslationApi =
            Retrofit.Builder()
                .baseUrl(PROXY_BASE_URL)
                .client(okHttpClient)
                .addConverterFactory(MoshiConverterFactory.create(moshi))
                .build()
                .create(ProxyTranslationApi::class.java)

        /** Legacy direct GLM API (for "bring your own key" mode). */
        @Provides
        @Singleton
        fun provideTranslationApi(
            okHttpClient: OkHttpClient,
            moshi: Moshi
        ): TranslationApi =
            Retrofit.Builder()
                .baseUrl(GLM_DIRECT_BASE_URL)
                .client(okHttpClient)
                .addConverterFactory(MoshiConverterFactory.create(moshi))
                .build()
                .create(TranslationApi::class.java)

        @Provides
        @Singleton
        fun provideConnectivityManager(
            @ApplicationContext context: Context
        ): ConnectivityManager =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        @Provides
        @Singleton
        @Named("mlkit")
        fun provideMlKitTranslationService(): MlKitTranslationServiceImpl =
            MlKitTranslationServiceImpl()
    }

    /**
     * Binds [CloudTranslationServiceImpl] as the primary [TranslationService].
     * This calls the Cloudflare Worker proxy — no API key in the APK.
     */
    @Binds
    @Singleton
    abstract fun bindTranslationService(
        impl: CloudTranslationServiceImpl
    ): TranslationService
}
