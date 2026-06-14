# Critterium — State

**Status:** M6 — CRT-45 done (Stress Test Suite). 777 unit tests pass. Branch pushed.
**Last Updated:** 2026-06-14
**Version:** v1.4.13
**Active Items:** CRT-46 → CRT-50 (5 ready items, P2-P3). CRT-15 (blocked — needs Svetlin for on-device perf check), CRT-16 (blocked — after M4). Next up: CRT-46 (P2, Edge Case Test Suite).
**Completed:** CRT-1 ✅ CRT-2 ✅ CRT-3 ✅ CRT-4 ✅ CRT-5 ✅ CRT-6 ✅ CRT-7 ✅ CRT-8 ✅ CRT-9 ✅ CRT-10 ✅ CRT-11 ✅ CRT-12 ✅ CRT-13 ✅ CRT-14 ✅ CRT-17 ✅ CRT-18 ✅ CRT-19 ✅ CRT-20 ✅ CRT-21 ✅ CRT-22 ✅ CRT-23 ✅ CRT-24 ✅ CRT-25 ✅ CRT-26 ✅ CRT-27 ✅ CRT-28 ✅ CRT-29 ✅ CRT-30 ✅ CRT-31 ✅ CRT-32 ✅ CRT-33 ✅ CRT-34 ✅ CRT-35 ✅ CRT-36 ✅ CRT-37 ✅ CRT-38 ✅ CRT-39 ✅ CRT-40 ✅ CRT-41 ✅ CRT-42 ✅ CRT-43 ✅ CRT-44 ✅ CRT-45 ✅
**Ecosystem (retrospective):** CRT-E1 ✅ CRT-E2 ✅ CRT-E3 ✅ CRT-E4 ✅ CRT-E5 ✅ CRT-E6 ✅
**Tests:** 777 unit tests (384 core + 16 render + 377 app) + 12 e2e tests (7 smoke + 4 export-import + 1 settings-stress), all pass
**Build:** `npm run build` passes for all 3 packages
**Lint:** ESLint v10 configured, `npm run lint` clean — zero warnings
**Format:** Prettier `endOfLine: lf` + `.gitattributes`, `npm run format:check` clean
**Security:** npm audit 0 vulnerabilities (Capacitor v8 resolves tar natively; esbuild override retained)
**Capacitor:** v8.4.0 (upgraded from v6.2.1). AGP 8.13.0, Gradle 8.14.3, Java 21, minSdk 24, compileSdk 36
**E2E CI:** Playwright e2e job in CI — runs on every PR/push, installs Chromium, uploads report on failure
**Built-in presets:** Classic, Plankton Bloom, Swarm Intelligence, Predator Arena, Tiny Pond, Zen Garden, Rock Paper Scissors, Grasslands, Birds, Fishes, Coral Reef, Tornado Alley, Deep Sea Vent, Symbiosis
**Working tree:** Clean (orphaned persistence.ts + capacitor.build.gradle changes stashed for triage)
**Open PRs:** PR #9 (CRT-32 loadAutosave hardening — pending review), PR #10 (CRT-33 e2e fixes + CI — pending review), PR #11 (CRT-34 dead sickness code removal — pending review). Branches `feat/crt-36-dynamic-force-serialization`, `feat/crt-37-force-pipeline`, `feat/crt-38-force-add-remove-ui`, `feat/crt-41-coral-reef-preset`, `feat/crt-42-tornado-alley`, `feat/crt-43-deep-sea-vent`, `feat/crt-44-symbiosis` pushed (PRs need manual creation — token scope). PRs #1-#8 all merged.
**Documentation:** Comprehensive README with features, presets table, architecture, dev commands. MIT LICENSE file added.
**Open Questions:** CRT-15 criterion 3 needs Svetlin to install debug APK and verify 60fps on device.
**Repo:** https://github.com/bot-io/critterium
**D9 Preset Wishlist:** Simple Particles✅ Predator/Prey✅ Predator/Prey/Vegetation✅ Rock/Paper/Scissors✅ Birds✅ Fishes✅ — ALL COMPLETE. "Predator/Prey/Sickness Center" blocked (infection feature removed).
**Ready Items Remaining:** 5 (CRT-46 → CRT-50)
**Backlog Status:** 5 ready items queued (CRT-46 → CRT-50) — edge-case test suite (CRT-46, P2), config/force hardening tests (CRT-47-48, P3), and 2 new force types (CRT-49-50, P3). P1 chain (CRT-35→38) fully done. Next up: CRT-46 (P2, Edge Case Test Suite). CRT-15 and CRT-16 remain blocked on user action (device verification + iOS/store readiness).
