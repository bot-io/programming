/**
 * D1 Translation Cache — Cross-User Translation Sharing
 *
 * Stores translated text in Cloudflare D1 so popular books (same EPUB content)
 * translate once and serve many users. Major cost savings at scale.
 *
 * Cache key: SHA-256 hash of (sourceText + targetLang) → { translatedText, model, cachedAt }
 * Cache TTL: 90 days. Entries cleaned on read if expired.
 *
 * D1 free tier: 5M reads/day, 100K writes/day — more than enough.
 */

const CACHE_TTL_MS = 90 * 24 * 60 * 60 * 1000; // 90 days

/**
 * Look up a cached translation for a single text + target language.
 * Returns { translated_text, model, cached_at } or null if not found or expired.
 * Automatically deletes expired entries on read (lazy cleanup).
 *
 * @param {D1Database} db - D1 binding
 * @param {string} sourceText - Original text
 * @param {string} targetLang - Target language code (e.g., 'bg')
 * @returns {Promise<{translated_text: string, model: string, cached_at: string}|null>}
 */
export async function getCachedTranslation(db, sourceText, targetLang) {
  if (!db) return null;

  const cacheKey = await computeCacheKey(sourceText, targetLang);

  try {
    const row = await db.prepare(
      'SELECT translated_text, model, cached_at FROM translation_cache WHERE cache_key = ?'
    ).bind(cacheKey).first();

    if (!row) return null;

    // Check TTL — delete expired entries on read
    const cachedAt = new Date(row.cached_at).getTime();
    if (Date.now() - cachedAt > CACHE_TTL_MS) {
      await db.prepare('DELETE FROM translation_cache WHERE cache_key = ?')
        .bind(cacheKey).run();
      return null;
    }

    return row;
  } catch (err) {
    console.error(`[cache] Lookup error: ${err.message}`);
    return null;
  }
}

/**
 * Look up cached translations for a batch of pages.
 * Returns a Map<pageIndex, {translated_text, model}> for pages that are cached.
 * Expired entries are cleaned up on read.
 *
 * @param {D1Database} db - D1 binding
 * @param {Array<{index: number, text: string}>} pages - Pages to look up
 * @param {string} targetLang - Target language code
 * @returns {Promise<Map<number, {translated_text: string, model: string}>>}
 */
export async function getCachedTranslations(db, pages, targetLang) {
  const result = new Map();
  if (!db || pages.length === 0) return result;

  try {
    // Build cache keys for all pages
    const keys = await Promise.all(
      pages.map(async (p) => ({
        index: p.index,
        key: await computeCacheKey(p.text, targetLang),
      }))
    );

    // Query all at once with IN clause (D1 supports this)
    const placeholders = keys.map(() => '?').join(',');
    const stmt = db.prepare(
      `SELECT cache_key, translated_text, model, cached_at FROM translation_cache WHERE cache_key IN (${placeholders})`
    ).bind(...keys.map(k => k.key));

    const rows = await stmt.all();

    const keyToIndex = new Map(keys.map(k => [k.key, k.index]));
    const expiredKeys = [];

    for (const row of rows.results) {
      const idx = keyToIndex.get(row.cache_key);
      if (idx === undefined) continue;

      const cachedAt = new Date(row.cached_at).getTime();
      if (Date.now() - cachedAt > CACHE_TTL_MS) {
        expiredKeys.push(row.cache_key);
        continue;
      }

      result.set(idx, {
        translated_text: row.translated_text,
        model: row.model,
      });
    }

    // Clean up expired entries in batch
    if (expiredKeys.length > 0) {
      const delPlaceholders = expiredKeys.map(() => '?').join(',');
      await db.prepare(
        `DELETE FROM translation_cache WHERE cache_key IN (${delPlaceholders})`
      ).bind(...expiredKeys).run();
    }
  } catch (err) {
    console.error(`[cache] Batch lookup error: ${err.message}`);
  }

  return result;
}

/**
 * Store a translation in the cache.
 * Uses INSERT OR REPLACE to handle re-translation of the same text.
 *
 * @param {D1Database} db - D1 binding
 * @param {string} sourceText - Original text
 * @param {string} targetLang - Target language code
 * @param {string} translatedText - Translated text
 * @param {string} model - Model that produced the translation
 * @returns {Promise<void>}
 */
export async function storeCachedTranslation(db, sourceText, targetLang, translatedText, model) {
  if (!db) return;

  const cacheKey = await computeCacheKey(sourceText, targetLang);

  try {
    await db.prepare(
      `INSERT OR REPLACE INTO translation_cache (cache_key, source_hash, target_lang, translated_text, model, cached_at)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).bind(
      cacheKey,
      await computeHash(sourceText),
      targetLang,
      translatedText,
      model,
      new Date().toISOString()
    ).run();
  } catch (err) {
    console.error(`[cache] Store error: ${err.message}`);
  }
}

/**
 * Store multiple translations in the cache (batch).
 *
 * @param {D1Database} db - D1 binding
 * @param {Array<{sourceText: string, targetLang: string, translatedText: string, model: string}>} translations
 * @returns {Promise<void>}
 */
export async function storeCachedTranslations(db, translations) {
  if (!db || translations.length === 0) return;

  try {
    // D1 doesn't support batch INSERT well, so we use individual inserts
    // But we can batch them in a D1 batch
    const stmts = await Promise.all(translations.map(async (t) => {
      const cacheKey = await computeCacheKey(t.sourceText, t.targetLang);
      return db.prepare(
        `INSERT OR REPLACE INTO translation_cache (cache_key, source_hash, target_lang, translated_text, model, cached_at)
         VALUES (?, ?, ?, ?, ?, ?)`
      ).bind(
        cacheKey,
        await computeHash(t.sourceText),
        t.targetLang,
        t.translatedText,
        t.model,
        new Date().toISOString()
      );
    }));

    await db.batch(stmts);
  } catch (err) {
    console.error(`[cache] Batch store error: ${err.message}`);
  }
}

/**
 * Get cache statistics for the /status endpoint.
 *
 * @param {D1Database} db - D1 binding
 * @returns {Promise<{total_entries: number, expired_entries: number, languages: string[]}|null>}
 */
export async function getCacheStats(db) {
  if (!db) return null;

  try {
    const [totalResult, expiredResult, langResult] = await db.batch([
      db.prepare('SELECT COUNT(*) as count FROM translation_cache'),
      db.prepare('SELECT COUNT(*) as count FROM translation_cache WHERE cached_at < ?')
        .bind(new Date(Date.now() - CACHE_TTL_MS).toISOString()),
      db.prepare('SELECT DISTINCT target_lang FROM translation_cache'),
    ]);

    return {
      total_entries: totalResult.results[0]?.count ?? 0,
      expired_entries: expiredResult.results[0]?.count ?? 0,
      languages: langResult.results.map(r => r.target_lang),
    };
  } catch (err) {
    console.error(`[cache] Stats error: ${err.message}`);
    return null;
  }
}

/**
 * Compute a deterministic cache key from source text + target language.
 * Uses Web Crypto API (available in CF Workers).
 */
async function computeCacheKey(sourceText, targetLang) {
  const combined = `${targetLang}:${sourceText}`;
  return computeHash(combined);
}

/**
 * SHA-256 hash using Web Crypto API.
 */
async function computeHash(text) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
