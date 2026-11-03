-- HTTP GET
-- One application, every column the workflow needs to draft a packet or a
-- follow-up, plus how much mail is behind it. This is the read that replaces
-- loading `applications.json` into memory.
select
  a.id,
  a.company,
  a.role,
  a.category,
  a.language,
  a.fit,
  a.status,
  a.stage,
  a.next_action,
  a.apply_url,
  a.cover_letter_url,
  a.resume_url,
  a.gmail,
  a.review_flag,
  a.notes,
  a.folder_path,
  a.message_id,
  a.recruiter_email,
  a.created_at,
  a.updated_at,
  (select count(*) from application_mail am where am.application_id = a.id) as linked_mail
from applications a
where a.id = :id;
