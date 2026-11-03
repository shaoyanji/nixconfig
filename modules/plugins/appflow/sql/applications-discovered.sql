-- HTTP GET
-- Applications the mail hub found on its own: an employer the workflow's JSON did
-- not track, with the message that named it. Confirm one by running the import
-- with it, or leave it here — it is a record with provenance, not a guess about
-- someone else's data.
select
  a.id,
  a.company,
  a.role,
  a.stage,
  a.status,
  a.next_action,
  a.message_id,
  a.created_at,
  (select count(*) from application_mail am where am.application_id = a.id) as linked_mail
from applications a
where a.origin = 'discovered'
order by a.created_at desc nulls last
limit :lim;
