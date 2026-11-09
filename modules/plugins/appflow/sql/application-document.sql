-- HTTP GET
-- The text behind one application, one row per kind: what the job description
-- said, what a note outgrew. `body` comes back whole — a description is small,
-- and a client that has to make a second call for the thing it asked for will
-- stop asking.
select
  d.kind,
  d.body,
  d.source,
  d.sha256,
  d.updated_at
from application_document d
where d.application_id = :application_id
order by d.kind;
