package com.dualreader.app.data.di

import com.dualreader.app.data.pagination.PaginationServiceImpl
import com.dualreader.app.domain.services.PaginationService
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class PaginationModule {

    @Binds
    @Singleton
    abstract fun bindPaginationService(impl: PaginationServiceImpl): PaginationService
}
