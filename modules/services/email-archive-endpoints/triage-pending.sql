-- HTTP GET
-- Messages no classifier has judged yet. This is what makes the hourly
-- classifier cheap: it asks for the gap, not the archive, and the gap shrinks
-- as the importer fills it.
select
  e.message_id,
  e.sender,
  e.recipients,
  e.subject,
  e.labels,
  e.sent_at,
  length(coalesce(e.body_plain, '')) as body_length
from emails e
where not exists (
  select 1
  from email_triage t
  where t.message_id = e.message_id
    and t.classifier = :classifier
)
order by e.sent_at desc nulls last, e.id desc
limit :lim;
