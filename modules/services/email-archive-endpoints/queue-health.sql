-- HTTP GET
-- Is the mail loop draining? One row, read by `services.fleetSentinel.queueProbe`
-- on the host that holds the archive, so a queue that stopped moving degrades
-- the host instead of being noticed the next time somebody runs `agents:hub`.
--
-- `unmatched_fresh` counts mail younger than 48 h that needs a person and that
-- no plugin owner claimed: a router that stopped matching shows up as new
-- attention mail owned by `none`. Digest and robot traffic does not count,
-- because nothing was supposed to claim it and a mailbox full of receipts is not
-- a broken router.
--
-- An absolute `newest_mail_age_h` cannot tell a quiet mailbox from a stalled
-- importer, so it ships with `prior_week_mails`: the volume of the week before
-- says which one it is.
with latest as (
  select distinct on (message_id)
    message_id,
    owner,
    tier,
    resolved_at
  from email_triage
  order by message_id, decided_at desc
),
open_rows as (
  select *
  from latest
  where resolved_at is null
    and tier <> 'ignore'
)
select
  (select count(*) from open_rows
    where tier = 'person' and owner not like 'agent:%')::int as open_person,
  (select count(*) from open_rows
    where tier = 'action' and owner not like 'agent:%')::int as open_action,
  (select count(*)
    from open_rows o
    join emails e on e.message_id = o.message_id
    where o.owner = 'none'
      and o.tier in ('person', 'action', 'review')
      and e.sent_at > now() - interval '48 hours')::int as unmatched_fresh,
  (select coalesce(round(extract(epoch from (now() - max(sent_at))) / 3600.0, 1), 0)::float
    from emails) as newest_mail_age_h,
  (select count(*)
    from emails
    where sent_at > now() - interval '8 days'
      and sent_at <= now() - interval '24 hours')::int as prior_week_mails;
