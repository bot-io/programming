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

## DR-007: Play Store Launch — User Actions Needed

The splash screen (criterion 2) and R8 rules (criterion 7) are done. The following still need your input:

1. **App icon review** (criterion 1) — An adaptive icon with an open-book design already exists. Do you want to keep it or commission a custom design?
2. **Privacy policy URL** (criterion 3) — Need a hosted privacy policy page. Options: GitHub Pages, Notion page, or custom domain. What do you prefer?
3. **Content rating** (criterion 4) — Requires Play Console access to complete the IARC questionnaire.
4. **Play Store listing** (criterion 5) — Need: description text, screenshots (phone + tablet), feature graphic (1024×500). Do you have these or need help creating them?
5. **Release keystore** (criterion 6) — Need to generate a release keystore for signing. Want me to script `keytool` commands, or will you handle this manually?

**Branch `feat/dr-007-splash-screen-2`** is pushed and ready for merge review.
