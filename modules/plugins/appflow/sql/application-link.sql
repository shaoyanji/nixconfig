-- HTTP POST
-- Attach one message to one application. A repeat refreshes the evidence rather
-- than failing, and a link is never deleted here: an agent that changes its mind
-- writes a lower-confidence second link, so the history of the guess survives.
insert into application_mail (message_id, application_id, matched_by, confidence)
values (:message_id, :application_id, :matched_by, :confidence::real)
on conflict (message_id, application_id) do update set
  matched_by = excluded.matched_by,
  confidence = excluded.confidence,
  linked_at  = now()
returning message_id, application_id, matched_by;
