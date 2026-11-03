-- HTTP POST
-- One message into the archive: every column the schema stores, keyed on
-- message_id. A repeat of the same id updates the row instead of failing, so an
-- importer can re-run a batch. Empty strings are read as "no value" and the
-- update keeps whatever is already there, which is what makes a metadata-first
-- then body-later import work.
--
-- Two NpgsqlRest facts shape this file (measured on 3.21.0):
--   * the JSON body must carry exactly these nine keys — a missing or unknown
--     key is a 404, not a 400, so a client always sends all of them;
--   * a JSON array cannot be bound to a text[] parameter ("Writing values of
--     'List<Object>' is not supported for parameters having NpgsqlDbType
--     'Unknown'"), so recipients and labels arrive comma-separated and are
--     split here.
insert into emails (
  message_id,
  thread_id,
  sender,
  recipients,
  subject,
  sent_at,
  labels,
  body_plain,
  attachment_path
)
values (
  nullif(:message_id, ''),
  nullif(:thread_id, ''),
  nullif(:sender, ''),
  string_to_array(nullif(:recipients, ''), ','),
  nullif(:subject, ''),
  nullif(:sent_at, '')::timestamptz,
  string_to_array(nullif(:labels, ''), ','),
  nullif(:body_plain, ''),
  nullif(:attachment_path, '')
)
on conflict (message_id) do update set
  thread_id       = coalesce(excluded.thread_id, emails.thread_id),
  sender          = coalesce(excluded.sender, emails.sender),
  recipients      = coalesce(excluded.recipients, emails.recipients),
  subject         = coalesce(excluded.subject, emails.subject),
  sent_at         = coalesce(excluded.sent_at, emails.sent_at),
  labels          = coalesce(excluded.labels, emails.labels),
  body_plain      = coalesce(excluded.body_plain, emails.body_plain),
  attachment_path = coalesce(excluded.attachment_path, emails.attachment_path)
returning id, message_id;
