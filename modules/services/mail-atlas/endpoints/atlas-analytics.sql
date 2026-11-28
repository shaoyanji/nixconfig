-- HTTP GET
-- The atlas as aggregates rather than letters: sender domains, taxonomy tags,
-- triage verdicts, attachment shape and daily timeline buckets. `days=0` means
-- the whole archive; otherwise the window is measured from now. `lim` caps each
-- ranked breakdown while the timeline remains bounded at 180 buckets.
with windowed as (
  select e.*
  from emails e
  where coalesce(:days, 0) = 0
     or e.sent_at >= now() - make_interval(days => greatest(coalesce(:days, 0), 0))
), domains as (
  select coalesce(lower(nullif(split_part(split_part(regexp_replace(coalesce(sender, ''), '^.*<', ''), '>', 1), '@', 2), '')), 'unknown') as domain,
         count(*)::int as letters,
         count(attachment_path)::int as attachments
  from windowed
  group by 1
  order by letters desc, domain
  limit greatest(coalesce(:lim, 10), 1)
), tags as (
  select et.tag, count(distinct et.message_id)::int as letters
  from email_tag et
  join windowed e on e.message_id = et.message_id
  group by et.tag
  order by letters desc, et.tag
  limit greatest(coalesce(:lim, 10), 1)
), triage as (
  select tr.tier, tr.owner, count(*)::int as verdicts,
         count(*) filter (where tr.resolved_at is null)::int as open
  from email_triage tr
  join windowed e on e.message_id = tr.message_id
  group by tr.tier, tr.owner
  order by verdicts desc, tr.tier, tr.owner
  limit greatest(coalesce(:lim, 10), 1)
), timeline as (
  select date_trunc('day', coalesce(sent_at, now()))::date as day,
         count(*)::int as letters,
         count(attachment_path)::int as attachments
  from windowed
  group by 1
  order by 1 desc
  limit 180
), totals as (
  select count(*)::int as letters,
         count(distinct coalesce(nullif(thread_id, ''), message_id))::int as threads,
         count(attachment_path)::int as attachments,
         count(distinct sender)::int as senders
  from windowed
)
select
  greatest(coalesce(:days, 0), 0) as days,
  now() as generated_at,
  (select row_to_json(totals) from totals) as totals,
  coalesce((select json_agg(row_to_json(domains)) from domains), '[]'::json) as domains,
  coalesce((select json_agg(row_to_json(tags)) from tags), '[]'::json) as tags,
  coalesce((select json_agg(row_to_json(triage)) from triage), '[]'::json) as triage,
  coalesce((select json_agg(row_to_json(timeline)) from (select * from timeline order by day asc) timeline), '[]'::json) as timeline;
