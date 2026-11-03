-- HTTP POST
-- The write an agent needs to keep the pipeline current from mail: status, the
-- stage derived from it, and the next action. Nothing else is writable here —
-- a status change must not be able to rewrite the documents or the URLs.
--
-- `stage` is sent by the caller rather than derived, because the buckets are a
-- rule in `task apps:overview` and this database holds no copy of that rule.
update applications
set
  status      = :status,
  stage       = :stage,
  next_action = :next_action,
  updated_at  = now()
where id = :id
returning id, company, status, stage, next_action;
