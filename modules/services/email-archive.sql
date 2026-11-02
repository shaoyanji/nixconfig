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
