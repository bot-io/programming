package com.dualreader.app.data.di

import com.dualreader.app.data.parser.EpubParserImpl
import com.dualreader.app.domain.services.EpubParserService
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt DI module that binds the domain [EpubParserService] interface
 * to its data-layer implementation [EpubParserImpl].
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class ParserModule {

    @Binds
    @Singleton
    abstract fun bindEpubParserService(
        impl: EpubParserImpl,
    ): EpubParserService
}
