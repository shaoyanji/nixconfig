-- HTTP GET
-- The body of one archived message. The list and search endpoints deliberately
-- return `body_length` instead of the text, so an agent that needs to read a
-- message asks for it here, one message at a time.
select
  e.message_id,
  e.sender,
  e.subject,
  e.sent_at,
  e.body_plain,
  e.attachment_path
from emails e
where e.message_id = :message_id;
