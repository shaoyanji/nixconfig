-- HTTP POST
-- Store one project. Every parameter is sent (a missing key is a 404, as with
-- `application-upsert`); `null` is the value of a field the artifact omits, and
-- `sort` null appends within the language.
insert into portfolio_project (
  id, language, title, source_title, role, period, badge, sector,
  description, stack, impact, highlights, link, links, featured, sort
)
values (
  :id,
  coalesce(nullif(:language, ''), 'en'),
  coalesce(:title, ''),
  :source_title,
  :role,
  :period,
  :badge,
  :sector::smallint,
  :description,
  :stack,
  :impact,
  :highlights,
  :link,
  :links,
  :featured::boolean,
  coalesce(:sort::int, (
    select coalesce(max(sort), -1) + 1
    from portfolio_project
    where language = coalesce(nullif(:language, ''), 'en')
  ))
)
on conflict (id, language) do update set
  title        = excluded.title,
  source_title = excluded.source_title,
  role         = excluded.role,
  period       = excluded.period,
  badge        = excluded.badge,
  sector       = excluded.sector,
  description  = excluded.description,
  stack        = excluded.stack,
  impact       = excluded.impact,
  highlights   = excluded.highlights,
  link         = excluded.link,
  links        = excluded.links,
  featured     = excluded.featured,
  sort         = coalesce(:sort::int, portfolio_project.sort),
  updated_at   = now()
returning id, language, sort, updated_at;
