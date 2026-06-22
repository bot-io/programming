-- Key usage tracking table
-- Tracks daily Gemini API calls per key for the monitoring dashboard

CREATE TABLE IF NOT EXISTS key_usage (
  key_index INTEGER NOT NULL,
  usage_date TEXT NOT NULL,          -- "2026-06-12" (UTC date)
  call_count INTEGER DEFAULT 0,
  last_updated TEXT,
  PRIMARY KEY (key_index, usage_date)
);

CREATE INDEX IF NOT EXISTS idx_key_usage_date ON key_usage(usage_date);
