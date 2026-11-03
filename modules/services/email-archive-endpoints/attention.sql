-- HTTP GET
-- What actually needs a person: person, action and review tiers, unresolved,
-- newest first. One row per message — the newest verdict from any classifier
-- wins, so a second classifier's opinion is an upgrade, never a duplicate.
select
  e.id,
  e.message_id,
  e.sender,
  e.subject,
  e.sent_at,
  t.tier,
  t.owner,
  t.reason,
  t.confidence,
  length(coalesce(e.body_plain, '')) as body_length
from emails e
join lateral (
  select *
  from email_triage x
  where x.message_id = e.message_id
  order by x.decided_at desc
  limit 1
) t on true
-- `owner` is the routing decision: a verdict an agent owns belongs to that
-- agent's queue, not to the person's. Without this, the pipeline's 27 ATS mails
-- would sit in the one queue that is supposed to be about people.
where t.tier in ('person', 'action', 'review')
  and t.resolved_at is null
  and t.owner not like 'agent:%'
order by
  case t.tier when 'person' then 0 when 'review' then 1 else 2 end,
  e.sent_at desc nulls last,
  e.id desc
limit :lim;
