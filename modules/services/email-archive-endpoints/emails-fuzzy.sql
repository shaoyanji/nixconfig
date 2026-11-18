-- HTTP GET
-- Substring search for what the stemmer cannot answer: a fragment of an
-- address, a surname inside a domain, a code or a part number. `:q` is matched
-- as one literal string across the envelope and the body, newest first; the
-- word-by-word path is `emails-search` (docs/email-archive.md).
select
  e.id,
  e.message_id,
  e.sender,
  e.subject,
  e.sent_at,
  e.attachment_path,
  length(coalesce(e.body_plain, '')) as body_length
from emails e
where e.sender ilike '%' || :q || '%'
   or e.subject ilike '%' || :q || '%'
   or coalesce(e.body_plain, '') ilike '%' || :q || '%'
order by e.sent_at desc nulls last, e.id desc
limit 50;
