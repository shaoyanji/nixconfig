-- HTTP POST
-- Store one role. The body must carry every parameter below (a missing key is a
-- 404, as with `application-upsert`), and `null` is the meaningful value for a
-- field the artifact does not have.
--
-- `sort` is the row's place in the CV. A client that appends sends null and the
-- row lands after the last one in its language; a client that edits sends the
-- number it read, so an edit cannot reorder the document by accident.
insert into career_role (
  id, language, employer, position, location, url,
  start_date, end_date, description, summary, highlights, keywords, sort
)
values (
  :id,
  coalesce(nullif(:language, ''), 'en'),
  coalesce(:employer, ''),
  coalesce(:position, ''),
  :location,
  :url,
  :start_date,
  :end_date,
  :description,
  :summary,
  :highlights,
  :keywords,
  coalesce(:sort::int, (
    select coalesce(max(sort), -1) + 1
    from career_role
    where language = coalesce(nullif(:language, ''), 'en')
  ))
)
on conflict (id, language) do update set
  employer   = excluded.employer,
  position   = excluded.position,
  location   = excluded.location,
  url        = excluded.url,
  start_date  = excluded.start_date,
  end_date    = excluded.end_date,
  description = excluded.description,
  summary     = excluded.summary,
  highlights = excluded.highlights,
  keywords   = excluded.keywords,
  sort       = coalesce(:sort::int, career_role.sort),
  updated_at = now()
returning id, language, sort, updated_at;
