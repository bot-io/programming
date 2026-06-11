import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

// We need to test the cache module functions.
// Since the module uses Web Crypto API (crypto.subtle) which is available in Node 19+,
// we can import it directly. For D1, we'll create a mock.

// Import the functions via dynamic import since the module uses Web Crypto
const cacheModule = await import('../src/translation-cache.js');

// ─── Mock D1 Database ─────────────────────────────────────────────────────────

function createMockDb(data = new Map()) {
  return {
    _data: data,
    prepare(sql) {
      const self = this;
      const stmt = {
        sql,
        _bindings: [],
        bind(...args) {
          stmt._bindings = args;
          return stmt;
        },
        async first() {
          // SELECT ... WHERE cache_key = ?
          if (sql.includes('SELECT') && sql.includes('WHERE cache_key = ?')) {
            const key = stmt._bindings[0];
            const row = self._data.get(key);
            return row || null;
          }
          return null;
        },
        async run() {
          // DELETE or INSERT
          if (sql.includes('DELETE')) {
            const key = stmt._bindings[0];
            self._data.delete(key);
            return { success: true };
          }
          if (sql.includes('INSERT OR REPLACE')) {
            const [cacheKey, sourceHash, targetLang, translatedText, model, cachedAt] = stmt._bindings;
            self._data.set(cacheKey, {
              cache_key: cacheKey,
              source_hash: sourceHash,
              target_lang: targetLang,
              translated_text: translatedText,
              model,
              cached_at: cachedAt,
            });
            return { success: true };
          }
          return { success: true };
        },
        async all() {
          // SELECT ... WHERE cache_key IN (?,?,?)
          if (sql.includes('IN (')) {
            const keys = stmt._bindings;
            const results = [];
            for (const key of keys) {
              if (self._data.has(key)) {
                results.push(self._data.get(key));
              }
            }
            return { results };
          }
          return { results: [] };
        },
      };
      return stmt;
    },
    async batch(stmts) {
      const results = [];
      for (const stmt of stmts) {
        results.push(await stmt.run());
      }
      return results;
    },
  };
}

// Helper: create an expired cache entry
function expiredEntry(cacheKey, targetLang, translatedText, model) {
  const expiredDate = new Date(Date.now() - 91 * 24 * 60 * 60 * 1000); // 91 days ago
  return {
    cache_key: cacheKey,
    source_hash: 'dummy',
    target_lang: targetLang,
    translated_text: translatedText,
    model,
    cached_at: expiredDate.toISOString(),
  };
}

// Helper: create a fresh cache entry
function freshEntry(cacheKey, targetLang, translatedText, model) {
  return {
    cache_key: cacheKey,
    source_hash: 'dummy',
    target_lang: targetLang,
    translated_text: translatedText,
    model,
    cached_at: new Date().toISOString(),
  };
}

// ─── computeCacheKey test (indirectly via getCachedTranslation) ───────────────

describe('getCachedTranslation', () => {
  it('returns null when db is null', async () => {
    const result = await cacheModule.getCachedTranslation(null, 'hello', 'bg');
    assert.equal(result, null);
  });

  it('returns null when db is undefined', async () => {
    const result = await cacheModule.getCachedTranslation(undefined, 'hello', 'bg');
    assert.equal(result, null);
  });

  it('returns null for cache miss', async () => {
    const db = createMockDb();
    const result = await cacheModule.getCachedTranslation(db, 'hello world', 'bg');
    assert.equal(result, null);
  });

  it('returns cached translation on cache hit', async () => {
    // First store, then retrieve
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello world', 'bg', 'здравей свят', 'gemini-3.5-flash');

    const result = await cacheModule.getCachedTranslation(db, 'hello world', 'bg');
    assert.ok(result);
    assert.equal(result.translated_text, 'здравей свят');
    assert.equal(result.model, 'gemini-3.5-flash');
  });

  it('returns null for different target language (cache miss)', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello world', 'bg', 'здравей свят', 'gemini-3.5-flash');

    const result = await cacheModule.getCachedTranslation(db, 'hello world', 'de');
    assert.equal(result, null);
  });

  it('returns null for different source text (cache miss)', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello world', 'bg', 'здравей свят', 'gemini-3.5-flash');

    const result = await cacheModule.getCachedTranslation(db, 'goodbye world', 'bg');
    assert.equal(result, null);
  });

  it('returns null and deletes expired entry on read', async () => {
    const db = createMockDb();
    // Manually insert an expired entry
    const cacheKey = await computeTestCacheKey('old text', 'bg');
    db._data.set(cacheKey, expiredEntry(cacheKey, 'bg', 'стар текст', 'glm-4.7-flash'));

    // Lookup should return null and delete the entry
    const result = await cacheModule.getCachedTranslation(db, 'old text', 'bg');
    assert.equal(result, null);

    // Verify entry was deleted
    assert.ok(!db._data.has(cacheKey));
  });

  it('returns result for fresh entry (within TTL)', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'fresh text', 'bg', 'свеж текст', 'gemini-2.5-flash');

    const result = await cacheModule.getCachedTranslation(db, 'fresh text', 'bg');
    assert.ok(result);
    assert.equal(result.translated_text, 'свеж текст');
    assert.equal(result.model, 'gemini-2.5-flash');
  });

  it('handles db errors gracefully (returns null)', async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
          async first() { throw new Error('D1 connection error'); },
        };
      },
    };
    const result = await cacheModule.getCachedTranslation(db, 'hello', 'bg');
    assert.equal(result, null);
  });
});

// ─── getCachedTranslations (batch) ────────────────────────────────────────────

describe('getCachedTranslations', () => {
  it('returns empty map when db is null', async () => {
    const result = await cacheModule.getCachedTranslations(null, [], 'bg');
    assert.ok(result instanceof Map);
    assert.equal(result.size, 0);
  });

  it('returns empty map for empty pages array', async () => {
    const db = createMockDb();
    const result = await cacheModule.getCachedTranslations(db, [], 'bg');
    assert.equal(result.size, 0);
  });

  it('returns empty map when no pages are cached', async () => {
    const db = createMockDb();
    const pages = [
      { index: 1, text: 'page one' },
      { index: 2, text: 'page two' },
    ];
    const result = await cacheModule.getCachedTranslations(db, pages, 'bg');
    assert.equal(result.size, 0);
  });

  it('returns cached pages only (partial cache hit)', async () => {
    const db = createMockDb();
    // Pre-store page 1
    await cacheModule.storeCachedTranslation(db, 'page one', 'bg', 'страница едно', 'gemini-3.5-flash');

    const pages = [
      { index: 1, text: 'page one' },
      { index: 2, text: 'page two' },
    ];
    const result = await cacheModule.getCachedTranslations(db, pages, 'bg');
    assert.equal(result.size, 1);
    assert.ok(result.has(1));
    assert.equal(result.get(1).translated_text, 'страница едно');
  });

  it('returns all pages on full cache hit', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'page one', 'bg', 'страница едно', 'gemini-3.5-flash');
    await cacheModule.storeCachedTranslation(db, 'page two', 'bg', 'страница две', 'gemini-3.5-flash');

    const pages = [
      { index: 1, text: 'page one' },
      { index: 2, text: 'page two' },
    ];
    const result = await cacheModule.getCachedTranslations(db, pages, 'bg');
    assert.equal(result.size, 2);
    assert.ok(result.has(1));
    assert.ok(result.has(2));
  });

  it('cleans up expired entries on batch read', async () => {
    const db = createMockDb();
    // Store fresh page 1
    await cacheModule.storeCachedTranslation(db, 'fresh page', 'bg', 'своя страница', 'gemini-3.5-flash');
    // Manually insert expired page 2
    const expiredKey = await computeTestCacheKey('old page', 'bg');
    db._data.set(expiredKey, expiredEntry(expiredKey, 'bg', 'стара страница', 'glm-4.7-flash'));

    const pages = [
      { index: 1, text: 'fresh page' },
      { index: 2, text: 'old page' },
    ];
    const result = await cacheModule.getCachedTranslations(db, pages, 'bg');
    assert.equal(result.size, 1);
    assert.ok(result.has(1));
    assert.ok(!result.has(2));
  });

  it('handles db errors gracefully (returns empty map)', async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
          async all() { throw new Error('D1 error'); },
        };
      },
    };
    const pages = [{ index: 1, text: 'hello' }];
    const result = await cacheModule.getCachedTranslations(db, pages, 'bg');
    assert.equal(result.size, 0);
  });
});

// ─── storeCachedTranslation ───────────────────────────────────────────────────

describe('storeCachedTranslation', () => {
  it('does nothing when db is null', async () => {
    // Should not throw
    await cacheModule.storeCachedTranslation(null, 'text', 'bg', 'текст', 'model');
  });

  it('stores a translation successfully', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello world', 'bg', 'здравей свят', 'gemini-3.5-flash');

    // Verify it's stored
    const result = await cacheModule.getCachedTranslation(db, 'hello world', 'bg');
    assert.ok(result);
    assert.equal(result.translated_text, 'здравей свят');
    assert.equal(result.model, 'gemini-3.5-flash');
  });

  it('overwrites existing entry (INSERT OR REPLACE)', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello', 'bg', 'здравей', 'gemini-3.5-flash');
    await cacheModule.storeCachedTranslation(db, 'hello', 'bg', 'здравей (updated)', 'gemini-2.5-flash');

    const result = await cacheModule.getCachedTranslation(db, 'hello', 'bg');
    assert.equal(result.translated_text, 'здравей (updated)');
    assert.equal(result.model, 'gemini-2.5-flash');
  });

  it('handles db errors gracefully', async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
          async run() { throw new Error('D1 write error'); },
        };
      },
    };
    // Should not throw
    await cacheModule.storeCachedTranslation(db, 'text', 'bg', 'текст', 'model');
  });

  it('stores same text for different languages separately', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello', 'bg', 'здравей', 'gemini-3.5-flash');
    await cacheModule.storeCachedTranslation(db, 'hello', 'de', 'hallo', 'gemini-3.5-flash');

    const bgResult = await cacheModule.getCachedTranslation(db, 'hello', 'bg');
    const deResult = await cacheModule.getCachedTranslation(db, 'hello', 'de');
    assert.equal(bgResult.translated_text, 'здравей');
    assert.equal(deResult.translated_text, 'hallo');
  });
});

// ─── storeCachedTranslations (batch) ──────────────────────────────────────────

describe('storeCachedTranslations', () => {
  it('does nothing when db is null', async () => {
    await cacheModule.storeCachedTranslations(null, []);
  });

  it('does nothing for empty translations array', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslations(db, []);
  });

  it('stores multiple translations in batch', async () => {
    const db = createMockDb();
    const translations = [
      { sourceText: 'one', targetLang: 'bg', translatedText: 'едно', model: 'gemini' },
      { sourceText: 'two', targetLang: 'bg', translatedText: 'две', model: 'gemini' },
      { sourceText: 'three', targetLang: 'bg', translatedText: 'три', model: 'glm' },
    ];
    await cacheModule.storeCachedTranslations(db, translations);

    // Verify each is stored
    const r1 = await cacheModule.getCachedTranslation(db, 'one', 'bg');
    const r2 = await cacheModule.getCachedTranslation(db, 'two', 'bg');
    const r3 = await cacheModule.getCachedTranslation(db, 'three', 'bg');
    assert.equal(r1.translated_text, 'едно');
    assert.equal(r2.translated_text, 'две');
    assert.equal(r3.translated_text, 'три');
  });

  it('handles db errors gracefully', async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
        };
      },
      async batch() { throw new Error('D1 batch error'); },
    };
    const translations = [
      { sourceText: 'one', targetLang: 'bg', translatedText: 'едно', model: 'gemini' },
    ];
    await cacheModule.storeCachedTranslations(db, translations);
  });
});

// ─── getCacheStats ────────────────────────────────────────────────────────────

describe('getCacheStats', () => {
  it('returns null when db is null', async () => {
    const result = await cacheModule.getCacheStats(null);
    assert.equal(result, null);
  });

  it('returns stats with zero entries for empty cache', async () => {
    const db = createMockDb();
    // Mock the batch call for stats
    db._mockStats = { total: 0, expired: 0, languages: [] };
    db.batch = async (stmts) => {
      return [
        { results: [{ count: 0 }] },
        { results: [{ count: 0 }] },
        { results: [] },
      ];
    };
    const result = await cacheModule.getCacheStats(db);
    assert.ok(result);
    assert.equal(result.total_entries, 0);
    assert.equal(result.expired_entries, 0);
    assert.deepEqual(result.languages, []);
  });

  it('returns correct stats with cached entries', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello', 'bg', 'здравей', 'gemini');
    await cacheModule.storeCachedTranslation(db, 'world', 'de', 'welt', 'glm');

    // Override batch for stats query
    db.batch = async (stmts) => {
      return [
        { results: [{ count: 2 }] },
        { results: [{ count: 0 }] },
        { results: [{ target_lang: 'bg' }, { target_lang: 'de' }] },
      ];
    };
    const result = await cacheModule.getCacheStats(db);
    assert.equal(result.total_entries, 2);
    assert.equal(result.expired_entries, 0);
    assert.deepEqual(result.languages, ['bg', 'de']);
  });

  it('handles db errors gracefully (returns null)', async () => {
    const db = {
      batch: async () => { throw new Error('D1 error'); },
      prepare() { return { bind() { return this; } }; },
    };
    const result = await cacheModule.getCacheStats(db);
    assert.equal(result, null);
  });
});

// ─── Cache Key Determinism ───────────────────────────────────────────────────

describe('cache key determinism', () => {
  it('same input produces same cache key (round-trip)', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'test text', 'fr', 'texte de test', 'gemini');
    // Multiple lookups should all succeed
    const r1 = await cacheModule.getCachedTranslation(db, 'test text', 'fr');
    const r2 = await cacheModule.getCachedTranslation(db, 'test text', 'fr');
    assert.equal(r1.translated_text, r2.translated_text);
  });

  it('different text produces different cache key', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'text A', 'bg', 'текст А', 'gemini');
    const result = await cacheModule.getCachedTranslation(db, 'text B', 'bg');
    assert.equal(result, null);
  });

  it('same text different language produces different cache key', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello', 'bg', 'здравей', 'gemini');
    const result = await cacheModule.getCachedTranslation(db, 'hello', 'es');
    assert.equal(result, null);
  });

  it('whitespace differences produce different cache keys', async () => {
    const db = createMockDb();
    await cacheModule.storeCachedTranslation(db, 'hello world', 'bg', 'здравей свят', 'gemini');
    const result = await cacheModule.getCachedTranslation(db, 'hello  world', 'bg');
    assert.equal(result, null);
  });
});

// ─── TTL Behavior ─────────────────────────────────────────────────────────────

describe('TTL behavior', () => {
  it('entry created 89 days ago is still valid', async () => {
    const db = createMockDb();
    const cacheKey = await computeTestCacheKey('89 day text', 'bg');
    const eightyNineDaysAgo = new Date(Date.now() - 89 * 24 * 60 * 60 * 1000);
    db._data.set(cacheKey, {
      cache_key: cacheKey,
      source_hash: 'dummy',
      target_lang: 'bg',
      translated_text: '89 дни текст',
      model: 'gemini',
      cached_at: eightyNineDaysAgo.toISOString(),
    });

    const result = await cacheModule.getCachedTranslation(db, '89 day text', 'bg');
    assert.ok(result);
    assert.equal(result.translated_text, '89 дни текст');
  });

  it('entry created 91 days ago is expired and deleted', async () => {
    const db = createMockDb();
    const cacheKey = await computeTestCacheKey('91 day text', 'bg');
    const ninetyOneDaysAgo = new Date(Date.now() - 91 * 24 * 60 * 60 * 1000);
    db._data.set(cacheKey, {
      cache_key: cacheKey,
      source_hash: 'dummy',
      target_lang: 'bg',
      translated_text: '91 дни текст',
      model: 'gemini',
      cached_at: ninetyOneDaysAgo.toISOString(),
    });

    const result = await cacheModule.getCachedTranslation(db, '91 day text', 'bg');
    assert.equal(result, null);
    assert.ok(!db._data.has(cacheKey));
  });
});

// Helper to compute the same cache key as the module (for test setup)
async function computeTestCacheKey(text, lang) {
  const combined = `${lang}:${text}`;
  const encoder = new TextEncoder();
  const data = encoder.encode(combined);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
