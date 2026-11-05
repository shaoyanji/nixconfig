-- HTTP GET
-- The queue an agent drains: `status=pending` is the work, `done`/`dismissed`
-- is the record. Oldest first, so a handed-off instruction does not sit behind
-- whatever the operator clicked a second ago.
--
-- `task agents:mail:atlas` prints this as TOON; Hermes reads it, executes with
-- himalaya under its own `--apply` gate, then posts to /api/atlas-close.
select
  a.id,
  a.message_id,
  a.kind,
  a.instruction,
  a.status,
  a.requested_at,
  a.result,
  e.sender,
  e.subject,
  e.sent_at
from mail_action a
join emails e on e.message_id = a.message_id
where a.status = :status
order by a.requested_at asc, a.id asc
limit :lim;
