-- The email archive: metadata and plain-text bodies only. Attachment bytes live
-- on disk (`attachment_path` names the file) and are mirrored to Google Drive.
-- Applied by email-archive-db-init as the archive role on every activation, so
-- every statement is idempotent.

CREATE TABLE IF NOT EXISTS emails (
  id              bigserial PRIMARY KEY,
  message_id      text UNIQUE NOT NULL,
  thread_id       text,
  sender          text,
  recipients      text[],
  subject         text,
  sent_at         timestamptz,
  labels          text[],
  body_plain      text,
  attachment_path text,
  search_vector   tsvector
    GENERATED ALWAYS AS (
      to_tsvector(
        'english',
        coalesce(subject, '') || ' ' ||
        coalesce(sender, '') || ' ' ||
        coalesce(body_plain, '')
      )
    ) STORED
);

CREATE INDEX IF NOT EXISTS emails_search_idx
  ON emails
  USING GIN (search_vector);

CREATE INDEX IF NOT EXISTS emails_sent_at_idx
  ON emails (sent_at DESC);

CREATE INDEX IF NOT EXISTS emails_thread_id_idx
  ON emails (thread_id);

-- Triage is a verdict *about* a message, and a verdict is a current state, not
-- a history: one message keeps one row (`UNIQUE (message_id)`), and a second
-- classifier replaces the first instead of adding a row beside it. Keying on
-- (message_id, classifier) let re-classification accumulate — 10,165 rows for
-- 2,907 messages on 2026-11-22 — so the route now conflicts on `message_id`.
-- `owner` is the routing decision: `agent:ci` means the loop closes on an agent
-- instead of a human queue.
--
-- `resolved_at` is how a CI notice stops being noise: an agent that fixes the
-- run marks the verdict resolved, and the row leaves /api/agent-queue without
-- deleting the mail or its searchable body.
CREATE TABLE IF NOT EXISTS email_triage (
  message_id  text NOT NULL REFERENCES emails (message_id) ON DELETE CASCADE,
  classifier  text NOT NULL,
  tier        text NOT NULL
    CHECK (tier IN ('person', 'action', 'digest', 'robot', 'review', 'ignore')),
  owner       text NOT NULL DEFAULT 'human',
  reason      text,
  confidence  real,
  decided_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  PRIMARY KEY (message_id, classifier),
  UNIQUE (message_id)
);

-- `ignore` was added after the table existed, and CREATE TABLE IF NOT EXISTS
-- never alters a constraint: without these two statements an ignore write is a
-- 400 on the live database while a fresh one accepts it.
ALTER TABLE email_triage DROP CONSTRAINT IF EXISTS email_triage_tier_check;
ALTER TABLE email_triage ADD CONSTRAINT email_triage_tier_check
  CHECK (tier IN ('person', 'action', 'digest', 'robot', 'review', 'ignore'));

-- CREATE TABLE IF NOT EXISTS never alters an existing table, so the one-row rule
-- needs its own idempotent statement. A unique_violation means the archive still
-- holds duplicates from the composite key: dedupe, then re-activate.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'email_triage'::regclass
      AND conname = 'email_triage_message_id_key'
  ) THEN
    BEGIN
      ALTER TABLE email_triage
        ADD CONSTRAINT email_triage_message_id_key UNIQUE (message_id);
    EXCEPTION WHEN unique_violation THEN
      RAISE NOTICE 'email_triage still holds duplicate message_id rows; one-row constraint not added';
    END;
  END IF;
END $$;

-- The three read paths are "unresolved, newest first", per tier and per owner.
CREATE INDEX IF NOT EXISTS email_triage_open_idx
  ON email_triage (tier, decided_at DESC)
  WHERE resolved_at IS NULL;

CREATE INDEX IF NOT EXISTS email_triage_owner_idx
  ON email_triage (owner, decided_at DESC)
  WHERE resolved_at IS NULL;
