# Critterium — Questions

## CRT-15: On-device performance verification needed
**Asked:** 2026-06-12
**Item:** CRT-15 criterion 3
**Question:** Please install the debug APK from the CI artifact (or from `critterium-1.0.2.apk` in the repo root) on your Android device and report:
1. Does the app launch and display the particle simulation?
2. What FPS does the HUD show with the default 200 particles?
3. Does the app pause when you switch to another app and resume correctly when you return?
4. Any visual glitches or crashes?

Once you confirm, we can mark CRT-15 as done and move to CRT-16 (iOS + store readiness).

## FYI (no action needed): Vault remote was corrupted — fixed 2026-06-13
**Noted:** 2026-06-13
**What happened:** The `D:\programming` vault repo's `origin` had drifted to `https://github.com/bot-io/critterium.git` (the critterium *code* repo) instead of the correct vault repo `https://github.com/bot-io/programming.git`. This silently blocked the last 3 vault pushes (CRT-17, CRT-18, CRT-19 worker commits were stuck local-only). The push to critterium:master was rejected by repo rules (no `master` branch there; default is `main`).
**What I did:** Corrected `origin` back to `https://github.com/bot-io/programming.git` and pushed all 3 pending worker commits (`17148e1..79e7167 master -> master`). The vault is now in sync.
**Side note:** A misconfigured git credential helper (`credential-netrc` is not installed) causes git network ops to hang/timeout; I worked around it with token-in-URL pushes. You may want to remove the bad `credential-netrc` helper from your git config to speed up future syncs.

## PR Merge Guidance — 5 open PRs need merging (2026-06-13)
**Asked:** 2026-06-13
**Context:** There are 5 stacked PRs open on `bot-io/critterium`. Each builds on the previous:
- PR #1 (crt-23): app package build fixes — CI FAIL (format check, expected — lacks CRT-24 Prettier fix)
- PR #2 (crt-24): ESLint + Prettier CRLF→LF — CI: build PASS, apk was FAIL (now fixed by CRT-27)
- PR #3 (crt-25): README + MIT LICENSE — CI: build PASS, apk was FAIL (now fixed)
- PR #4 (crt-26): eslint.config.mjs rename — CI pending
- PR #5 (crt-27): gradlew executable permission fix — NEW, contains all above + CI fix

**Recommended action:** Merge PR #5 (it contains all changes from #1-#4 plus the gradlew fix) and close PRs #1-#4. Alternatively, merge them in order #1→#2→#3→#4→#5.

**Why this matters:** Every new worker session has to branch from the tip of this stack. Merging will simplify future work and give you a clean `main` with ESLint, README, working CI, and all bug fixes.

