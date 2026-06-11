-- Translation cache for cross-user sharing.
-- Cache key: SHA-256(sourceText + targetLang) → translated text + model
-- D1 free tier: 5M reads/day, 100K writes/day

CREATE TABLE IF NOT EXISTS translation_cache (
  cache_key TEXT PRIMARY KEY,
  source_hash TEXT NOT NULL,
  target_lang TEXT NOT NULL,
  translated_text TEXT NOT NULL,
  model TEXT NOT NULL,
  cached_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Index for batch lookups (IN queries on cache_key use PK index automatically)
-- Index for cleanup/expiry queries
CREATE INDEX IF NOT EXISTS idx_cache_cached_at ON translation_cache(cached_at);
-- Index for stats by language
CREATE INDEX IF NOT EXISTS idx_cache_target_lang ON translation_cache(target_lang);
