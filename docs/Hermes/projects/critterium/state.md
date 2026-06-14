# Critterium — State

**Status:** M6 — CRT-50 done (AttractorForce — point-based attraction/repulsion). 658 unit tests pass (30 new). Branch pushed.
**Last Updated:** 2026-06-14 (run #51)
**Version:** v1.4.18
**Active Items:** All backlog items complete. CRT-15 (blocked — needs Svetlin for on-device perf check), CRT-16 (blocked — after M4). Backlog exhausted — ready items remaining: 0.
**Completed:** CRT-1 ✅ CRT-2 ✅ CRT-3 ✅ CRT-4 ✅ CRT-5 ✅ CRT-6 ✅ CRT-7 ✅ CRT-8 ✅ CRT-9 ✅ CRT-10 ✅ CRT-11 ✅ CRT-12 ✅ CRT-13 ✅ CRT-14 ✅ CRT-17 ✅ CRT-18 ✅ CRT-19 ✅ CRT-20 ✅ CRT-21 ✅ CRT-22 ✅ CRT-23 ✅ CRT-24 ✅ CRT-25 ✅ CRT-26 ✅ CRT-27 ✅ CRT-28 ✅ CRT-29 ✅ CRT-30 ✅ CRT-31 ✅ CRT-32 ✅ CRT-33 ✅ CRT-34 ✅ CRT-35 ✅ CRT-36 ✅ CRT-37 ✅ CRT-38 ✅ CRT-39 ✅ CRT-40 ✅ CRT-41 ✅ CRT-42 ✅ CRT-43 ✅ CRT-44 ✅ CRT-45 ✅ CRT-46 ✅ CRT-47 ✅ CRT-48 ✅ CRT-49 ✅ CRT-50 ✅
**Ecosystem (retrospective):** CRT-E1 ✅ CRT-E2 ✅ CRT-E3 ✅ CRT-E4 ✅ CRT-E5 ✅ CRT-E6 ✅
**Tests:** 658 unit tests on feat/crt-50-attractor-force branch (392 core + 16 render + 250 app; includes 30 new attractor-force + registry tests). 3 e2e test files fail (pre-existing, no Playwright browser in env). Build/lint/format/typecheck all clean.
**Build:** `npm run build` passes for all 3 packages
**Lint:** ESLint v10 configured, `npm run lint` clean — zero warnings
**Format:** Prettier `endOfLine: lf` + `.gitattributes`, `npm run format:check` clean (pre-existing config-schema.ts format warnings from CRT-36 branch chain)
**Security:** npm audit 0 vulnerabilities (Capacitor v8 resolves tar natively; esbuild override retained)
**Capacitor:** v8.4.0 (upgraded from v6.2.1). AGP 8.13.0, Gradle 8.14.3, Java 21, minSdk 24, compileSdk 36
**E2E CI:** Playwright e2e job in CI — runs on every PR/push, installs Chromium, uploads report on failure
**Built-in presets:** Classic, Plankton Bloom, Swarm Intelligence, Predator Arena, Tiny Pond, Zen Garden, Rock Paper Scissors, Grasslands, Birds, Fishes, Coral Reef, Tornado Alley, Deep Sea Vent, Symbiosis
**Built-in force types (9):** drag, wander, gravity, flow-field, vortex, pointer, alignment, boids, attractor
**Open PRs:** PR #9 (CRT-32), PR #10 (CRT-33), PR #11 (CRT-34) pending review. Branches feat/crt-35→feat/crt-50 pushed (PRs need manual creation — token scope). PRs #1-#8 all merged.
**Documentation:** Comprehensive README with features, presets table, architecture, dev commands. MIT LICENSE file added.
**Open Questions:** CRT-15 criterion 3 needs Svetlin to install debug APK and verify 60fps on device.
**Repo:** https://github.com/bot-io/critterium
**Ready Items Remaining:** 0 — backlog exhausted. All 50 tracked items (CRT-1 through CRT-50) plus 6 retrospective ecosystem items are complete.
**Backlog Status:** Complete. Only CRT-15 and CRT-16 remain blocked on user action (device verification + iOS/store readiness).
**Merge Backlog (2026-06-14, run #51):** `main` is stuck at CRT-31. 19 items of completed work (CRT-32→50, 1120 tests green) sit on unmerged branches. PR #12 (integration CRT-35→50) `build-and-test` CI now PASSES (fixed Prettier format failure on run #51). Open PRs #9/#10/#11 (crt-32/33/34) still pending. Integration branch includes CRT-32 work but NOT CRT-33/34. Merge-strategy decision still needed from Svetlin (see questions.md).
