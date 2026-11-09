-- HTTP GET
-- Every document's metadata without its body: what exists, how big it is, and
-- the digest the importer recorded. This is what the deletion gate reads to
-- answer "is the text in the database", and what a list view costs when the
-- bodies are megabytes apart.
select
  application_id,
  kind,
  -- Characters, not bytes: `length` counts characters, and a German description
  -- is mostly not ASCII. The digest is the byte-level identity.
  length(body) as chars,
  sha256,
  updated_at
from application_document
order by application_id, kind;
