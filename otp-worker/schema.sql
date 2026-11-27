CREATE TABLE IF NOT EXISTS otp_challenges (
  email_hash TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  otp_hash TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  resend_window_start INTEGER NOT NULL,
  resend_count INTEGER NOT NULL DEFAULT 0,
  attempts INTEGER NOT NULL DEFAULT 0,
  verified INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_otp_expiry
ON otp_challenges(expires_at);

-- Durable citizen profile deletion jobs. A row is written when the citizen
-- confirms deletion and is retried by the hourly cron until cleanup finishes.
-- The email is dropped after the confirmation is sent, or after 30 days.
CREATE TABLE IF NOT EXISTS citizen_deletions (
  uid TEXT PRIMARY KEY,
  email TEXT,
  status TEXT NOT NULL,
  email_status TEXT NOT NULL,
  requested_at INTEGER NOT NULL,
  purge_deadline INTEGER NOT NULL,
  deleted_at INTEGER,
  next_attempt_at INTEGER,
  lease_until INTEGER
);

CREATE INDEX IF NOT EXISTS idx_citizen_deletions_due
ON citizen_deletions(next_attempt_at);

CREATE TABLE IF NOT EXISTS data_exports (
  export_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  email_hash TEXT NOT NULL,
  recipient_email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'ready',
  encrypted_payload TEXT NOT NULL,
  payload_iv TEXT NOT NULL,
  report_count INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  delivered_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_data_exports_expiry
ON data_exports(expires_at);

CREATE INDEX IF NOT EXISTS idx_data_exports_user
ON data_exports(user_id, created_at);
