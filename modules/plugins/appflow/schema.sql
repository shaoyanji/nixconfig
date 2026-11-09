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

-- The career corpus: the prose a CV is built from, and the artifacts the site,
-- the packet and the gist read. The database is the source and the JSON Resume
-- files are exports (modules/plugins/appflow/README.md), so these tables carry
-- exactly the fields JSON Resume fixes and nothing the templates invent.
--
-- Two shapes, not one, because their join keys differ: a role is identified by
-- its employer, a translated project by the English project name (`resume_name`),
-- which is what `task matt:gist:drift` compares the German corpus on.
--
-- Lists are text, not jsonb: one highlight per line and one comma-separated
-- keyword, so the row is editable with psql and a heredoc, and a bullet that
-- contains a quote or a backslash is not a serializer's problem. NULL means the
-- field is absent from the artifact; an empty string means it is present and
-- empty. The export keeps that distinction, which is what makes a round trip
-- byte-comparable instead of merely similar.
CREATE TABLE IF NOT EXISTS career_role (
  id          text NOT NULL,
  language    text NOT NULL DEFAULT 'en',
  employer    text NOT NULL DEFAULT '',
  position    text NOT NULL DEFAULT '',
  location    text,
  url         text,
  start_date  text,
  end_date    text,
  description text,
  summary     text,
  highlights  text,
  keywords    text,
  sort        smallint NOT NULL DEFAULT 0,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, language)
);

CREATE INDEX IF NOT EXISTS career_role_order_idx
  ON career_role (language, sort);

CREATE TABLE IF NOT EXISTS career_project (
  id          text NOT NULL,
  language    text NOT NULL DEFAULT 'en',
  name        text NOT NULL DEFAULT '',
  resume_name text,
  entity      text,
  type        text,
  url         text,
  start_date  text,
  end_date    text,
  description text,
  highlights  text,
  keywords    text,
  roles       text,
  sort        smallint NOT NULL DEFAULT 0,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, language)
);

CREATE INDEX IF NOT EXISTS career_project_order_idx
  ON career_project (language, sort);

-- The portfolio: the sector projects the Bountystash capsule renders. Same rule
-- as the CV corpus — the rows are the source and `lib/bountystash/portfolio.json`
-- (plus its German copy) is an export — but a different vocabulary, so a
-- different table rather than a nullable half of `career_project`.
--
-- `source_title` is the German row's join key, the English title, for the same
-- reason `career_project.resume_name` exists: the capsule slugs a project by its
-- title, and a translation that renamed one would be a second project.
--
-- `links` is one `label<TAB>href` per line: an array of objects is JSON's shape,
-- not a row's, and the tab keeps a label that contains a colon or a slash intact.
CREATE TABLE IF NOT EXISTS portfolio_project (
  id           text NOT NULL,
  language     text NOT NULL DEFAULT 'en',
  title        text NOT NULL DEFAULT '',
  source_title text,
  role         text,
  period       text,
  badge        text,
  sector       smallint,
  description  text,
  stack        text,
  impact       text,
  highlights   text,
  link         text,
  links        text,
  featured     boolean,
  sort         smallint NOT NULL DEFAULT 0,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, language)
);

CREATE INDEX IF NOT EXISTS portfolio_project_order_idx
  ON portfolio_project (language, sort);
