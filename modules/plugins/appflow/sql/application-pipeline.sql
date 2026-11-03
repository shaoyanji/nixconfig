-- HTTP GET
-- Pipeline counts by stage, the same buckets `task apps:overview` prints, so the
-- database and the CLI cannot disagree about what the pipeline looks like.
select
  stage,
  count(*) as applications,
  count(*) filter (where (next_action is not null and next_action <> '')) as with_next_action
from applications
group by stage
order by applications desc;
