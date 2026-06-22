/**
 * Per-Key Daily Usage Tracking — counts API calls per provider/key per day.
 *
 * Gemini free tier: 250 RPD per key (generateContent).
 * GLM (Z.AI): free tier, RPM-limited but tracked for visibility.
 *
 * Key index convention:
 *   0..N-1  → Gemini keys (from resolveGeminiKeys)
 *   100     → GLM key (single key)
 *
 * D1 table: key_usage (key_index INTEGER, usage_date TEXT, call_count INTEGER, PRIMARY KEY(key_index, usage_date))
 */

const FREE_TIER_RPD = 250; // Gemini free tier: 250 requests per day per key
export const GLM_KEY_INDEX = 100;

/**
 * Increment the usage counter for a specific key index.
 * Call this every time a Gemini API call is made (success or fail).
 *
 * @param {D1Database} db
 * @param {number} keyIndex - 0-based index into the keys array
 * @param {number} count - Number of calls to add (default 1)
 */
export async function incrementKeyUsage(db, keyIndex, count = 1) {
  if (!db) return;
  const today = new Date().toISOString().slice(0, 10);
  try {
    await db.prepare(`
      INSERT INTO key_usage (key_index, usage_date, call_count, last_updated)
      VALUES (?, ?, ?, datetime('now'))
      ON CONFLICT(key_index, usage_date) DO UPDATE SET
        call_count = call_count + ?,
        last_updated = datetime('now')
    `).bind(keyIndex, today, count, count).run();
  } catch (err) {
    console.error(`[key-usage] Increment error: ${err.message}`);
  }
}

/**
 * Get today's usage for all keys.
 *
 * @param {D1Database} db
 * @param {number} keyCount - Total number of keys in the pool
 * @returns {Promise<Array<{keyIndex: number, callCount: number, remaining: number, dailyLimit: number}>>}
 */
export async function getKeyUsageToday(db, keyCount) {
  const today = new Date().toISOString().slice(0, 10);
  const results = [];

  if (!db) {
    for (let i = 0; i < keyCount; i++) {
      results.push({ keyIndex: i, callCount: 0, remaining: FREE_TIER_RPD, dailyLimit: FREE_TIER_RPD });
    }
    return results;
  }

  try {
    for (let i = 0; i < keyCount; i++) {
      const row = await db.prepare(
        'SELECT call_count FROM key_usage WHERE key_index = ? AND usage_date = ?'
      ).bind(i, today).first();
      const callCount = row?.call_count || 0;
      results.push({
        keyIndex: i,
        callCount,
        remaining: Math.max(0, FREE_TIER_RPD - callCount),
        dailyLimit: FREE_TIER_RPD,
      });
    }
  } catch (err) {
    console.error(`[key-usage] Query error: ${err.message}`);
    for (let i = 0; i < keyCount; i++) {
      results.push({ keyIndex: i, callCount: 0, remaining: FREE_TIER_RPD, dailyLimit: FREE_TIER_RPD });
    }
  }

  return results;
}

/**
 * Get today's usage for the GLM key.
 *
 * @param {D1Database} db
 * @returns {Promise<{callCount: number}>}
 */
export async function getGlmUsageToday(db) {
  const today = new Date().toISOString().slice(0, 10);
  if (!db) return { callCount: 0 };
  try {
    const row = await db.prepare(
      'SELECT call_count FROM key_usage WHERE key_index = ? AND usage_date = ?'
    ).bind(GLM_KEY_INDEX, today).first();
    return { callCount: row?.call_count || 0 };
  } catch (err) {
    console.error(`[key-usage] GLM query error: ${err.message}`);
    return { callCount: 0 };
  }
}

/**
 * Clean up old key_usage rows (older than 7 days).
 */
export async function cleanupOldKeyUsage(db) {
  if (!db) return 0;
  try {
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const result = await db.prepare(
      'DELETE FROM key_usage WHERE usage_date < ?'
    ).bind(weekAgo).run();
    return result.meta?.changes || 0;
  } catch (err) {
    console.error(`[key-usage] Cleanup error: ${err.message}`);
    return 0;
  }
}
