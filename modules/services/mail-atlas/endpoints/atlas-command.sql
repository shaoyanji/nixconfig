-- HTTP POST
-- A command about the mailbox as a whole, in the person's own words: "every
-- newsletter older than a month goes", "unsubscribe from the ATS senders". The
-- row is a request like a per-letter decision, read by an agent and closed with
-- a result; nothing here runs himalaya.
insert into mail_command (instruction)
values (btrim(:instruction))
returning id, instruction, status, requested_at;
