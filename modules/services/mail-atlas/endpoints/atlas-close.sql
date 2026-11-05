-- HTTP POST
-- Close a queued action once it has been executed (or refused): `status` is
-- `done` or `dismissed`, `result` is one line of what happened. The instruction
-- itself is never rewritten — the row is the record of the request.
--
-- The letter's box follows the outcome here, not at request time: `done` means
-- the mailbox really moved it (archived, or trashed for a deletion), while
-- `dismissed` means it had already left the inbox by other means.
with closed as (
  update mail_action
  set
    status    = :status,
    closed_at = now(),
    result    = nullif(:result, '')
  where id = :id::bigint
  returning id, message_id, kind, status, closed_at, result
),
boxed as (
  update mail_box b
  set
    box        = case
                   when c.status = 'dismissed' then 'gone'
                   when c.status = 'done' and c.kind = 'delete' then 'trashed'
                   when c.status = 'done' then 'archived'
                   else 'queued'
                 end,
    kind       = c.kind,
    changed_at = now()
  from closed c
  where b.message_id = c.message_id
  returning b.message_id, b.box, 'queued'::text as from_box, c.status
),
-- The trail, paragraph two: what the mailbox actually did with it. `from_box`
-- is 'queued' because that is the move this endpoint closes.
evented as (
  insert into mail_box_event (message_id, from_box, box, reason)
  select b.message_id, b.from_box, b.box, 'drain ' || b.status
  from boxed b
  returning 1
)
select c.*, (select count(*) from boxed) as boxed, (select count(*) from evented) as logged
from closed c;
