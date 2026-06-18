package com.dualreader.app.data.di

import com.dualreader.app.data.tts.TtsServiceImpl
import com.dualreader.app.domain.services.TtsService
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class TtsModule {

    @Binds
    @Singleton
    abstract fun bindTtsService(impl: TtsServiceImpl): TtsService
}
