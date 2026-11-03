-- HTTP GET
-- The hub's own dashboard: one row per owner, how much of the archive is waiting
-- for it, and when it last saw work. A plugin exists the moment a triage rule
-- assigns its owner, so this is the registry — no second list to keep in step.
--
-- One verdict per message, the newest: two classifiers both have an opinion on
-- every message, and counting both inflated the queue by exactly 2x when this
-- first ran (1399 "open" for a mailbox of 1100).
with latest as (
  select distinct on (message_id)
    message_id,
    owner,
    tier,
    decided_at,
    resolved_at
  from email_triage
  order by message_id, decided_at desc
)
select
  split_part(owner, ':', 1) as kind,
  owner,
  count(*) filter (where resolved_at is null) as open,
  count(*) filter (where resolved_at is not null) as resolved,
  max(decided_at) as last_decision,
  max(resolved_at) as last_resolved
from latest
group by 1, 2
order by open desc, owner;
