-- HTTP POST
-- One letter's box, set from outside a decision. The page writes boxes when a
-- person decides; the reconcile writes one when the mailbox itself has moved a
-- letter and the atlas did not know. `kind` is left alone — it records what was
-- asked for, not where the letter now is.
--
-- A write that changes nothing is not a move: the upsert is skipped when the box
-- already matches, so `changed_at` does not churn hourly on every letter the
-- reconcile looked at and agreed about, and the trail stays a list of changes.
with previous as (
  select coalesce((select b.box from mail_box b where b.message_id = :message_id), 'inbox') as box
),
upsert as (
  insert into mail_box (message_id, box, kind, changed_at)
  values (:message_id, :box, null, now())
  on conflict (message_id) do update set
    box        = excluded.box,
    changed_at = now()
  where mail_box.box is distinct from excluded.box
  returning message_id, box
),
evented as (
  insert into mail_box_event (message_id, from_box, box, reason)
  select u.message_id, p.box, u.box, coalesce(nullif(:reason, ''), 'reconcile')
  from upsert u
  cross join previous p
  returning 1
)
select
  :message_id as message_id,
  coalesce((select box from upsert), (select box from previous)) as box,
  (select count(*) from evented) as changed;
