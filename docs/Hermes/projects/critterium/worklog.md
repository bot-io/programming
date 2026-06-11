# Critterium — Worklog

## 2026-06-11 CRT-7: Alignment (flocking) force ✅
- **Branch:** `feat/crt-7-alignment`
- **Commit:** 99b3018
- **Status:** Done, pushed
- **Changes:**
  - Added `AlignmentForce` class to `packages/core/src/index.ts`
    - Steers particles toward average heading of same-type neighbors
    - `crossType` parameter for cross-type alignment
    - Uses spatial hash grid for O(n) neighbor queries
    - Pre-allocated temp arrays (sumVx, sumVy, neighborCounts) — zero hot-loop allocations
    - Implements `Force` interface (id='alignment', serializable params)
  - Added 10 unit tests to `packages/core/src/index.test.ts`:
    1. Default params
    2. Isolated particle (no neighbors) — no effect
    3. Steering toward average heading (analytic test)
    4. Heading convergence over 2s simulation
    5. Same-type isolation (crossType=false)
    6. Cross-type alignment (crossType=true)
    7. Radius limit — particles outside radius unaffected
    8. ForcePipeline integration (300 steps, stable)
    9. Array reuse (no reallocation after first apply)
    10. Already-aligned particles — zero force
- **Test Results:** 146 total (144 core + 1 app + 1 render) — all pass
- **PR:** Needs manual creation (token scope issue)
