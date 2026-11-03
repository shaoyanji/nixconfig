-- HTTP GET
-- Every application, every column, in the shape `data/applications.json` uses.
-- This is the export direction of the sunset: the database is the writer, and the
-- JSON in the workflow repo is a generated artifact from here.
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
  a.updated_at
from applications a
order by a.id;
