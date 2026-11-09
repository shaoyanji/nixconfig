-- HTTP GET
-- Every document's metadata without its body: what exists, how big it is, and
-- the digest the importer recorded. This is what the deletion gate reads to
-- answer "is the text in the database", and what a list view costs when the
-- bodies are megabytes apart.
select
  application_id,
  kind,
  length(body) as bytes,
  sha256,
  updated_at
from application_document
order by application_id, kind;
