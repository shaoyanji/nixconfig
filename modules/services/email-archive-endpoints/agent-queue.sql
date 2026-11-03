-- HTTP GET
-- The agent's own inbox: every unresolved verdict whose owner is an agent, with
-- the message id a dispatch needs. `owner_kind` is the prefix before the colon,
-- so `owner=agent` alone returns every agent queue.
select
  e.message_id,
  e.sender,
  e.subject,
  e.sent_at,
  t.tier,
  t.owner,
  t.reason,
  split_part(t.owner, ':', 1) as owner_kind,
  split_part(t.owner, ':', 2) as owner_name
from emails e
join lateral (
  select *
  from email_triage x
  where x.message_id = e.message_id
  order by x.decided_at desc
  limit 1
) t on true
where t.owner like :owner || '%'
  and t.resolved_at is null
order by e.sent_at desc nulls last, e.id desc
limit :lim;
