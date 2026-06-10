# Critterium — Worklog

### 2026-06-10 — Kickoff
- Created project workspace from spec v2
- Saved spec.md, charter.md, backlog.md (CRT-1..CRT-16), state.md
- Flagged questions in questions.md
- Ran "Vivarium" name availability check — conflicts found on all fronts (App Store, USPTO, domains)
- User chose **Critterium** as replacement name
- Ran "Critterium" name check — clear on Play Store, App Store, USPTO
- Renamed project folder and all references from vivarium → critterium
- Updated backlog IDs: VIV-n → CRT-n
- Resolved all 8 questions, recorded decisions D1–D6
- Updated PRIORITIES.md with Critterium at rank 2

### 2026-06-10 — CRT-1: Scaffold
- Created repo `bot-io/critterium` on GitHub (public)
- Scaffolded monorepo: `packages/core/`, `packages/render/`, `packages/app/`
- npm workspaces, Vite, Vitest, TypeScript strict, Prettier, GitHub Actions CI
- All 3 packages pass: `npm test` (3/3), `npm run build`, `npm run typecheck`
- Branch `crt-1-scaffold` pushed (PR needs manual creation — token scope)
- Marked CRT-1 done
