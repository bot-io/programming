import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const ku = await import('../src/key-usage.js');

// ─── Mock D1 Database for key_usage table ────────────────────────────────────
// Schema: key_usage(key_index INTEGER, usage_date TEXT, call_count INTEGER,
//                   last_updated TEXT, PRIMARY KEY(key_index, usage_date))
// Mock key: `${keyIndex}:${usageDate}`

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
          if (sql.includes('SELECT call_count FROM key_usage')) {
            // getKeyUsageToday / getGlmUsageToday
            const [keyIndex, usageDate] = stmt._bindings;
            const row = self._data.get(`${keyIndex}:${usageDate}`);
            return row || null;
          }
          return null;
        },
        async run() {
          if (sql.includes('INSERT INTO key_usage')) {
            // incrementKeyUsage: bind(keyIndex, today, count, count)
            const [keyIndex, usageDate, insertCount, incrCount] = stmt._bindings;
            const key = `${keyIndex}:${usageDate}`;
            const existing = self._data.get(key);
            if (existing) {
              existing.call_count += incrCount;
              existing.last_updated = 'mock-now';
            } else {
              self._data.set(key, {
                key_index: keyIndex,
                usage_date: usageDate,
                call_count: insertCount,
                last_updated: 'mock-now',
              });
            }
            return { success: true };
          }
          if (sql.includes('DELETE FROM key_usage')) {
            // cleanupOldKeyUsage: bind(weekAgoDate)
            const [cutoff] = stmt._bindings;
            let changes = 0;
            for (const [key, row] of self._data) {
              if (row.usage_date < cutoff) {
                self._data.delete(key);
                changes++;
              }
            }
            return { success: true, meta: { changes } };
          }
          return { success: true };
        },
        async all() {
          return { results: [] };
        },
      };
      return stmt;
    },
    async batch(stmts) {
      const results = [];
      for (const s of stmts) results.push(await s.run());
      return results;
    },
  };
}

// ─── incrementKeyUsage ───────────────────────────────────────────────────────

describe('incrementKeyUsage', () => {
  it('is a no-op when db is null', async () => {
    await assert.doesNotReject(() => ku.incrementKeyUsage(null, 0));
  });

  it('inserts a new row with count=1 by default', async () => {
    const db = createMockDb();
    await ku.incrementKeyUsage(db, 0);
    const today = new Date().toISOString().slice(0, 10);
    const row = db._data.get(`0:${today}`);
    assert.ok(row, 'row should exist');
    assert.equal(row.call_count, 1);
  });

  it('inserts a new row with a custom count', async () => {
    const db = createMockDb();
    await ku.incrementKeyUsage(db, 2, 5);
    const today = new Date().toISOString().slice(0, 10);
    const row = db._data.get(`2:${today}`);
    assert.equal(row.call_count, 5);
  });

  it('increments an existing row (ON CONFLICT update)', async () => {
    const db = createMockDb();
    await ku.incrementKeyUsage(db, 1, 3);
    await ku.incrementKeyUsage(db, 1, 2);
    const today = new Date().toISOString().slice(0, 10);
    const row = db._data.get(`1:${today}`);
    assert.equal(row.call_count, 5);
  });

  it('tracks multiple keys independently', async () => {
    const db = createMockDb();
    await ku.incrementKeyUsage(db, 0, 10);
    await ku.incrementKeyUsage(db, 1, 20);
    await ku.incrementKeyUsage(db, 0, 5);
    const today = new Date().toISOString().slice(0, 10);
    assert.equal(db._data.get(`0:${today}`).call_count, 15);
    assert.equal(db._data.get(`1:${today}`).call_count, 20);
  });

  it('handles db errors gracefully (does not throw)', async () => {
    const badDb = {
      prepare() {
        return {
          bind() {
            return this;
          },
          async run() {
            throw new Error('D1 unavailable');
          },
        };
      },
    };
    await assert.doesNotReject(() => ku.incrementKeyUsage(badDb, 0, 1));
  });
});

// ─── getKeyUsageToday ────────────────────────────────────────────────────────

describe('getKeyUsageToday', () => {
  it('returns default 250 remaining per key when db is null', async () => {
    const results = await ku.getKeyUsageToday(null, 3);
    assert.equal(results.length, 3);
    for (const r of results) {
      assert.equal(r.callCount, 0);
      assert.equal(r.remaining, 250);
      assert.equal(r.dailyLimit, 250);
    }
  });

  it('returns tracked usage for keys with data', async () => {
    const db = createMockDb();
    await ku.incrementKeyUsage(db, 0, 100);
    await ku.incrementKeyUsage(db, 1, 50);
    const results = await ku.getKeyUsageToday(db, 2);
    assert.equal(results.length, 2);
    assert.equal(results[0].keyIndex, 0);
    assert.equal(results[0].callCount, 100);
    assert.equal(results[0].remaining, 150);
    assert.equal(results[1].keyIndex, 1);
    assert.equal(results[1].callCount, 50);
    assert.equal(results[1].remaining, 200);
  });

  it('returns 250 remaining for keys with no usage today', async () => {
    const db = createMockDb();
    const results = await ku.getKeyUsageToday(db, 2);
    assert.equal(results[0].callCount, 0);
    assert.equal(results[0].remaining, 250);
  });

  it('respects the requested keyCount', async () => {
    const db = createMockDb();
    const results = await ku.getKeyUsageToday(db, 5);
    assert.equal(results.length, 5);
  });

  it('clamps remaining to 0 when usage exceeds daily limit', async () => {
    const db = createMockDb();
    await ku.incrementKeyUsage(db, 0, 300); // exceeds 250 RPD
    const results = await ku.getKeyUsageToday(db, 1);
    assert.equal(results[0].callCount, 300);
    assert.equal(results[0].remaining, 0); // never negative
  });

  it('handles db errors gracefully (falls back to defaults)', async () => {
    const badDb = {
      prepare() {
        return {
          bind() {
            return this;
          },
          async first() {
            throw new Error('D1 unavailable');
          },
        };
      },
    };
    const results = await ku.getKeyUsageToday(badDb, 2);
    assert.equal(results.length, 2);
    for (const r of results) {
      assert.equal(r.callCount, 0);
      assert.equal(r.remaining, 250);
    }
  });
});

// ─── getGlmUsageToday ────────────────────────────────────────────────────────

describe('getGlmUsageToday', () => {
  it('returns 0 when db is null', async () => {
    const result = await ku.getGlmUsageToday(null);
    assert.equal(result.callCount, 0);
  });

  it('returns callCount for the GLM key index', async () => {
    const db = createMockDb();
    await ku.incrementKeyUsage(db, ku.GLM_KEY_INDEX, 7);
    await ku.incrementKeyUsage(db, ku.GLM_KEY_INDEX, 3);
    const result = await ku.getGlmUsageToday(db);
    assert.equal(result.callCount, 10);
  });

  it('returns 0 when no GLM usage recorded today', async () => {
    const db = createMockDb();
    const result = await ku.getGlmUsageToday(db);
    assert.equal(result.callCount, 0);
  });

  it('does not count Gemini keys (index != GLM_KEY_INDEX)', async () => {
    const db = createMockDb();
    await ku.incrementKeyUsage(db, 0, 40);
    await ku.incrementKeyUsage(db, 1, 30);
    const result = await ku.getGlmUsageToday(db);
    assert.equal(result.callCount, 0);
  });

  it('handles db errors gracefully', async () => {
    const badDb = {
      prepare() {
        return {
          bind() {
            return this;
          },
          async first() {
            throw new Error('D1 unavailable');
          },
        };
      },
    };
    const result = await ku.getGlmUsageToday(badDb);
    assert.equal(result.callCount, 0);
  });
});

// ─── cleanupOldKeyUsage ──────────────────────────────────────────────────────

describe('cleanupOldKeyUsage', () => {
  it('returns 0 when db is null', async () => {
    const n = await ku.cleanupOldKeyUsage(null);
    assert.equal(n, 0);
  });

  it('deletes rows older than 7 days and returns the count', async () => {
    const db = createMockDb();
    // Seed: an old row and a recent row
    const oldDate = new Date(Date.now() - 10 * 86400000).toISOString().slice(0, 10);
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`0:${oldDate}`, { key_index: 0, usage_date: oldDate, call_count: 5 });
    db._data.set(`1:${today}`, { key_index: 1, usage_date: today, call_count: 9 });

    const deleted = await ku.cleanupOldKeyUsage(db);
    assert.equal(deleted, 1);
    assert.equal(db._data.size, 1);
    assert.ok(db._data.has(`1:${today}`));
    assert.ok(!db._data.has(`0:${oldDate}`));
  });

  it('preserves recent rows (returns 0 when nothing is old)', async () => {
    const db = createMockDb();
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`0:${today}`, { key_index: 0, usage_date: today, call_count: 1 });
    const deleted = await ku.cleanupOldKeyUsage(db);
    assert.equal(deleted, 0);
    assert.equal(db._data.size, 1);
  });

  it('handles db errors gracefully', async () => {
    const badDb = {
      prepare() {
        return {
          bind() {
            return this;
          },
          async run() {
            throw new Error('D1 unavailable');
          },
        };
      },
    };
    const n = await ku.cleanupOldKeyUsage(badDb);
    assert.equal(n, 0);
  });
});

// ─── Constants ───────────────────────────────────────────────────────────────

describe('constants', () => {
  it('GLM_KEY_INDEX is 100 (distinct from Gemini keys 0..N-1)', () => {
    assert.equal(ku.GLM_KEY_INDEX, 100);
  });
});
