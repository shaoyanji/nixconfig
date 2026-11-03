-- HTTP GET
-- The digest tier, for the weekly summary: newsletters and marketing are stored
-- and searchable, and this is the only surface that reads them as a batch
-- instead of one search at a time.
select
  e.message_id,
  e.sender,
  e.subject,
  e.sent_at
from emails e
join lateral (
  select *
  from email_triage x
  where x.message_id = e.message_id
  order by x.decided_at desc
  limit 1
) t on true
where t.tier = 'digest'
  and e.sent_at >= now() - make_interval(days => :days::int)
order by e.sent_at desc nulls last
limit :lim;
