-- Per-device daily translation quota.
-- Each installation gets a daily free quota (e.g. 50 pages/day).
-- Tracks usage via installation_id (UUID generated on first install).
-- Rows are scoped to a specific date; old rows are cleaned up lazily.

CREATE TABLE IF NOT EXISTS device_quota (
  installation_id TEXT NOT NULL,
  quota_date TEXT NOT NULL,
  pages_used INTEGER NOT NULL DEFAULT 0,
  last_updated TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (installation_id, quota_date)
);

-- Index for quota lookups by installation_id
CREATE INDEX IF NOT EXISTS idx_quota_installation ON device_quota(installation_id);
-- Index for cleanup of old quota rows
CREATE INDEX IF NOT EXISTS idx_quota_date ON device_quota(quota_date);
