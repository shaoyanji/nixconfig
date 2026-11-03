-- HTTP GET
-- Search by employer, role, id or status. `websearch_to_tsquery` would need a
-- generated vector for three columns; a case-insensitive substring is what a
-- person types into `apps:search` and stays honest about what it matches.
select
  a.id,
  a.company,
  a.role,
  a.stage,
  a.status,
  a.next_action,
  a.updated_at
from applications a
where a.id ilike '%' || :q || '%'
   or a.company ilike '%' || :q || '%'
   or a.role ilike '%' || :q || '%'
   or a.status ilike '%' || :q || '%'
   or coalesce(a.notes, '') ilike '%' || :q || '%'
order by a.updated_at desc nulls last
limit :lim;
