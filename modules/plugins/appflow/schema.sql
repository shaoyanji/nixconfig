-- The application pipeline, owned by the appflow plugin. Applied by the archive's
-- db-init after the core schema, on every activation, so every statement is
-- idempotent. docs: modules/plugins/appflow/README.md.

-- The job pipeline, in the same database as the mail it is driven by.
--
-- The shape is `data/supabase_migration.sql` from
-- shaoyanji/antigravity-application-workflow, kept close enough that the JSON the
-- workflow writes imports without a translation table, plus the two fields that
-- file only carries in the records: `message_id` and `recruiter_email`. `stage`
-- is derived at import from the same rules `task apps:overview` applies, so a
-- freeform status ("Applied (Ashby ATS 21.09.2026)") keeps its text AND sorts.
CREATE TABLE IF NOT EXISTS applications (
  id                text PRIMARY KEY,
  company           text NOT NULL,
  role              text NOT NULL,
  category          text NOT NULL DEFAULT 'other',
  language          text NOT NULL DEFAULT 'en',
  fit               smallint CHECK (fit BETWEEN 1 AND 5),
  status            text NOT NULL DEFAULT '',
  stage             text NOT NULL DEFAULT 'other',
  next_action       text,
  apply_url         text,
  cover_letter_url  text,
  resume_url        text,
  gmail             text,
  review_flag       text,
  notes             text,
  folder_path       text,
  message_id        text,
  recruiter_email   text,
  created_at        timestamptz,
  updated_at        timestamptz,
  imported_at       timestamptz NOT NULL DEFAULT now()
);

-- Where a row came from. `import` is the workflow's JSON; `discovered` is mail
-- that named an employer the pipeline did not track yet, which is how the
-- tracker hydrates itself. Re-applying the schema adds the column to a table
-- that already exists, which CREATE TABLE IF NOT EXISTS cannot do.
ALTER TABLE applications ADD COLUMN IF NOT EXISTS origin text NOT NULL DEFAULT 'import';

CREATE INDEX IF NOT EXISTS applications_stage_idx ON applications (stage);
CREATE INDEX IF NOT EXISTS applications_origin_idx ON applications (origin);
CREATE INDEX IF NOT EXISTS applications_company_idx ON applications (lower(company));

-- Mail about one application. Many-to-many with a confidence, because a
-- rejection and an interview invite can both concern the same job, and because
-- a company match is a guess until someone looks: the link never overwrites a
-- row and `matched_by` says which rule produced it.
CREATE TABLE IF NOT EXISTS application_mail (
  message_id     text NOT NULL REFERENCES emails (message_id) ON DELETE CASCADE,
  application_id text NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  matched_by     text NOT NULL,
  confidence     real,
  linked_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, application_id)
);

CREATE INDEX IF NOT EXISTS application_mail_app_idx
  ON application_mail (application_id);

-- The text behind one application: the job description it was written against, a
-- note that outgrew the row, a letter draft. `kind` is open on purpose, so a new
-- sort of text is a row and not a column, and (application, kind) is the key
-- because two files for the same text is exactly the problem this replaces.
--
-- `sha256` is the caller's digest of `body`. It makes a re-import a no-op at the
-- row level, and it lets a rebuild prove the text it started from — the file hash
-- of a 5% reproducible artifact workflow, without the file.
CREATE TABLE IF NOT EXISTS application_document (
  application_id text NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  kind           text NOT NULL,
  body           text NOT NULL,
  source         text NOT NULL DEFAULT '',
  sha256         text NOT NULL DEFAULT '',
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (application_id, kind)
);

CREATE INDEX IF NOT EXISTS application_document_kind_idx
  ON application_document (kind);
