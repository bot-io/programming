# Dual-Reader Android App

## Project
Bilingual paragraph-by-paragraph e-book reader. Kotlin, Jetpack Compose, Hilt DI, Room v7, DataStore, ML Kit Translation, Google Play Billing.

## Location
`D:\programming\cross-platform\dual-reader\dual-reader-android\`

## Build
```bash
taskkill //F //IM java.exe 2>/dev/null; sleep 3
export JAVA_HOME="/c/Users/Svetlin/.jdks/temurin-21/jdk-21.0.11+10"
./gradlew assembleDebug --no-daemon
cp app/build/outputs/apk/debug/app-arm64-v8a-debug.apk "C:/Users/Svetlin/dual-reader-{VERSION}.apk"
```

## Test
```bash
./gradlew :app:testDebugUnitTest --no-daemon -Djava.io.tmpdir=/tmp
```

## Current State
- v1.0.62, ~870 tests, ~85% coverage (target 90%+)
- Room DB version 7, fallbackToDestructiveMigration
- 7 pre-installed EPUBs in app/src/main/assets/books/

## Test Quirks (CRITICAL)
1. FakeDataStore class for DataStore tests (no file I/O)
2. `java.io.tmpdir` is broken in Hermes terminal — use `System.getProperty("user.home")`
3. Robolectric causes OOM — remove `@RunWith` + `@Config` entirely, don't just @Ignore
4. PreInstalledBooksInitializerTest: use flag `_v3`, check `successCount > 0`
5. No `forkEvery=1` — causes JVM crashes
6. 4GB heap + 1GB metaspace in build.gradle.kts
7. `testImplementation("org.json:json:20240303")` needed for JSONObject in JVM tests
8. ViewModel tests: `StandardTestDispatcher` + `Dispatchers.setMain()`, `advanceUntilIdle()`, `backgroundScope` collector for `WhileSubscribed(5000)` StateFlows

## Architecture
- MVVM with Compose
- AppLogger methods take only `message: String`
- ML Kit: `TranslateRemoteModel` for delete; `langCode` IS the language tag string
- MlKitModelManager: `@Singleton` + `@Inject constructor`
- ReaderScreen.kt has CRLF — use `patch` tool, NOT Python
- WARNING: Avoid brace-counting Python on Kotlin source

## Backlog
`D:\programming\docs\Hermes\projects\dual-reader\backlog.md`

## Standing Instructions
- ALWAYS send APK via Telegram after every successful build
- NEVER ask permission to work on backlog items — always execute
- When backlog empty: code review → add findings → backlog → execute
- Cover every new bug with regression tests
- GLM quota interrupted → resume automatically when cleared

## Files excluded from JVM tests (need instrumented tests)
- BillingRepositoryImpl (Google Play Billing)
- TtsServiceImpl (Android TextToSpeech)
- MlKitTranslationServiceImpl (ML Kit APIs)
- Room DAOs (need Android DB runtime)
- Compose screens (need UI test framework)

## Worker
- URL: `https://dual-reader-translate.dualreader.workers.dev/dashboard`
- Provider chain: gemini-2.5-flash (15s) → gemini-2.0-flash (12s) → GLM
- D1 database: `dual-reader-cache` (ID: dcc8dfce-2390-4ed0-b1a0-ba826321927d)
- Hallucination guard: reject if output >3× input words
- Temp ≤0.2, maxBatchPages: 15, maxBatchChars: 30000
