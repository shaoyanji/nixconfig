-- HTTP POST
-- One message into the archive.
insert into emails (message_id, sender, subject, body_plain)
values (:message_id, :sender, :subject, :body_plain)
returning id, message_id;
