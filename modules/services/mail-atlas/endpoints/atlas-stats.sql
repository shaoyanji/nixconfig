-- HTTP GET
-- The numbers the header shows. Distinct messages everywhere: "letters" is what
-- a person means, and an association count would be a different (larger) fact
-- wearing the same word.
--
-- `inbox` is the working set (nothing decided yet) and `queued` is what has been
-- asked for but not executed — the two numbers that matter while clearing mail.
select
  (select count(*) from emails)::int as letters,
  (select count(*) from mail_tag)::int as tags,
  (select count(distinct message_id) from email_tag)::int as tagged,
  (select count(*) from email_tag)::int as associations,
  (select max(sent_at) from emails) as newest,
  (
    select count(*)
    from emails e
    left join mail_box b on b.message_id = e.message_id
    where coalesce(b.box, 'inbox') = 'inbox'
  )::int as inbox,
  (select count(*) from mail_box where box = 'queued')::int as queued,
  (
    select count(*) from mail_command where status = 'pending'
  )::int as commands,
  -- A queue that stopped draining and an empty queue look identical in a
  -- count. The age is what tells them apart, so the header can say "3h"
  -- instead of a reassuring zero.
  (
    select coalesce(extract(epoch from now() - min(requested_at)) / 60, 0)::int
    from mail_action
    where status = 'pending'
  ) as oldest_pending_min,
  (
    select coalesce(extract(epoch from now() - min(changed_at)) / 60, 0)::int
    from mail_box
    where box = 'queued'
  ) as oldest_queued_min;
