-- HTTP POST
-- Mark a verdict resolved: `resolved_at` is the only writable column, so a
-- dispatch that fixes the run cannot accidentally re-tier the message. Returns
-- the row it changed, so a caller sees whether anything was open.
-- All classifiers' verdicts for the message resolve together: the mail is dealt
-- with, and a classifier that has not yet seen it starts from a clean state.
update email_triage
set resolved_at = now()
where message_id = :message_id
  and resolved_at is null
returning message_id, classifier, tier, owner, resolved_at;
