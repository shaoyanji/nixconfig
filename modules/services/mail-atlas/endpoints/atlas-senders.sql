-- HTTP GET
-- Who writes to you, rolled up by the domain that sent it: the discovery question
-- in a mailbox you did not build yourself.
--
-- A flood from one source and a mailbox nobody has triaged look identical in a
-- letter list. `untagged` is the number that tells them apart, and `newest` is
-- what says a source has gone quiet rather than merely be quiet.
--
-- The domain comes from the address, never the display name, so `Stripe
-- <no-reply@stripe.com>` and `billing@stripe.com` are one shore. A sender with no
-- `@` keeps its whole string instead of becoming null and vanishing from the sum.
with extracted as (
  select
    e.message_id,
    e.sent_at,
    lower(nullif(split_part(
      regexp_replace(coalesce(e.sender, ''), '^.*<', ''),
      '>', 1
    ), '')) as address,
    exists (select 1 from email_tag et where et.message_id = e.message_id) as tagged
  from emails e
),
shored as (
  select
    message_id,
    sent_at,
    tagged,
    address,
    coalesce(nullif(split_part(address, '@', 2), ''), address) as domain
  from extracted
)
select
  domain,
  count(*)::int as letters,
  count(distinct address)::int as addresses,
  count(*) filter (where not tagged)::int as untagged,
  min(sent_at) as oldest,
  max(sent_at) as newest
from shored
where domain <> ''
  and (coalesce(:q, '') = '' or domain like '%' || lower(:q) || '%')
group by domain
order by letters desc, domain
limit :lim;
