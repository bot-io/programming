import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

const quotaModule = await import('../src/quota.js');

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
          if (sql.includes('SELECT pages_used FROM device_quota')) {
            const [installationId, quotaDate] = stmt._bindings;
            const key = `${installationId}:${quotaDate}`;
            const row = self._data.get(key);
            return row || null;
          }
          return null;
        },
        async run() {
          if (sql.includes('DELETE FROM device_quota')) {
            const cutoffDate = stmt._bindings[0];
            for (const [key, _] of self._data) {
              if (key.split(':')[1] < cutoffDate) {
                self._data.delete(key);
              }
            }
            return { success: true, meta: { changes: 1 } };
          }
          if (sql.includes('INSERT INTO device_quota')) {
            const [installationId, quotaDate, pagesUsed, pagesUsedIncr] = stmt._bindings;
            const key = `${installationId}:${quotaDate}`;
            const existing = self._data.get(key);
            if (existing) {
              existing.pages_used += pagesUsedIncr;
              existing.last_updated = new Date().toISOString();
            } else {
              self._data.set(key, {
                installation_id: installationId,
                quota_date: quotaDate,
                pages_used: pagesUsed,
                last_updated: new Date().toISOString(),
              });
            }
            return { success: true };
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
      for (const stmt of stmts) {
        results.push(await stmt.run());
      }
      return results;
    },
  };
}

// ─── checkDeviceQuota ───────────────────────────────────────────────────────

describe('checkDeviceQuota', () => {
  it('returns allowed=true when db is null', async () => {
    const result = await quotaModule.checkDeviceQuota(null, 'test-id', 1, 50);
    assert.equal(result.allowed, true);
    assert.equal(result.dailyLimit, 50);
    assert.equal(result.remaining, 50);
  });

  it('returns allowed=true when installation_id is null', async () => {
    const db = createMockDb();
    const result = await quotaModule.checkDeviceQuota(db, null, 1, 50);
    assert.equal(result.allowed, true);
    assert.equal(result.remaining, 50);
  });

  it('returns allowed=true when installation_id is empty string', async () => {
    const db = createMockDb();
    const result = await quotaModule.checkDeviceQuota(db, '', 1, 50);
    assert.equal(result.allowed, true);
  });

  it('returns allowed=true for new installation (no usage)', async () => {
    const db = createMockDb();
    const result = await quotaModule.checkDeviceQuota(db, 'new-device-id', 1, 50);
    assert.equal(result.allowed, true);
    assert.equal(result.pagesUsed, 0);
    assert.equal(result.remaining, 50);
  });

  it('returns allowed=true when under quota', async () => {
    const db = createMockDb();
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`device-1:${today}`, {
      installation_id: 'device-1',
      quota_date: today,
      pages_used: 45,
      last_updated: new Date().toISOString(),
    });
    const result = await quotaModule.checkDeviceQuota(db, 'device-1', 3, 50);
    assert.equal(result.allowed, true);
    assert.equal(result.pagesUsed, 45);
    assert.equal(result.remaining, 5);
  });

  it('returns allowed=false when at quota limit', async () => {
    const db = createMockDb();
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`device-1:${today}`, {
      installation_id: 'device-1',
      quota_date: today,
      pages_used: 49,
      last_updated: new Date().toISOString(),
    });
    const result = await quotaModule.checkDeviceQuota(db, 'device-1', 2, 50);
    assert.equal(result.allowed, false);
    assert.equal(result.pagesUsed, 49);
    assert.equal(result.remaining, 1);
  });

  it('returns allowed=false when quota exceeded', async () => {
    const db = createMockDb();
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`device-1:${today}`, {
      installation_id: 'device-1',
      quota_date: today,
      pages_used: 50,
      last_updated: new Date().toISOString(),
    });
    const result = await quotaModule.checkDeviceQuota(db, 'device-1', 1, 50);
    assert.equal(result.allowed, false);
    assert.equal(result.remaining, 0);
  });

  it('uses default daily limit of 50 when not specified', async () => {
    const db = createMockDb();
    const result = await quotaModule.checkDeviceQuota(db, 'device-1', 1);
    assert.equal(result.dailyLimit, 50);
    assert.equal(result.allowed, true);
  });

  it('respects custom daily limit', async () => {
    const db = createMockDb();
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`device-1:${today}`, {
      installation_id: 'device-1',
      quota_date: today,
      pages_used: 10,
      last_updated: new Date().toISOString(),
    });
    const result = await quotaModule.checkDeviceQuota(db, 'device-1', 1, 10);
    assert.equal(result.allowed, false);
    assert.equal(result.dailyLimit, 10);
  });

  it('handles db errors gracefully (fail open)', async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
          async first() { throw new Error('D1 connection error'); },
        };
      },
    };
    const result = await quotaModule.checkDeviceQuota(db, 'device-1', 1, 50);
    assert.equal(result.allowed, true);
  });

  it('different dates are independent', async () => {
    const db = createMockDb();
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    // Yesterday's usage is at limit
    db._data.set(`device-1:${yesterday}`, {
      installation_id: 'device-1',
      quota_date: yesterday,
      pages_used: 50,
      last_updated: new Date().toISOString(),
    });
    // Today should be fine
    const result = await quotaModule.checkDeviceQuota(db, 'device-1', 1, 50);
    assert.equal(result.allowed, true);
    assert.equal(result.pagesUsed, 0);
  });
});

// ─── incrementDeviceQuota ───────────────────────────────────────────────────

describe('incrementDeviceQuota', () => {
  it('does nothing when db is null', async () => {
    await quotaModule.incrementDeviceQuota(null, 'device-1', 1);
  });

  it('does nothing when installation_id is null', async () => {
    const db = createMockDb();
    await quotaModule.incrementDeviceQuota(db, null, 1);
    assert.equal(db._data.size, 0);
  });

  it('creates new quota row for first request', async () => {
    const db = createMockDb();
    await quotaModule.incrementDeviceQuota(db, 'device-1', 3);
    const today = new Date().toISOString().slice(0, 10);
    const key = `device-1:${today}`;
    assert.ok(db._data.has(key));
    assert.equal(db._data.get(key).pages_used, 3);
  });

  it('increments existing quota row', async () => {
    const db = createMockDb();
    await quotaModule.incrementDeviceQuota(db, 'device-1', 5);
    await quotaModule.incrementDeviceQuota(db, 'device-1', 3);
    const today = new Date().toISOString().slice(0, 10);
    const key = `device-1:${today}`;
    assert.equal(db._data.get(key).pages_used, 8);
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
    await quotaModule.incrementDeviceQuota(db, 'device-1', 1);
  });

  it('defaults to 1 page when pagesUsed not specified', async () => {
    const db = createMockDb();
    await quotaModule.incrementDeviceQuota(db, 'device-1');
    const today = new Date().toISOString().slice(0, 10);
    const key = `device-1:${today}`;
    assert.equal(db._data.get(key).pages_used, 1);
  });
});

// ─── getDeviceQuotaStatus ───────────────────────────────────────────────────

describe('getDeviceQuotaStatus', () => {
  it('returns default status when db is null', async () => {
    const result = await quotaModule.getDeviceQuotaStatus(null, 'device-1', 50);
    assert.equal(result.pagesUsed, 0);
    assert.equal(result.dailyLimit, 50);
    assert.equal(result.remaining, 50);
    assert.ok(result.resetAt);
  });

  it('returns default status when installation_id is null', async () => {
    const db = createMockDb();
    const result = await quotaModule.getDeviceQuotaStatus(db, null, 50);
    assert.equal(result.pagesUsed, 0);
    assert.equal(result.remaining, 50);
  });

  it('returns correct status for existing usage', async () => {
    const db = createMockDb();
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`device-1:${today}`, {
      installation_id: 'device-1',
      quota_date: today,
      pages_used: 25,
      last_updated: new Date().toISOString(),
    });
    const result = await quotaModule.getDeviceQuotaStatus(db, 'device-1', 50);
    assert.equal(result.pagesUsed, 25);
    assert.equal(result.dailyLimit, 50);
    assert.equal(result.remaining, 25);
  });

  it('returns 0 remaining when at limit', async () => {
    const db = createMockDb();
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`device-1:${today}`, {
      installation_id: 'device-1',
      quota_date: today,
      pages_used: 50,
      last_updated: new Date().toISOString(),
    });
    const result = await quotaModule.getDeviceQuotaStatus(db, 'device-1', 50);
    assert.equal(result.remaining, 0);
  });

  it('handles db errors gracefully', async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
          async first() { throw new Error('D1 error'); },
        };
      },
    };
    const result = await quotaModule.getDeviceQuotaStatus(db, 'device-1', 50);
    assert.equal(result.pagesUsed, 0);
    assert.equal(result.remaining, 50);
  });

  it('resetAt is a valid ISO date string in the future', async () => {
    const db = createMockDb();
    const result = await quotaModule.getDeviceQuotaStatus(db, 'device-1', 50);
    const resetDate = new Date(result.resetAt);
    assert.ok(!isNaN(resetDate.getTime()));
    assert.ok(resetDate > new Date());
  });
});

// ─── cleanupOldQuotaRows ────────────────────────────────────────────────────

describe('cleanupOldQuotaRows', () => {
  it('returns 0 when db is null', async () => {
    const result = await quotaModule.cleanupOldQuotaRows(null);
    assert.equal(result, 0);
  });

  it('deletes rows older than 2 days', async () => {
    const db = createMockDb();
    const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const today = new Date().toISOString().slice(0, 10);
    db._data.set(`device-1:${threeDaysAgo}`, {
      installation_id: 'device-1',
      quota_date: threeDaysAgo,
      pages_used: 10,
      last_updated: new Date().toISOString(),
    });
    db._data.set(`device-2:${today}`, {
      installation_id: 'device-2',
      quota_date: today,
      pages_used: 5,
      last_updated: new Date().toISOString(),
    });
    const deleted = await quotaModule.cleanupOldQuotaRows(db);
    assert.ok(deleted >= 1);
    // Today's entry should survive
    assert.ok(db._data.has(`device-2:${today}`));
  });

  it('keeps recent rows', async () => {
    const db = createMockDb();
    const today = new Date().toISOString().slice(0, 10);
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    db._data.set(`device-1:${today}`, {
      installation_id: 'device-1',
      quota_date: today,
      pages_used: 10,
      last_updated: new Date().toISOString(),
    });
    db._data.set(`device-2:${yesterday}`, {
      installation_id: 'device-2',
      quota_date: yesterday,
      pages_used: 5,
      last_updated: new Date().toISOString(),
    });
    await quotaModule.cleanupOldQuotaRows(db);
    assert.ok(db._data.has(`device-1:${today}`));
    assert.ok(db._data.has(`device-2:${yesterday}`));
  });

  it('handles db errors gracefully', async () => {
    const db = {
      prepare() {
        return {
          bind() { return this; },
          async run() { throw new Error('D1 error'); },
        };
      },
    };
    const result = await quotaModule.cleanupOldQuotaRows(db);
    assert.equal(result, 0);
  });
});

// ─── Integration: check → increment → check ──────────────────────────────────

describe('quota integration flow', () => {
  it('full flow: check → translate → increment → check shows updated quota', async () => {
    const db = createMockDb();

    // 1. Initial check — should be allowed
    const check1 = await quotaModule.checkDeviceQuota(db, 'test-device', 1, 50);
    assert.equal(check1.allowed, true);
    assert.equal(check1.pagesUsed, 0);

    // 2. Simulate translation — increment quota
    await quotaModule.incrementDeviceQuota(db, 'test-device', 1);

    // 3. Check again — should show 1 page used
    const check2 = await quotaModule.checkDeviceQuota(db, 'test-device', 1, 50);
    assert.equal(check2.allowed, true);
    assert.equal(check2.pagesUsed, 1);
    assert.equal(check2.remaining, 49);
  });

  it('full flow: batch of 3 pages increments correctly', async () => {
    const db = createMockDb();

    // Check quota for 3 pages
    const check = await quotaModule.checkDeviceQuota(db, 'test-device', 3, 50);
    assert.equal(check.allowed, true);

    // Increment by 3
    await quotaModule.incrementDeviceQuota(db, 'test-device', 3);

    // Verify
    const status = await quotaModule.getDeviceQuotaStatus(db, 'test-device', 50);
    assert.equal(status.pagesUsed, 3);
    assert.equal(status.remaining, 47);
  });

  it('full flow: quota exhaustion', async () => {
    const db = createMockDb();

    // Use 49 pages
    await quotaModule.incrementDeviceQuota(db, 'test-device', 49);

    // Check for 1 more — should be allowed
    const check1 = await quotaModule.checkDeviceQuota(db, 'test-device', 1, 50);
    assert.equal(check1.allowed, true);

    // Use that page
    await quotaModule.incrementDeviceQuota(db, 'test-device', 1);

    // Check for 1 more — should be blocked
    const check2 = await quotaModule.checkDeviceQuota(db, 'test-device', 1, 50);
    assert.equal(check2.allowed, false);
    assert.equal(check2.remaining, 0);
  });
});
