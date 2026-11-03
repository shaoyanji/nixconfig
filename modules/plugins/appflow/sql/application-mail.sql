-- HTTP GET
-- The mail behind one application, newest first, with the verdict that decides
-- whether it still needs someone. This is the join that makes the mail archive
-- and the tracker one system instead of two.
select
  e.message_id,
  e.sender,
  e.subject,
  e.sent_at,
  am.matched_by,
  am.confidence,
  t.tier,
  t.owner,
  t.resolved_at
from application_mail am
join emails e on e.message_id = am.message_id
left join lateral (
  select *
  from email_triage x
  where x.message_id = e.message_id
  order by x.decided_at desc
  limit 1
) t on true
where am.application_id = :application_id
order by e.sent_at desc nulls last
limit :lim;
