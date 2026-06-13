# Critterium — State

**Status:** M4/M6 — Capacitor upgraded to v8.4.0 (CRT-31 done). tar vulnerability resolved natively, dual @capacitor/core version conflict eliminated. npm audit 0 vulnerabilities. Android toolchain fully updated (AGP 8.13.0, Gradle 8.14.3, Java 21). 536 tests pass.
**Last Updated:** 2026-06-13
**Version:** v1.4.1
**Active Items:** CRT-15 (blocked — needs Svetlin for on-device perf check), CRT-16 (blocked — after M4)
**Completed:** CRT-1 ✅ CRT-2 ✅ CRT-3 ✅ CRT-4 ✅ CRT-5 ✅ CRT-6 ✅ CRT-7 ✅ CRT-8 ✅ CRT-9 ✅ CRT-10 ✅ CRT-11 ✅ CRT-12 ✅ CRT-13 ✅ CRT-14 ✅ CRT-17 ✅ CRT-18 ✅ CRT-19 ✅ CRT-20 ✅ CRT-21 ✅ CRT-22 ✅ CRT-23 ✅ CRT-24 ✅ CRT-25 ✅ CRT-26 ✅ CRT-27 ✅ CRT-28 ✅ CRT-29 ✅ CRT-30 ✅ CRT-31 ✅
**Ecosystem (retrospective):** CRT-E1 ✅ CRT-E2 ✅ CRT-E3 ✅ CRT-E4 ✅ CRT-E5 ✅ CRT-E6 ✅
**Tests:** 536 unit tests, all pass (303 core + 16 render + 217 app)
**Build:** `npm run build` passes for all 3 packages
**Lint:** ESLint v10 configured, `npm run lint` clean — zero warnings
**Format:** Prettier `endOfLine: lf` + `.gitattributes`, `npm run format:check` clean
**Security:** npm audit 0 vulnerabilities (Capacitor v8 resolves tar natively; esbuild override retained)
**Capacitor:** v8.4.0 (upgraded from v6.2.1). AGP 8.13.0, Gradle 8.14.3, Java 21, minSdk 24, compileSdk 36
**Built-in presets:** Classic, Plankton Bloom, Swarm Intelligence, Predator Arena, Tiny Pond, Zen Garden, Rock Paper Scissors, Grasslands, Birds, Fishes
**Working tree:** Clean
**Open PRs:** PR #1-#5 (stacked), PR #6, PR #7, PR #8 (CRT-31 Capacitor v8 upgrade)
**Documentation:** Comprehensive README with features, presets table, architecture, dev commands. MIT LICENSE file added.
**Open Questions:** CRT-15 criterion 3 needs Svetlin to install debug APK and verify 60fps on device. PR merge guidance below.
**PR Merge Path:** Merge PR #5 (contains #1-#4 + gradlew fix) → merge #6 → merge #7 → merge #8. Or merge #8 which contains everything.
**Repo:** https://github.com/bot-io/critterium
**D9 Preset Wishlist:** Simple Particles✅ Predator/Prey✅ Predator/Prey/Vegetation✅ Rock/Paper/Scissors✅ Birds✅ Fishes✅ — ALL COMPLETE. "Predator/Prey/Sickness Center" blocked (infection feature removed).
**Backlog Status:** No ready items remaining. CRT-15 and CRT-16 blocked on user action (device verification + iOS/store readiness).
