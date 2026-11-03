-- HTTP POST
-- One classifier's verdict on one message. The body carries exactly six fields,
-- and a body missing one — or carrying an unknown one — is a 404 with no body,
-- not a 400, so a client always sends all of them. Field names are camelCased in
-- JSON (`messageId`), the same convention the responses use.
--
-- No comment line in this file may start with an annotation word: NpgsqlRest
-- parses `keys:` and friends out of comments and prefixed this response body
-- with the annotation instead of returning JSON.
--
-- A repeat keeps the row's `resolved_at`: re-classifying a CI notice an agent
-- already fixed must not put it back in the queue.
insert into email_triage (
  message_id,
  classifier,
  tier,
  owner,
  reason,
  confidence
)
values (
  :message_id,
  :classifier,
  :tier,
  :owner,
  nullif(:reason, ''),
  :confidence::real
)
on conflict (message_id, classifier) do update set
  tier       = excluded.tier,
  owner      = excluded.owner,
  reason     = excluded.reason,
  confidence = excluded.confidence,
  decided_at = now()
returning message_id, tier, owner;
