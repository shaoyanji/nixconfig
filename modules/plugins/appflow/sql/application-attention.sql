-- HTTP GET
-- Applications with mail nobody has dealt with yet: one row per application, its
-- newest unresolved message, and what tier that message carries. This is the
-- pipeline view an agent reads instead of guessing from the inbox.
select
  a.id,
  a.company,
  a.role,
  a.stage,
  a.status,
  e.subject,
  e.sender,
  e.sent_at,
  t.tier,
  t.owner
from applications a
join lateral (
  select am.message_id
  from application_mail am
  join lateral (
    select x.tier, x.owner, x.resolved_at
    from email_triage x
    where x.message_id = am.message_id
    order by x.decided_at desc
    limit 1
  ) x on true
  where x.resolved_at is null
    and x.tier in ('person', 'action', 'review')
  order by am.linked_at desc
  limit 1
) open_mail on true
join emails e on e.message_id = open_mail.message_id
join lateral (
  select x.tier, x.owner
  from email_triage x
  where x.message_id = e.message_id
  order by x.decided_at desc
  limit 1
) t on true
order by e.sent_at desc nulls last
limit :lim;
