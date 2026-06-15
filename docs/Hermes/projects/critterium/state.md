# Critterium — State

**Status:** M6 — CRT-55 done (predator satiation + stress test fix triaged and committed). CRT-54 orphaned work finally committed (was marked done but never committed). Integration branch now at 95371f7 with 1145+ tests. PR #12 awaiting Svetlin's merge decision.
**Last Updated:** 2026-06-15 (run #73)
**Version:** v1.4.19
**Active Items:** All backlog items complete. CRT-15 (blocked — needs Svetlin for on-device perf check), CRT-16 (blocked — after M4). Backlog exhausted — ready items remaining: 0.
**Completed:** CRT-1 ✅ CRT-2 ✅ CRT-3 ✅ CRT-4 ✅ CRT-5 ✅ CRT-6 ✅ CRT-7 ✅ CRT-8 ✅ CRT-9 ✅ CRT-10 ✅ CRT-11 ✅ CRT-12 ✅ CRT-13 ✅ CRT-14 ✅ CRT-17 ✅ CRT-18 ✅ CRT-19 ✅ CRT-20 ✅ CRT-21 ✅ CRT-22 ✅ CRT-23 ✅ CRT-24 ✅ CRT-25 ✅ CRT-26 ✅ CRT-27 ✅ CRT-28 ✅ CRT-29 ✅ CRT-30 ✅ CRT-31 ✅ CRT-32 ✅ CRT-33 ✅ CRT-34 ✅ CRT-35 ✅ CRT-36 ✅ CRT-37 ✅ CRT-38 ✅ CRT-39 ✅ CRT-40 ✅ CRT-41 ✅ CRT-42 ✅ CRT-43 ✅ CRT-44 ✅ CRT-45 ✅ CRT-46 ✅ CRT-47 ✅ CRT-48 ✅ CRT-49 ✅ CRT-50 ✅ CRT-52 ✅ CRT-53 ✅ CRT-54 ✅ CRT-55 ✅ (CRT-51 review-ready, awaiting merge decision)
**Ecosystem (retrospective):** CRT-E1 ✅ CRT-E2 ✅ CRT-E3 ✅ CRT-E4 ✅ CRT-E5 ✅ CRT-E6 ✅
**Tests:** 1145+ unit tests on integration/crt-35-50 branch (554 core + 591 app). 3 e2e test files fail locally (expected — need dev server). Build/lint/format/typecheck all clean.
**Build:** `npm run build` passes for all 3 packages
**Lint:** ESLint v10 configured, `npm run lint` clean — zero warnings
**Format:** Prettier `endOfLine: lf` + `.gitattributes`, `npm run format:check` clean
**Security:** npm audit 0 vulnerabilities (Capacitor v8 resolves tar natively; esbuild override retained)
**Capacitor:** v8.4.0 (upgraded from v6.2.1). AGP 8.13.0, Gradle 8.14.3, Java 21, minSdk 24, compileSdk 36
**E2E CI:** Playwright e2e job in CI — runs on every PR/push, installs Chromium, uploads report on failure
**Built-in presets:** Classic, Plankton Bloom, Swarm Intelligence, Predator Arena, Tiny Pond, Zen Garden, Rock Paper Scissors, Grasslands, Birds, Fishes, Coral Reef, Tornado Alley, Deep Sea Vent, Symbiosis
**Built-in force types (9):** drag, wander, gravity, flow-field, vortex, pointer, alignment, boids, attractor
**Open PRs:** PR #9 (CRT-32), PR #10 (CRT-33), PR #11 (CRT-34) pending review (superseded by PR #12). PR #12 (integration CRT-32→55) is CI-green and ready to merge. PRs #1-#8 all merged.
**Documentation:** Comprehensive README with features, presets table, architecture, dev commands. MIT LICENSE file added.
**Open Questions:** CRT-15 criterion 3 needs Svetlin to install debug APK and verify 60fps on device. CRT-51 merge-strategy decision needed (Option 2 = merge PR #12 is the fastest path).
**Repo:** https://github.com/bot-io/critterium
**Ready Items Remaining:** 0 — backlog exhausted.
**Backlog Status:** Complete. Only CRT-15 and CRT-16 remain blocked on user action (device verification + iOS/store readiness).
**Merge Backlog (2026-06-15, run #73):** `main` is stuck at CRT-31. 24 items of completed work (CRT-32→55) sit on the unmerged integration branch. PR #12 is feature-complete AND fully CI-green. Run #73 discovered CRT-54 was marked "done" but never committed — committed all orphaned work (sim-logger, per-species cap, endangered boost, predator satiation, preset-stability tests). Three new behavioral changes added to PR #12: (1) per-species fair cap, (2) endangered species reproduction boost, (3) predator satiation. All improve ecosystem stability but change preset balance — Svetlin should review when merging. Merge-strategy decision still needed from Svetlin (Option 2 = merge PR #12 is the clear fastest path).
