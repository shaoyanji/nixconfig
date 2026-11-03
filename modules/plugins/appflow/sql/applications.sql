-- HTTP GET
-- The pipeline, newest activity first. `stage` is the coarse bucket; `status` is
-- the workflow's own freeform string, kept beside it so nothing is paraphrased.
select
  a.id,
  a.company,
  a.role,
  a.stage,
  a.status,
  a.fit,
  a.next_action,
  a.origin,
  a.updated_at,
  count(am.message_id) as linked_mail
from applications a
left join application_mail am on am.application_id = a.id
group by a.id
order by a.updated_at desc nulls last, a.id
limit :lim;
