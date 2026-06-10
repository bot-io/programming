# Vivarium — Questions

_Questions flagged during kickoff review. Blocking implementation until acknowledged._

## Q1: PRIORITIES.md — user-owned file

Per vault protocol, agents must not edit `PRIORITIES.md`. The spec says "Add vivarium to PRIORITIES.md at rank 2, active." **Svetlin needs to add this manually**, or explicitly authorize the edit.

## Q2: GitHub repo — under which account?

The charter assumes a `vivarium` repo. Should it be under **bot-io** (like the existing programming repo) or a personal account? If bot-io, I'll use the existing credentials. If elsewhere, I'll need the org/account name.

## Q3: "Vivarium" name availability — VIV-1 scope

VIV-1 says to check Play Store, App Store, domain, trademark. Should I run this check now (web search) as part of kickoff, or defer to when VIV-1 is picked up for implementation? The spec says "report findings as a question if conflicts found" — so this is a prerequisite for scaffold.

## Q4: Monorepo package structure — shared config?

The spec says monorepo with `core/`, `render/`, `app/`. Questions:
- Is this a single npm workspace (`"workspaces"` in root `package.json`) or separate packages linked via path?
- Should there be a `shared/` or `types/` package for interfaces (e.g. `Force`, `WorldState`) that both core and render depend on?
- Or does core export its types and render/app import from core?

## Q5: Interaction matrix — size limits / dynamic resize?

When the user adds/removes a type live via UI (VIV-12), the N×N matrix must resize. Is there a max number of types? The spec says "add/remove types" but doesn't cap it. Suggest a reasonable limit (e.g. 10–16 types) to keep the matrix editor usable and memory bounded.

## Q6: Wander noise — implementation detail

"Wander: per-particle smooth noise" — this implies per-particle noise state (phase offset into a smooth function). With typed arrays and no per-particle objects, where does this state live? Options:
- Additional `Float32Array` for wander phase per particle
- Wander force owns its own state array (allocated once)
- Derived from particle index + simTime (stateless but less organic)

The spec says "no hot-loop allocations" — so it needs to be pre-allocated. Is the force allowed to own its own typed arrays?

## Q7: Snapshot size for 5k particles

A snapshot stores positions + velocities for all particles. At 5k particles × 4 floats × 4 bytes = 80KB per snapshot, plus the JSON envelope. This seems fine, but confirming: is there a max snapshot size or particle count we should enforce? The spec says "headroom for ~5k."

## Q8: CI — GitHub Actions?

Is GitHub Actions the CI platform, or should we use something else? Assumed yes since the repo is on GitHub.

## Q9: Matrix editor UI — what interaction model?

VIV-12 mentions a "matrix editor" but doesn't specify the interaction. Options:
- N×N grid of sliders
- N×N grid of number inputs
- Color-coded heatmap (strength → color) with click-to-edit
- The asymmetry (A→B ≠ B→A) means each cell is independent — not just upper triangle

This is a UX decision. I'll implement a reasonable default (slider grid) unless you have a preference.
