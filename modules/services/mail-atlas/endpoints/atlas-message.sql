-- HTTP GET
-- One message in full, by row id. The search endpoint ships a snippet and a
-- body length, never the whole text: a result list that carried 2000 bodies
-- would be a megabyte per keystroke.
select
  e.id,
  e.message_id,
  e.sender,
  e.recipients,
  e.subject,
  e.sent_at,
  e.body_plain,
  e.attachment_path,
  coalesce((select b.box from mail_box b where b.message_id = e.message_id), 'inbox') as box,
  coalesce(
    (select json_agg(et.tag order by et.tag)
     from email_tag et where et.message_id = e.message_id),
    '[]'::json
  ) as tags,
  -- How the letter got to its box: the trail is short by nature, and the reader
  -- shows it under the sender so "archived" is never an unlabelled verdict.
  coalesce(
    (select json_agg(
       json_build_object('box', ev.box, 'fromBox', ev.from_box, 'reason', ev.reason, 'at', ev.at)
       order by ev.at asc
     )
     from (select * from mail_box_event x where x.message_id = e.message_id order by x.at desc, x.id desc limit 8) ev),
    '[]'::json
  ) as box_history,
  -- The dialog needs the decisions already taken on this message, so a second
  -- visit shows "queued for Hermes" instead of offering the same button again.
  coalesce(
    (select json_agg(
       json_build_object(
         'kind', a.kind,
         'status', a.status,
         'instruction', a.instruction,
         'requestedAt', a.requested_at
       ) order by a.kind
     )
     from mail_action a where a.message_id = e.message_id),
    '[]'::json
  ) as actions
from emails e
where e.id = :id;
