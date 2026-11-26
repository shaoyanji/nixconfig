-- HTTP GET
-- One conversation in chronological order. `id` is the numeric envelope id used
-- by search and reader; the endpoint resolves its thread_id first, so callers
-- never need to know whether the archive or the originating mail system minted
-- the thread identifier. A message without a thread id is a one-letter thread.
with anchor as (
  select e.id, e.message_id, e.thread_id
  from emails e
  where e.id = :id::bigint
  limit 1
), letters as (
  select e.*
  from anchor a
  join emails e on (
    (a.thread_id is not null and a.thread_id <> '' and e.thread_id = a.thread_id)
    or (coalesce(a.thread_id, '') = '' and e.message_id = a.message_id)
  )
), counted as (
  select
    l.*,
    count(*) over () as thread_count,
    count(l.attachment_path) over () as attachments,
    (select json_agg(distinct x.sender) from letters x where coalesce(x.sender, '') <> '') as participants
  from letters l
)
select
  c.id,
  c.message_id,
  c.thread_id,
  c.sender,
  c.recipients,
  c.subject,
  c.sent_at,
  c.attachment_path,
  c.thread_count::int,
  c.attachments::int,
  c.participants,
  coalesce((select b.box from mail_box b where b.message_id = c.message_id), 'inbox') as box,
  coalesce(
    (select json_agg(et.tag order by et.tag)
     from email_tag et where et.message_id = c.message_id),
    '[]'::json
  ) as tags,
  coalesce(
    (select json_agg(distinct tr.tier)
     from email_triage tr where tr.message_id = c.message_id),
    '[]'::json
  ) as triage
from counted c
order by c.sent_at asc nulls last, c.id asc
limit :lim;
