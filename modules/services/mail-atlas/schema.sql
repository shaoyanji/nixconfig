-- mail-atlas: a taxonomy over the archive, so a message can be found by what it
-- is about rather than only by a word in its body.
--
-- Three tables, one contract:
--   mail_category  the fixed domains (ten of them; a human curates this list)
--   mail_tag       a findable subject within a category
--   mail_tag_rule  how a tag is recognised in a message (substring on a field)
--   email_tag      the association, keyed by message + tag + source, so two
--                  taggers can disagree and both verdicts stand
--
-- Every statement is idempotent: email-archive-db-init applies this on every
-- activation as the archive role. Rule seeds use ON CONFLICT DO NOTHING so a
-- local edit is never reverted by a rebuild, and a tag is never deleted by a
-- seed that stops matching it.

CREATE TABLE IF NOT EXISTS mail_category (
  id          text PRIMARY KEY,
  glyph       text NOT NULL,
  label       text NOT NULL,
  description text NOT NULL,
  position    int  NOT NULL DEFAULT 100
);

CREATE TABLE IF NOT EXISTS mail_tag (
  id       text PRIMARY KEY,
  category text NOT NULL REFERENCES mail_category (id) ON DELETE CASCADE,
  label    text NOT NULL
);

-- `pattern` is a LIKE pattern on the lowercased field, so '%kleinanzeigen%' is
-- a domain and '%run failed%' is a subject. `field = 'any'` concatenates all
-- three. weight is the confidence the rule carries into email_tag.
CREATE TABLE IF NOT EXISTS mail_tag_rule (
  id      serial PRIMARY KEY,
  field   text NOT NULL CHECK (field IN ('sender', 'subject', 'body', 'any')),
  pattern text NOT NULL,
  tag     text NOT NULL REFERENCES mail_tag (id) ON DELETE CASCADE,
  weight  real NOT NULL DEFAULT 1.0,
  UNIQUE (field, pattern, tag)
);

CREATE TABLE IF NOT EXISTS email_tag (
  message_id text NOT NULL REFERENCES emails (message_id) ON DELETE CASCADE,
  tag        text NOT NULL REFERENCES mail_tag (id) ON DELETE CASCADE,
  source     text NOT NULL DEFAULT 'rules',
  confidence real NOT NULL DEFAULT 1.0,
  tagged_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, tag, source)
);

-- Lookups run in both directions: "this message's tags" (by message_id, the
-- primary key's first column) and "everything under this tag".
CREATE INDEX IF NOT EXISTS email_tag_tag_idx ON email_tag (tag);

-- Trigram indexes make a misspelled query ("invoce", "kleinanzeig") resolve to
-- the field it meant instead of returning nothing. pg_trgm is created by the
-- db-init unit as postgres, before this file runs as the archive role.
CREATE INDEX IF NOT EXISTS emails_subject_trgm_idx
  ON emails USING GIN (lower(coalesce(subject, '')) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS emails_sender_trgm_idx
  ON emails USING GIN (lower(coalesce(sender, '')) gin_trgm_ops);

INSERT INTO mail_category (id, glyph, label, description, position) VALUES
  ('career',   '業', 'Career & Calling',  'Applications, recruiters, interviews — the working life.',      10),
  ('commerce', '商', 'Commerce',          'Orders, marketplaces, shipping, the exchange of things.',       20),
  ('finance',  '財', 'Finance',           'Invoices, receipts, banks, billing and statements.',            30),
  ('infra',    '器', 'Machinery',         'CI, repositories, alerts — the fleet talking to itself.',       40),
  ('security', '守', 'The Gate',          'Sign-ins, verification codes, security notices.',               50),
  ('media',    '文', 'Word & Signal',     'Newsletters, digests, publications, reading lists.',            60),
  ('social',   '人', 'People',            'A human writing to you, not a system.',                         70),
  ('travel',   '行', 'Wayfaring',         'Flights, bookings, tickets, places to be.',                     80),
  ('civic',    '公', 'The Commons',       'Institutions, government, education, community.',               90),
  ('records',  '錄', 'Records',           'Documents, attachments, the durable paper trail.',             100)
ON CONFLICT (id) DO NOTHING;

INSERT INTO mail_tag (id, category, label) VALUES
  ('job-application', 'career',   'Job application'),
  ('interview',       'career',   'Interview'),
  ('recruiter',       'career',   'Recruiter'),
  ('marketplace',     'commerce', 'Marketplace'),
  ('order',           'commerce', 'Order'),
  ('shipping',        'commerce', 'Shipping'),
  ('review-request',  'commerce', 'Review request'),
  ('receipt',         'finance',  'Receipt'),
  ('invoice',         'finance',  'Invoice'),
  ('billing',         'finance',  'Billing'),
  ('banking',         'finance',  'Banking'),
  ('ci-failure',      'infra',    'CI failure'),
  ('repository',      'infra',    'Repository'),
  ('monitoring',      'infra',    'Monitoring'),
  ('sign-in',         'security', 'Sign-in'),
  ('verification',    'security', 'Verification code'),
  ('security-alert',  'security', 'Security alert'),
  ('newsletter',      'media',    'Newsletter'),
  ('news',            'media',    'News'),
  ('reading-list',    'media',    'Reading list'),
  ('direct',          'social',   'Direct note'),
  ('invitation',      'social',   'Invitation'),
  ('travel',          'travel',   'Travel'),
  ('transit',         'travel',   'Transit'),
  ('institution',     'civic',    'Institution'),
  ('government',      'civic',    'Government'),
  ('community',       'civic',    'Community'),
  ('attachment',      'records',  'Attachment'),
  ('statement',       'records',  'Statement'),
  -- A handful of recurring sources, because "where it came from" is the tag a
  -- person reaches for when the subject line has long been forgotten.
  ('kleinanzeigen',   'commerce', 'Kleinanzeigen'),
  ('ebay',            'commerce', 'eBay'),
  ('amazon',          'commerce', 'Amazon'),
  ('github',          'infra',    'GitHub'),
  ('todoist',         'infra',    'Todoist'),
  ('supabase',        'infra',    'Supabase'),
  ('steam',           'media',    'Steam'),
  ('google',          'security', 'Google'),
  ('gmx',             'security', 'GMX'),
  ('nytimes',         'media',    'New York Times'),
  ('deutsche-welle',  'media',    'Deutsche Welle'),
  ('fidelity',        'finance',  'Fidelity'),
  ('stripe',          'finance',  'Stripe'),
  ('paypal',          'finance',  'PayPal')
ON CONFLICT (id) DO NOTHING;

INSERT INTO mail_tag_rule (field, pattern, tag, weight) VALUES
  -- career
  ('subject', '%bewerbung%',         'job-application', 1.0),
  ('subject', '%application%',       'job-application', 0.8),
  ('subject', '%resume%',            'job-application', 0.9),
  ('subject', '%received your resume%', 'job-application', 1.0),
  ('subject', '%interview%',         'interview',       1.0),
  ('subject', '%gespräch%',          'interview',       0.9),
  ('sender',  '%applytojob%',        'job-application', 1.0),
  ('sender',  '%greenhouse%',        'job-application', 1.0),
  ('sender',  '%lever.co%',          'job-application', 1.0),
  ('sender',  '%personio%',          'job-application', 1.0),
  ('sender',  '%join.com%',          'job-application', 1.0),
  ('sender',  '%softgarden%',        'job-application', 1.0),
  ('sender',  '%recruit%',           'recruiter',       0.9),
  ('sender',  '%talent%',            'recruiter',       0.7),
  -- commerce
  ('sender',  '%kleinanzeigen%',     'kleinanzeigen',   1.0),
  ('sender',  '%kleinanzeigen%',     'marketplace',     1.0),
  ('sender',  '%ebay%',              'ebay',            1.0),
  ('sender',  '%ebay%',              'marketplace',     1.0),
  ('sender',  '%amazon%',            'amazon',          1.0),
  ('sender',  '%immobilienscout%',   'marketplace',     1.0),
  ('sender',  '%vinted%',            'marketplace',     1.0),
  ('subject', '%nutzer-anfrage%',    'kleinanzeigen',   1.0),
  ('subject', '%anfrage zu deiner anzeige%', 'marketplace', 0.9),
  ('subject', '%bestellung%',        'order',           1.0),
  ('subject', '%your order%',        'order',           1.0),
  ('subject', '%order execution%',   'order',           0.7),
  ('subject', '%versandt%',          'shipping',        1.0),
  ('subject', '%shipped%',           'shipping',        1.0),
  ('subject', '%lieferung%',         'shipping',        0.9),
  ('sender',  '%dhl%',               'shipping',        1.0),
  ('sender',  '%dpd%',               'shipping',        1.0),
  ('sender',  '%hermes%',            'shipping',        0.9),
  ('subject', '%bewerten%',          'review-request',  1.0),
  ('subject', '%rate your%',         'review-request',  1.0),
  -- finance
  ('subject', '%receipt%',           'receipt',         1.0),
  ('subject', '%rechnung%',          'invoice',         1.0),
  ('subject', '%invoice%',           'invoice',         1.0),
  ('subject', '%quittung%',          'receipt',         1.0),
  ('subject', '%payment%',           'billing',         0.9),
  ('subject', '%zahlung%',           'billing',         0.9),
  ('subject', '%subscription%',      'billing',         0.9),
  ('subject', '%kontoauszug%',       'banking',         1.0),
  ('sender',  '%fidelity%',          'fidelity',        1.0),
  ('sender',  '%stripe%',            'stripe',          1.0),
  ('sender',  '%paypal%',            'paypal',          1.0),
  ('any',     '%kontoauszug%',       'statement',       0.9),
  -- infrastructure
  ('subject', '%run failed%',        'ci-failure',      1.0),
  ('subject', '%build failed%',      'ci-failure',      1.0),
  ('sender',  '%github.com%',        'github',          1.0),
  ('sender',  '%github.com%',        'repository',      1.0),
  ('sender',  '%gitlab%',            'repository',      1.0),
  ('sender',  '%codeberg%',          'repository',      1.0),
  ('sender',  '%todoist%',           'todoist',         1.0),
  ('sender',  '%supabase%',          'supabase',        1.0),
  ('sender',  '%gatus%',             'monitoring',      1.0),
  ('sender',  '%alerts@%',           'monitoring',      0.9),
  ('sender',  '%uptime%',            'monitoring',      1.0),
  -- security
  ('subject', '%sign in%',           'sign-in',         1.0),
  ('subject', '%signed in%',         'sign-in',         1.0),
  ('subject', '%logged in%',         'sign-in',         1.0),
  ('subject', '%new device%',        'sign-in',         1.0),
  ('subject', '%anmeldung%',         'sign-in',         0.9),
  ('subject', '%verification%',      'verification',    1.0),
  ('subject', '%bestätigungscode%',  'verification',    1.0),
  ('subject', '%security alert%',    'security-alert',  1.0),
  ('subject', '%sicherheitshinweis%','security-alert',  1.0),
  ('subject', '%password%',          'security-alert',  0.9),
  ('sender',  '%accounts.google%',   'google',          1.0),
  ('sender',  '%gmx%',               'gmx',             1.0),
  -- media
  ('subject', '%newsletter%',        'newsletter',      1.0),
  ('sender',  '%newsletter%',        'newsletter',      0.9),
  ('subject', '%digest%',            'newsletter',      0.8),
  ('subject', '%weekly%',            'newsletter',      0.6),
  ('sender',  '%nytimes%',           'nytimes',         1.0),
  ('sender',  '%nytimes%',           'news',            1.0),
  ('sender',  '%dw.com%',            'deutsche-welle',  1.0),
  ('sender',  '%dw.com%',            'news',            1.0),
  ('sender',  '%readwise%',          'reading-list',    1.0),
  ('sender',  '%steampowered%',      'steam',           1.0),
  ('subject', '%wishlist%',          'steam',           0.7),
  -- social
  ('subject', '%invitation%',        'invitation',      1.0),
  ('subject', '%einladung%',         'invitation',      0.9),
  ('subject', '%congratulations%',   'direct',          0.6),
  -- travel
  ('subject', '%flight%',            'travel',          1.0),
  ('subject', '%flug%',              'travel',          1.0),
  ('subject', '%booking%',           'travel',          0.9),
  ('subject', '%hotel%',             'travel',          0.9),
  ('subject', '%reise%',             'travel',          0.9),
  ('subject', '%ticket%',            'transit',         0.8),
  -- civic
  ('sender',  '%.edu%',              'institution',     1.0),
  ('sender',  '%university%',        'institution',     1.0),
  ('sender',  '%christenseninstitute%', 'institution',  1.0),
  ('sender',  '%.gov%',              'government',      1.0),
  ('subject', '%admissions%',        'institution',     0.9),
  ('subject', '%community%',         'community',       0.7),
  -- records
  ('subject', '%statement%',         'statement',       1.0)
ON CONFLICT (field, pattern, tag) DO NOTHING;

-- The tagger. Runs as the archive role from mail-atlas-tag.service, never
-- inside a request: a GET that mutates would make every search a write.
--
-- It tags messages that carry no rule verdict yet, newest first, bounded by
-- max_rows so a backfill is a run of the timer rather than one long transaction.
-- The `attachment` tag comes from the column, not the text: an attachment is a
-- fact about the row, not something a subject line mentions.
CREATE OR REPLACE FUNCTION mail_atlas_autotag(max_rows int DEFAULT 4000)
RETURNS int AS $$
DECLARE
  inserted int := 0;
  n int;
BEGIN
  WITH targets AS (
    SELECT e.message_id, e.sender, e.subject, e.body_plain
    FROM emails e
    WHERE NOT EXISTS (
      SELECT 1 FROM email_tag t
      WHERE t.message_id = e.message_id AND t.source = 'rules'
    )
    ORDER BY e.sent_at DESC NULLS LAST, e.id DESC
    LIMIT max_rows
  ), hits AS (
    SELECT DISTINCT t.message_id, r.tag, r.weight
    FROM targets t
    JOIN mail_tag_rule r ON
      (r.field = 'sender'  AND lower(coalesce(t.sender, ''))  LIKE r.pattern)
      OR (r.field = 'subject' AND lower(coalesce(t.subject, '')) LIKE r.pattern)
      OR (r.field = 'body'    AND lower(coalesce(t.body_plain, '')) LIKE r.pattern)
      OR (r.field = 'any'     AND lower(
            coalesce(t.sender, '') || ' ' || coalesce(t.subject, '') || ' ' ||
            coalesce(t.body_plain, '')
          ) LIKE r.pattern)
  )
  INSERT INTO email_tag (message_id, tag, source, confidence)
  SELECT message_id, tag, 'rules', max(weight)
  FROM hits
  GROUP BY message_id, tag
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS n = ROW_COUNT;
  inserted := inserted + n;

  INSERT INTO email_tag (message_id, tag, source, confidence)
  SELECT message_id, 'attachment', 'rules', 1.0
  FROM emails
  WHERE attachment_path IS NOT NULL
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS n = ROW_COUNT;
  inserted := inserted + n;

  RETURN inserted;
END;
$$ LANGUAGE plpgsql;

-- What a person decided about a message they just read: archive it, queue it for
-- deletion, or hand it to Hermes with an instruction in their own words.
--
-- These are REQUESTS, not effects. The archive never deletes mail — it is the
-- searchable record — and no browser is allowed to run himalaya. An agent that
-- owns the mailbox reads the pending rows (and `task agents:mail:atlas`) and
-- executes with its own gate, then closes the row with a result.
--
-- One row per (message, kind): asking twice updates the instruction instead of
-- queueing the same work twice, and a repeat after it was closed reopens it.
CREATE TABLE IF NOT EXISTS mail_action (
  id           bigserial PRIMARY KEY,
  message_id   text NOT NULL REFERENCES emails (message_id) ON DELETE CASCADE,
  kind         text NOT NULL CHECK (kind IN ('archive', 'delete', 'hermes')),
  instruction  text,
  requested_by text NOT NULL DEFAULT 'operator',
  requested_at timestamptz NOT NULL DEFAULT now(),
  status       text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'done', 'dismissed')),
  closed_at    timestamptz,
  result       text,
  UNIQUE (message_id, kind)
);

-- The queue read is "pending, oldest first, by kind"; a partial index keeps it
-- off the closed history, which is the part that grows.
CREATE INDEX IF NOT EXISTS mail_action_pending_idx
  ON mail_action (kind, requested_at)
  WHERE status = 'pending';

-- Where a letter sits in the working inbox, as far as this surface knows.
--
-- The mailbox is the authority for what exists; this is the authority for what
-- the atlas has already handled. Without it a batch decision is invisible until
-- the next import — which would never notice, because the archive keeps mail on
-- purpose. `inbox` is the working set, `queued` is asked-for and not yet done,
-- and everything else has left.
CREATE TABLE IF NOT EXISTS mail_box (
  message_id text PRIMARY KEY REFERENCES emails (message_id) ON DELETE CASCADE,
  box        text NOT NULL DEFAULT 'inbox'
    CHECK (box IN ('inbox', 'queued', 'archived', 'trashed', 'gone')),
  kind       text,
  changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS mail_box_box_idx ON mail_box (box);

-- Every move of a letter between boxes, append-only: `mail_box` says where it is
-- now, this says how it got there. A handled row can show what was done to it
-- and when without trusting `changed_at`, which the next write overwrites — and
-- the trail is what makes "archived by the drain" distinguishable from
-- "archived because it left the Gmail inbox".
CREATE TABLE IF NOT EXISTS mail_box_event (
  id         bigserial PRIMARY KEY,
  message_id text NOT NULL REFERENCES emails (message_id) ON DELETE CASCADE,
  from_box   text,
  box        text NOT NULL
    CHECK (box IN ('inbox', 'queued', 'archived', 'trashed', 'gone')),
  reason     text NOT NULL,
  at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS mail_box_event_message_idx
  ON mail_box_event (message_id, at DESC);

-- The trail starts where the record starts. Letters already in a box when this
-- table arrived get one event carrying `changed_at`, so a handled row can show
-- an age instead of waiting for the next move. `not exists` rather than a
-- constraint: a later activation must not restate history as if it had just
-- happened.
INSERT INTO mail_box_event (message_id, from_box, box, reason, at)
SELECT b.message_id, NULL, b.box, 'recorded', b.changed_at
FROM mail_box b
WHERE NOT EXISTS (
  SELECT 1 FROM mail_box_event ev WHERE ev.message_id = b.message_id
);

-- A command to Hermes about the mailbox rather than about one letter: "clear
-- every newsletter older than a month", "unsubscribe from the ATS senders". A
-- free sentence with no row behind it, so it cannot ride on mail_action.
CREATE TABLE IF NOT EXISTS mail_command (
  id           bigserial PRIMARY KEY,
  instruction  text NOT NULL CHECK (btrim(instruction) <> ''),
  requested_by text NOT NULL DEFAULT 'operator',
  requested_at timestamptz NOT NULL DEFAULT now(),
  status       text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'done', 'dismissed')),
  closed_at    timestamptz,
  result       text
);

CREATE INDEX IF NOT EXISTS mail_command_pending_idx
  ON mail_command (requested_at)
  WHERE status = 'pending';

-- Decisions that predate the box column still count: a message whose archive or
-- deletion was executed is not in the working inbox. `DO NOTHING` keeps this a
-- backfill — a later run must not overwrite what the drain has recorded since.
INSERT INTO mail_box (message_id, box, kind, changed_at)
SELECT
  a.message_id,
  CASE
    WHEN a.status = 'dismissed' THEN 'gone'
    WHEN a.kind = 'delete' THEN 'trashed'
    WHEN a.status = 'done' THEN 'archived'
    ELSE 'queued'
  END,
  a.kind,
  coalesce(a.closed_at, a.requested_at)
FROM mail_action a
ON CONFLICT (message_id) DO NOTHING;
