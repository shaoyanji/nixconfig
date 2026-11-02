-- HTTP GET
-- Newest first. NpgsqlRest derives /api/list-emails from this filename and
-- publishes :lim as a query parameter; it is required.
select
  id,
  message_id,
  thread_id,
  sender,
  recipients,
  subject,
  sent_at,
  labels,
  attachment_path,
  length(coalesce(body_plain, '')) as body_length
from emails
order by sent_at desc nulls last, id desc
limit :lim;
