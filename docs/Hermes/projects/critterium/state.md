# Critterium — State

**Status:** M6 ecosystem mode active — all backlog items done or blocked. CRT-24 added ESLint + fixed Prettier line-endings (213 files CRLF→LF). CRT-15 blocked on device verification, CRT-16 blocked pending M4.
**Last Updated:** 2026-06-13
**Version:** v1.4.0
**Active Items:** CRT-15 (blocked — needs Svetlin for on-device perf check), CRT-16 (blocked — after M4)
**Completed:** CRT-1 ✅ CRT-2 ✅ CRT-3 ✅ CRT-4 ✅ CRT-5 ✅ CRT-6 ✅ CRT-7 ✅ CRT-8 ✅ CRT-9 ✅ CRT-10 ✅ CRT-11 ✅ CRT-12 ✅ CRT-13 ✅ CRT-14 ✅ CRT-17 ✅ CRT-18 ✅ CRT-19 ✅ CRT-20 ✅ CRT-21 ✅ CRT-22 ✅ CRT-23 ✅ CRT-24 ✅
**Ecosystem (retrospective):** CRT-E1 ✅ CRT-E2 ✅ CRT-E3 ✅ CRT-E4 ✅ CRT-E5 ✅ CRT-E6 ✅
**Tests:** 502 unit tests, all pass (303 core + 16 render + 183 app)
**Build:** `npm run build` passes for all 3 packages
**Lint:** ESLint v10 configured, `npm run lint` clean (was completely absent)
**Format:** Prettier `endOfLine: lf` + `.gitattributes`, `npm run format:check` clean (was 213 files with CRLF issues)
**Built-in presets:** Classic, Plankton Bloom, Swarm Intelligence, Predator Arena, Tiny Pond, Zen Garden, Rock Paper Scissors, Grasslands, Birds, Fishes
**Working tree:** Clean
**Open Questions:** CRT-15 criterion 3 needs Svetlin to install debug APK and verify 60fps on device
**Repo:** https://github.com/bot-io/critterium
**D9 Preset Wishlist:** Simple Particles✅ Predator/Prey✅ Predator/Prey/Vegetation✅ Rock/Paper/Scissors✅ Birds✅ Fishes✅ — ALL COMPLETE. "Predator/Prey/Sickness Center" blocked (infection feature removed).
