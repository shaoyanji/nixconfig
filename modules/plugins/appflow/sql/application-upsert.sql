-- HTTP POST
-- One application record, as the workflow's `data/applications.json` carries it.
-- The body must carry every parameter below (a missing key is a 404), so a client
-- sends nulls rather than omitting fields.
--
-- `stage` is computed by the caller from the same rules `task apps:overview`
-- applies; the row keeps the verbatim `status` beside it so nothing is lost.
insert into applications (
  id, company, role, category, language, fit, status, stage,
  next_action, apply_url, cover_letter_url, resume_url, gmail, review_flag,
  notes, folder_path, message_id, recruiter_email, created_at, updated_at, origin
)
values (
  :id, :company, :role,
  coalesce(nullif(:category, ''), 'other'),
  coalesce(nullif(:language, ''), 'en'),
  :fit::smallint,
  coalesce(:status, ''),
  coalesce(nullif(:stage, ''), 'other'),
  nullif(:next_action, ''), nullif(:apply_url, ''),
  nullif(:cover_letter_url, ''), nullif(:resume_url, ''),
  nullif(:gmail, ''), nullif(:review_flag, ''), nullif(:notes, ''),
  nullif(:folder_path, ''), nullif(:message_id, ''),
  nullif(:recruiter_email, ''),
  nullif(:created_at, '')::timestamptz,
  nullif(:updated_at, '')::timestamptz,
  coalesce(nullif(:origin, ''), 'import')
)
on conflict (id) do update set
  company          = excluded.company,
  role             = excluded.role,
  category         = excluded.category,
  language         = excluded.language,
  fit              = excluded.fit,
  status           = excluded.status,
  stage            = excluded.stage,
  next_action      = excluded.next_action,
  apply_url        = excluded.apply_url,
  cover_letter_url = excluded.cover_letter_url,
  resume_url       = excluded.resume_url,
  gmail            = excluded.gmail,
  review_flag      = excluded.review_flag,
  notes            = excluded.notes,
  folder_path      = excluded.folder_path,
  message_id       = coalesce(excluded.message_id, applications.message_id),
  recruiter_email  = coalesce(excluded.recruiter_email, applications.recruiter_email),
  created_at       = coalesce(excluded.created_at, applications.created_at),
  updated_at       = coalesce(excluded.updated_at, applications.updated_at),
  -- A discovered row that the workflow later exported is confirmed, never the
  -- other way round: only an import may promote the origin.
  origin           = case
    when excluded.origin = 'import' then 'import'
    else applications.origin
  end,
  imported_at      = now()
returning id, company, stage;
