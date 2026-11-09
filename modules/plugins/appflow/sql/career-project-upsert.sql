-- HTTP POST
-- Store one project. Same rule as the role upsert: every parameter is sent,
-- `null` for a field the artifact omits, and `sort` null appends.
--
-- `resume_name` is set on a translated row only. It is the join key the drift
-- check uses (`task matt:gist:drift`), so a German project that does not name its
-- English counterpart is refused by that check rather than here.
insert into career_project (
  id, language, name, resume_name, entity, type, url,
  start_date, end_date, description, highlights, keywords, roles, sort
)
values (
  :id,
  coalesce(nullif(:language, ''), 'en'),
  coalesce(:name, ''),
  :resume_name,
  :entity,
  :type,
  :url,
  :start_date,
  :end_date,
  :description,
  :highlights,
  :keywords,
  :roles,
  coalesce(:sort::int, (
    select coalesce(max(sort), -1) + 1
    from career_project
    where language = coalesce(nullif(:language, ''), 'en')
  ))
)
on conflict (id, language) do update set
  name        = excluded.name,
  resume_name = excluded.resume_name,
  entity      = excluded.entity,
  type        = excluded.type,
  url         = excluded.url,
  start_date  = excluded.start_date,
  end_date    = excluded.end_date,
  description = excluded.description,
  highlights  = excluded.highlights,
  keywords    = excluded.keywords,
  roles       = excluded.roles,
  sort        = coalesce(:sort::int, career_project.sort),
  updated_at  = now()
returning id, language, sort, updated_at;
