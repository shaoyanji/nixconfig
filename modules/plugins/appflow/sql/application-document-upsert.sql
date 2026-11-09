-- HTTP POST
-- Store or replace one text document for an application. The body must carry
-- every parameter below (a missing key is a 404, as with `application-upsert`),
-- so a client sends empty strings rather than omitting a field.
--
-- The upsert is the whole import: a re-run with the same text changes
-- `updated_at` and nothing else, and a changed text replaces the body in place —
-- there is no second file to reconcile and no history of drafts to age out.
insert into application_document (application_id, kind, body, source, sha256)
values (
  :application_id,
  :kind,
  :body,
  coalesce(:source, ''),
  coalesce(:sha256, '')
)
on conflict (application_id, kind) do update set
  body       = excluded.body,
  source     = excluded.source,
  sha256     = excluded.sha256,
  updated_at = now()
returning kind, sha256, length(body) as bytes, updated_at;
