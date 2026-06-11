# Dual Reader — Open Questions

<!-- Add questions here when ambiguity is encountered. User should answer and then items can proceed. -->

## DR-008: D1 Database Setup (action needed)

**Action needed:** The D1 translation cache code is complete, but the D1 database needs to be created on Cloudflare before deployment:
1. Run `wrangler d1 create dual-reader-cache` — this outputs a `database_id`
2. Update `database_id` in `D:\programming\Tools\translate-proxy\wrangler.toml` (currently "PLACEHOLDER_RUN_wrangler_d1_create")
3. Apply migration: `wrangler d1 migrations apply dual-reader-cache --local` (local) or `wrangler d1 migrations apply dual-reader-cache --remote` (production)
4. Redeploy worker: `wrangler deploy`

## DR-005: Device sync (criterion 4)

**Question:** Should reading progress sync across devices (e.g. via cloud)? Currently progress is local-only (Room DB). This was deferred — need decision before any cloud sync implementation.

## Push Protection Block

**Issue:** GitHub push protection blocks pushes to `bot-io/critterium` due to a pre-existing Atlassian API token in `Python/confluence_directory_sync/delete_pages.log`. This affects pushing new branches (including `feat/DR-005-reading-progress`).

**Action needed:** Either allowlist the secret at https://github.com/bot-io/critterium/security/secret-scanning/unblock-secret/3EyIhu9HUG2fNrOlRmn0RWKSA5V or clean the history.
