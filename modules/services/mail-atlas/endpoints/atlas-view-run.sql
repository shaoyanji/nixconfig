-- HTTP GET
-- Replay one saved view. This is deliberately a separate read from
-- /api/atlas-search: the old route keeps its exact parameter contract, while a
-- saved view can carry sender and triage restrictions that the original search
-- grammar predates. Unknown view ids simply return no rows.
with view as (
  select * from saved_view where id = :id::bigint
), matched as (
  select
    e.id,
    e.message_id,
    e.thread_id,
    e.sender,
    e.subject,
    e.sent_at,
    e.attachment_path,
    length(coalesce(e.body_plain, '')) as body_length,
    coalesce(b.box, 'inbox') as box,
    case when v.q = '' then left(coalesce(e.body_plain, ''), 200)
         else ts_headline('english', coalesce(e.body_plain, ''), websearch_to_tsquery('english', v.q), 'StartSel=<<, StopSel=>>, MaxWords=26, MinWords=8')
    end as snippet,
    case when v.q = '' then 0 else ts_rank(e.search_vector, websearch_to_tsquery('english', v.q)) end as score
  from view v
  join emails e on true
  left join mail_box b on b.message_id = e.message_id
  where case v.box
          when 'all' then true
          when 'done' then coalesce(b.box, 'inbox') in ('archived', 'trashed', 'gone')
          else coalesce(b.box, 'inbox') = v.box
        end
    and (v.q = '' or e.search_vector @@ websearch_to_tsquery('english', v.q)
      or lower(coalesce(e.subject, '')) like '%' || lower(v.q) || '%'
      or lower(coalesce(e.sender, '')) like '%' || lower(v.q) || '%')
    and (v.cat = '' or exists (
      select 1 from email_tag et join mail_tag t on t.id = et.tag
      where et.message_id = e.message_id and t.category = v.cat
    ))
    and (v.sender = '' or lower(coalesce(e.sender, '')) like '%' || lower(v.sender) || '%')
    and (v.tier = '' or exists (
      select 1 from email_triage tr
      where tr.message_id = e.message_id and tr.tier = v.tier and tr.resolved_at is null
    ))
)
select
  m.id,
  m.message_id,
  m.thread_id,
  m.sender,
  m.subject,
  m.sent_at,
  m.attachment_path,
  m.body_length,
  m.box,
  m.snippet,
  m.score,
  coalesce((select json_agg(et.tag order by et.tag) from email_tag et where et.message_id = m.message_id), '[]'::json) as tags,
  coalesce((select array_agg(distinct t.category) from email_tag et join mail_tag t on t.id = et.tag where et.message_id = m.message_id), '{}'::text[]) as categories
from matched m
order by case when (select q from view) = '' then 0 else 1 end, m.score desc, m.sent_at desc nulls last, m.id desc
offset greatest(coalesce(:off, 0), 0)
limit :lim;
