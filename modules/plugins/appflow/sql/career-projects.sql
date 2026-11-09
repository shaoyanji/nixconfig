-- HTTP GET
-- The projects beside the roles, in artifact order, both languages. `resume_name`
-- is the English name a translated row joins on; it is NULL on an English row,
-- which is why the export only writes `resumeName` when it is not.
select
  id,
  language,
  name,
  resume_name,
  entity,
  type,
  url,
  start_date,
  end_date,
  description,
  highlights,
  keywords,
  roles,
  sort,
  updated_at
from career_project
order by language, sort, id;
