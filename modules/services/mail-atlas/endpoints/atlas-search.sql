-- HTTP GET
-- Fuzzy finding over the archive: one query that is a full-text match, a
-- substring hit and a trigram near-miss at once, so "invoce" still finds the
-- invoice and "kleinanzeig" still finds the marketplace.
--
-- Parameters are all required (`q`, `cat`, `box`, `off`, `lim`): NpgsqlRest never
-- registers a defaulted parameter, and an unregistered one is a 404. An empty
-- `q` is legal and means "the newest mail"; an empty `cat` means every category.
--
-- `box` is the working set, not a Gmail label: `inbox` (the default, and what a
-- decision removes a letter from), `queued` (asked for, not yet executed),
-- `done` (archived, trashed or gone by other means) and `all`.
--
-- `score` mixes the three signals rather than picking one, because they measure
-- different things: ts_rank ranks the body, similarity measures the subject and
-- sender against the typed string, and tag similarity routes a query to the
-- taxonomy before it ever reaches a body.
-- An empty query-string value arrives as NULL, not as '': `coalesce` is what
-- makes `?cat=` mean "every category" instead of "match nothing".
with needle as (
  select lower(btrim(coalesce(:q, ''))) as q, coalesce(:cat, '') as cat
),
tag_sim as (
  select et.message_id, max(similarity(t.id, n.q)) as sim
  from email_tag et
  join mail_tag t on t.id = et.tag
  cross join needle n
  where n.q <> ''
  group by et.message_id
),
matched as (
  select
    e.id,
    e.message_id,
    e.sender,
    e.subject,
    e.sent_at,
    e.attachment_path,
    length(coalesce(e.body_plain, '')) as body_length,
    coalesce(b.box, 'inbox') as box,
    last_move.at as box_changed_at,
    last_move.reason as box_reason,
    case when n.q = '' then 0
         else ts_rank(e.search_vector, websearch_to_tsquery('english', n.q))
    end as fts,
    case when n.q = '' then 0
         else greatest(
           similarity(lower(coalesce(e.subject, '')), n.q),
           similarity(lower(coalesce(e.sender, '')), n.q)
         )
    end as sim,
    case when n.q = '' then left(coalesce(e.body_plain, ''), 200)
         else ts_headline(
           'english',
           coalesce(e.body_plain, ''),
           websearch_to_tsquery('english', n.q),
           'StartSel=<<, StopSel=>>, MaxWords=26, MinWords=8'
         )
    end as snippet
  from emails e
  left join mail_box b on b.message_id = e.message_id
  -- The last line of the box trail, so a handled row can say what was done to it
  -- and when: `box` is where it is, this is why.
  left join lateral (
    select ev.at, ev.reason
    from mail_box_event ev
    where ev.message_id = e.message_id
    order by ev.at desc, ev.id desc
    limit 1
  ) last_move on true
  cross join needle n
  where case coalesce(:box, 'inbox')
          when 'all' then true
          when 'done' then coalesce(b.box, 'inbox') in ('archived', 'trashed', 'gone')
          else coalesce(b.box, 'inbox') = coalesce(:box, 'inbox')
        end
    and (
      n.q = ''
      or e.search_vector @@ websearch_to_tsquery('english', n.q)
      or lower(coalesce(e.subject, '')) like '%' || n.q || '%'
      or lower(coalesce(e.sender, '')) like '%' || n.q || '%'
      or similarity(lower(coalesce(e.subject, '')), n.q) > 0.28
      or exists (
        select 1 from tag_sim ts
        where ts.message_id = e.message_id and ts.sim > 0.42
      )
    )
    and (
      n.cat = ''
      or exists (
        select 1
        from email_tag et
        join mail_tag t on t.id = et.tag
        where et.message_id = e.message_id and t.category = n.cat
      )
    )
)
select
  m.id,
  m.message_id,
  m.sender,
  m.subject,
  m.sent_at,
  m.attachment_path,
  m.body_length,
  m.box,
  m.box_changed_at,
  m.box_reason,
  m.snippet,
  (3 * m.fts + 2 * m.sim + coalesce(ts.sim, 0) * 1.5) as score,
  coalesce(
    (select json_agg(et.tag order by et.tag)
     from email_tag et where et.message_id = m.message_id),
    '[]'::json
  ) as tags,
  coalesce(
    (select array_agg(distinct t.category)
     from email_tag et join mail_tag t on t.id = et.tag
     where et.message_id = m.message_id),
    '{}'::text[]
  ) as categories
from matched m
left join tag_sim ts on ts.message_id = m.message_id
order by score desc, m.sent_at desc nulls last, m.id desc
offset :off
limit :lim;
