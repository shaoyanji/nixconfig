-- HTTP POST
-- One operator decision about one message: `kind` is `archive`, `delete` or
-- `hermes`; `instruction` is the sentence Hermes should act on (empty for the
-- two mechanical kinds). A repeat is an update, not a second request.
--
-- This endpoint records the request. Executing it is an agent's job with its
-- own gate — the archive is the searchable record of the mail and nothing here
-- removes a message.
--
-- It also closes the open verdicts for the message: the person has just dealt
-- with it, so it should leave /api/attention in the same act.
with previous as (
  select coalesce((select b.box from mail_box b where b.message_id = :message_id), 'inbox') as box
),
action as (
  insert into mail_action (message_id, kind, instruction)
  values (:message_id, :kind, nullif(:instruction, ''))
  on conflict (message_id, kind) do update set
    instruction  = excluded.instruction,
    status       = 'pending',
    requested_at = now(),
    closed_at    = null,
    result       = null
  returning id, message_id, kind, instruction, status, requested_at
),
dealt as (
  update email_triage
  set resolved_at = now()
  where message_id = :message_id
    and resolved_at is null
  returning 1
),
-- The letter leaves the working inbox the moment it is asked for, not when an
-- agent gets to it: a list that keeps showing what you just queued is how a
-- decision feels ignored.
boxed as (
  insert into mail_box (message_id, box, kind, changed_at)
  values (:message_id, 'queued', :kind, now())
  on conflict (message_id) do update set
    box        = 'queued',
    kind       = excluded.kind,
    changed_at = now()
  returning 1
),
-- The trail, paragraph one: the letter left the inbox because a person said so.
-- A repeat of the same decision while it is still queued is not a new move.
evented as (
  insert into mail_box_event (message_id, from_box, box, reason)
  select :message_id, p.box, 'queued', 'decision ' || :kind
  from previous p
  where p.box is distinct from 'queued'
  returning 1
)
select
  a.id,
  a.message_id,
  a.kind,
  a.instruction,
  a.status,
  a.requested_at,
  (select count(*) from dealt) as resolved_verdicts,
  (select count(*) from boxed) as boxed,
  (select count(*) from evented) as logged
from action a;
