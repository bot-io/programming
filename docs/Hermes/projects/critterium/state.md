# Critterium — State

**Status:** M6 — CRT-47 done (Config Validation Hardening). 63 config-schema tests pass. Branch pushed.
**Last Updated:** 2026-06-14
**Version:** v1.4.15
**Active Items:** CRT-48 → CRT-50 (3 ready items, P3). CRT-15 (blocked — needs Svetlin for on-device perf check), CRT-16 (blocked — after M4). Next up: CRT-48 (P3, Force Isolation Tests).
**Completed:** CRT-1 ✅ CRT-2 ✅ CRT-3 ✅ CRT-4 ✅ CRT-5 ✅ CRT-6 ✅ CRT-7 ✅ CRT-8 ✅ CRT-9 ✅ CRT-10 ✅ CRT-11 ✅ CRT-12 ✅ CRT-13 ✅ CRT-14 ✅ CRT-17 ✅ CRT-18 ✅ CRT-19 ✅ CRT-20 ✅ CRT-21 ✅ CRT-22 ✅ CRT-23 ✅ CRT-24 ✅ CRT-25 ✅ CRT-26 ✅ CRT-27 ✅ CRT-28 ✅ CRT-29 ✅ CRT-30 ✅ CRT-31 ✅ CRT-32 ✅ CRT-33 ✅ CRT-34 ✅ CRT-35 ✅ CRT-36 ✅ CRT-37 ✅ CRT-38 ✅ CRT-39 ✅ CRT-40 ✅ CRT-41 ✅ CRT-42 ✅ CRT-43 ✅ CRT-44 ✅ CRT-45 ✅ CRT-46 ✅ CRT-47 ✅
**Ecosystem (retrospective):** CRT-E1 ✅ CRT-E2 ✅ CRT-E3 ✅ CRT-E4 ✅ CRT-E5 ✅ CRT-E6 ✅
**Tests:** 341 core tests on feat/crt-47 branch (303 original + 38 CRT-47 adversarial). Build/lint/format/typecheck all clean.
**Build:** `npm run build` passes for all 3 packages
**Lint:** ESLint v10 configured, `npm run lint` clean — zero warnings
**Format:** Prettier `endOfLine: lf` + `.gitattributes`, `npm run format:check` clean
**Security:** npm audit 0 vulnerabilities (Capacitor v8 resolves tar natively; esbuild override retained)
**Capacitor:** v8.4.0 (upgraded from v6.2.1). AGP 8.13.0, Gradle 8.14.3, Java 21, minSdk 24, compileSdk 36
**E2E CI:** Playwright e2e job in CI — runs on every PR/push, installs Chromium, uploads report on failure
**Built-in presets:** Classic, Plankton Bloom, Swarm Intelligence, Predator Arena, Tiny Pond, Zen Garden, Rock Paper Scissors, Grasslands, Birds, Fishes, Coral Reef, Tornado Alley, Deep Sea Vent, Symbiosis
**Working tree:** Clean
**Open PRs:** PR #9 (CRT-32), PR #10 (CRT-33), PR #11 (CRT-34) pending review. Branches feat/crt-35→feat/crt-46, feat/crt-47 pushed (PRs need manual creation — token scope). PRs #1-#8 all merged.
**Documentation:** Comprehensive README with features, presets table, architecture, dev commands. MIT LICENSE file added.
**Open Questions:** CRT-15 criterion 3 needs Svetlin to install debug APK and verify 60fps on device.
**Repo:** https://github.com/bot-io/critterium
**Ready Items Remaining:** 3 (CRT-48 → CRT-50)
**Backlog Status:** 3 ready items queued (CRT-48 → CRT-50) — force isolation tests (CRT-48, P3), and 2 new force types (CRT-49-50, P3). P1/P2 chains fully done. CRT-15 and CRT-16 remain blocked on user action (device verification + iOS/store readiness).
