-- HTTP GET
-- Which applications a message is linked to. The reverse of
-- /api/application-mail: the pipeline sync needs to know what a message is
-- about, and `matched_by` says how sure the link is.
select
  a.id,
  a.company,
  a.role,
  a.stage,
  a.status,
  a.next_action,
  am.matched_by,
  am.confidence
from application_mail am
join applications a on a.id = am.application_id
where am.message_id = :message_id
order by am.confidence desc, a.updated_at desc nulls last;
