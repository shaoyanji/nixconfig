-- HTTP GET
-- Every archived letter and the box it is in, as one flat list. This exists for
-- the reconcile, which has to compare the whole archive against the mailbox in
-- one pass: the search endpoint is a ranked page of one box, not an index, and
-- asking it 40 times to enumerate the archive is how a reconcile takes minutes.
--
-- A letter with no row in `mail_box` is in the inbox by default, so the default
-- is written here rather than materialised for 2000 rows.
select
  e.message_id,
  coalesce(b.box, 'inbox') as box
from emails e
left join mail_box b on b.message_id = e.message_id
order by e.id
limit 20000;
