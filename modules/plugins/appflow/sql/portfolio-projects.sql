-- HTTP GET
-- The portfolio projects, in page order, both languages. `source_title` is the
-- English title a translated row joins on and is NULL on an English row.
select
  id,
  language,
  title,
  source_title,
  role,
  period,
  badge,
  sector,
  description,
  stack,
  impact,
  highlights,
  link,
  links,
  featured,
  sort,
  updated_at
from portfolio_project
order by language, sort, id;
