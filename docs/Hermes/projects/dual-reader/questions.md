# Dual Reader — Open Questions

<!-- Add questions here when ambiguity is encountered. User should answer and then items can proceed. -->

## Backlog exhausted — new items needed (2026-06-13)

**Question:** The dual-reader backlog is fully complete (DR-001..DR-010 all done) and the autonomous worker has no "ready" items to process. What should the worker build next?

**Suggested candidates** (need user confirmation before adding as ready backlog items):
1. Cloud reading-progress sync (deferred from DR-005 criterion 4) — requires backend decision
2. In-app dictionary / word lookup for selected text
3. Text-to-speech (TTS) for source and/or translated pages
4. Additional languages / localization beyond en-US + bg
5. Annotation highlighting styles and colors
6. Close out remaining DR-007 manual items (IARC rating, Play Store screenshots, production keystore, privacy policy URL hosting, feature graphic)

**Or:** confirm the project is feature-complete for v1 launch and the worker should go SILENT until further notice.

## DR-008: D1 Database Setup (action needed)

**Action needed:** The D1 translation cache code is complete, but the D1 database needs to be created on Cloudflare before deployment:
1. Run `wrangler d1 create dual-reader-cache` — this outputs a `database_id`
2. Update `database_id` in `D:\programming\Tools\translate-proxy\wrangler.toml` (currently "PLACEHOLDER_RUN_wrangler_d1_create")
3. Apply migration: `wrangler d1 migrations apply dual-reader-cache --local` (local) or `wrangler d1 migrations apply dual-reader-cache --remote` (production)
4. Redeploy worker: `wrangler deploy`

## DR-005: Device sync (criterion 4)

**Decision:** Deferred — local-only for now. Cloud sync is a future feature.

## Push Protection Block

**Issue:** GitHub push protection blocks pushes to `bot-io/critterium` due to a pre-existing Atlassian API token in `Python/confluence_directory_sync/delete_pages.log`. This affects pushing new branches (including `feat/DR-005-reading-progress`).

**Action needed:** Either allowlist the secret at https://github.com/bot-io/critterium/security/secret-scanning/unblock-secret/3EyIhu9HUG2fNrOlRmn0RWKSA5V or clean the history.
