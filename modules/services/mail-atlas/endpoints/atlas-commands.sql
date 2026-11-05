-- HTTP GET
-- The commands waiting on an agent, oldest first — same read shape as
-- /api/atlas-actions, only without a message behind each row.
select
  c.id,
  c.instruction,
  c.status,
  c.requested_at,
  c.closed_at,
  c.result
from mail_command c
where c.status = :status
order by c.requested_at asc, c.id asc
limit :lim;
