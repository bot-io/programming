# Critterium — Worklog

## 2026-06-11 CRT-8: Benchmark harness + CI perf gate

**Worker:** autonomous
**Branch:** `feat/crt-8-benchmark-harness`
**Status:** Done
**Tests:** 11 new (248 total including existing 237)

### What was done
- Created `packages/core/src/benchmark.ts` — Core benchmark harness with:
  - `runSingleBenchmark(count, steps, thresholds)` — measures steps/sec for a given particle count
  - `runBenchmarks(thresholds, steps)` — runs all tiers and produces a report
  - `formatReportMarkdown(report)` — formats as markdown
  - Allocation check via heap growth measurement (with --expose-gc)
  - Full simulation pipeline: pairwise + wander + drag + vortex + boundary forces
- Created `packages/core/src/benchmark.test.ts` — 11 vitest tests:
  - 6 harness unit tests (validity, scaling, report format)
  - 5 CI performance gate tests (threshold enforcement at each tier)
  - Generous CI thresholds (100/20/10/2 steps/sec for 100/500/1k/5k particles)
- Updated `.github/workflows/ci.yml` with benchmark CI step
- Added `npm run test:bench` script to root package.json
- Committed benchmark report at `docs/BENCHMARK.md`
- Excluded `benchmark.ts` from build output (not a library export)

### Performance results (this machine)
- 100 particles: ~8,000+ steps/sec
- 500 particles: ~465 steps/sec
- 1000 particles: ~170 steps/sec
- 5000 particles: ~7 steps/sec

### Pre-existing issues
- Build fails due to unused variables in ecosystem files (ecosystem.ts, lifecycle.ts, ecosystem-world.ts)
- These were broken before CRT-8 changes
