/**
 * Per-Device Daily Quota — tracks translation usage per installation.
 *
 * Each app installation gets a daily free quota (default: 50 pages/day).
 * Quota is tracked via a UUID installation_id generated on first install.
 * The app sends this ID with every translation request.
 *
 * D1 free tier: 5M reads/day, 100K writes/day — more than enough.
 */

const DEFAULT_DAILY_QUOTA = 50;

/**
 * Check if an installation has remaining quota for today.
 * Returns { allowed, pagesUsed, dailyLimit, remaining }.
 *
 * If installation_id is not provided, quota check is skipped (returns allowed=true).
 * This maintains backward compatibility during the rollout period.
 *
 * @param {D1Database} db - D1 binding
 * @param {string|null} installationId - UUID from the app
 * @param {number} pagesRequested - Number of pages being requested (default 1)
 * @param {number} [dailyLimit] - Override daily quota limit
 * @returns {Promise<{allowed: boolean, pagesUsed: number, dailyLimit: number, remaining: number}>}
 */
export async function checkDeviceQuota(db, installationId, pagesRequested = 1, dailyLimit) {
  const limit = dailyLimit || DEFAULT_DAILY_QUOTA;

  // No installation ID = skip quota check (backward compatibility)
  if (!installationId || !db) {
    return { allowed: true, pagesUsed: 0, dailyLimit: limit, remaining: limit };
  }

  const today = getTodayString();

  try {
    const row = await db.prepare(
      'SELECT pages_used FROM device_quota WHERE installation_id = ? AND quota_date = ?'
    ).bind(installationId, today).first();

    const pagesUsed = row?.pages_used || 0;
    const remaining = Math.max(0, limit - pagesUsed);

    return {
      allowed: pagesUsed + pagesRequested <= limit,
      pagesUsed,
      dailyLimit: limit,
      remaining,
    };
  } catch (err) {
    console.error(`[quota] Check error: ${err.message}`);
    // On error, allow the request through (fail open)
    return { allowed: true, pagesUsed: 0, dailyLimit: limit, remaining: limit };
  }
}

/**
 * Increment the page usage count for an installation.
 * Creates a new row if this is the first request today.
 *
 * @param {D1Database} db - D1 binding
 * @param {string|null} installationId - UUID from the app
 * @param {number} pagesUsed - Number of pages to add (default 1)
 * @returns {Promise<void>}
 */
export async function incrementDeviceQuota(db, installationId, pagesUsed = 1) {
  if (!installationId || !db) return;

  const today = getTodayString();

  try {
    // Use INSERT OR REPLACE with a subquery to atomically increment
    await db.prepare(`
      INSERT INTO device_quota (installation_id, quota_date, pages_used, last_updated)
      VALUES (?, ?, ?, datetime('now'))
      ON CONFLICT(installation_id, quota_date) DO UPDATE SET
        pages_used = pages_used + ?,
        last_updated = datetime('now')
    `).bind(installationId, today, pagesUsed, pagesUsed).run();
  } catch (err) {
    console.error(`[quota] Increment error: ${err.message}`);
  }
}

/**
 * Get the current quota status for an installation.
 * Used by the GET /quota endpoint.
 *
 * @param {D1Database} db - D1 binding
 * @param {string} installationId - UUID from the app
 * @param {number} [dailyLimit] - Override daily quota limit
 * @returns {Promise<{pagesUsed: number, dailyLimit: number, remaining: number, resetAt: string}>}
 */
export async function getDeviceQuotaStatus(db, installationId, dailyLimit) {
  const limit = dailyLimit || DEFAULT_DAILY_QUOTA;

  if (!installationId || !db) {
    return { pagesUsed: 0, dailyLimit: limit, remaining: limit, resetAt: getResetTime() };
  }

  const today = getTodayString();

  try {
    const row = await db.prepare(
      'SELECT pages_used FROM device_quota WHERE installation_id = ? AND quota_date = ?'
    ).bind(installationId, today).first();

    const pagesUsed = row?.pages_used || 0;
    const remaining = Math.max(0, limit - pagesUsed);

    return { pagesUsed, dailyLimit: limit, remaining, resetAt: getResetTime() };
  } catch (err) {
    console.error(`[quota] Status error: ${err.message}`);
    return { pagesUsed: 0, dailyLimit: limit, remaining: limit, resetAt: getResetTime() };
  }
}

/**
 * Clean up old quota rows (older than 2 days).
 * Call periodically to prevent table bloat.
 *
 * @param {D1Database} db - D1 binding
 * @returns {Promise<number>} Number of rows deleted
 */
export async function cleanupOldQuotaRows(db) {
  if (!db) return 0;

  try {
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const result = await db.prepare(
      'DELETE FROM device_quota WHERE quota_date < ?'
    ).bind(twoDaysAgo).run();
    return result.meta?.changes || 0;
  } catch (err) {
    console.error(`[quota] Cleanup error: ${err.message}`);
    return 0;
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function getTodayString() {
  return new Date().toISOString().slice(0, 10); // "2026-06-12"
}

function getResetTime() {
  // Reset at midnight UTC
  const tomorrow = new Date();
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  tomorrow.setUTCHours(0, 0, 0, 0);
  return tomorrow.toISOString();
}
