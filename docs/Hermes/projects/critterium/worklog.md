# Critterium — Worklog

## 2026-06-12 CRT-15: Capacitor Android build + background-pause
- **Branch:** `feat/crt-15-capacitor-android-ci`
- **Commit:** 27dcb21
- **What was done:**
  1. Added `android-debug-apk` CI job to `.github/workflows/ci.yml` — uses Node 22, Java 17, Gradle, Capacitor sync, builds debug APK, uploads as artifact (14-day retention)
  2. Verified background-pause already implemented in `main.ts` (Capacitor pause/resume events, visibilitychange, beforeunload)
  3. Added 12 background-pause lifecycle tests in `packages/app/src/background-pause.test.ts`
  4. Fixed pre-existing TS build errors: FalloffType cast in matrix rebuild, unused canvas variable in PopulationGraph
  5. Fixed infection feature removal inconsistencies (test files still referencing removed infection features)
- **Tests:** 397 total (266 core + 16 render + 115 app unit) — all pass
- **Status:** Blocked on criterion 3 (on-device perf check needs Svetlin)
- **Blocker:** Need Svetlin to install debug APK and report FPS/performance on physical device
