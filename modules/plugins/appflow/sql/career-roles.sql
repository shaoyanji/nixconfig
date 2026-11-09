-- HTTP GET
-- The career corpus, in the order the CV prints it. Both languages come back in
-- one answer because the two corpora are one table and the reader filters: a
-- CV is 15 rows, so a second endpoint per language would be a mode to keep in
-- sync for no saving.
--
-- Lists are newline- and comma-separated text (see schema.sql); `NULL` means the
-- artifact has no such field, `''` that it has an empty one.
select
  id,
  language,
  employer,
  position,
  location,
  url,
  start_date,
  end_date,
  description,
  summary,
  highlights,
  keywords,
  sort,
  updated_at
from career_role
order by language, sort, id;
