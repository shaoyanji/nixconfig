-- HTTP GET
-- Saved operator views, pinned first and then by name. These are replayable
-- filter combinations, not folders: saving one never moves or reclassifies mail.
select
  v.id,
  v.name,
  v.q,
  v.cat,
  v.box,
  v.sender,
  v.tier,
  v.pinned,
  v.created_at,
  v.updated_at
from saved_view v
order by v.pinned desc, lower(v.name), v.id
limit :lim;
