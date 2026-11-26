-- HTTP POST
-- Save or replace a named view. The name is the stable handle; replaying it is
-- a read of the current archive, so the same view changes as mail changes.
insert into saved_view (name, q, cat, box, sender, tier, pinned)
values (
  btrim(:name),
  coalesce(:q, ''),
  coalesce(:cat, ''),
  coalesce(nullif(:box, ''), 'inbox'),
  coalesce(:sender, ''),
  coalesce(:tier, ''),
  coalesce(:pinned, true)
)
on conflict (name) do update set
  q          = excluded.q,
  cat        = excluded.cat,
  box        = excluded.box,
  sender     = excluded.sender,
  tier       = excluded.tier,
  pinned     = excluded.pinned,
  updated_at = now()
returning id, name, q, cat, box, sender, tier, pinned, created_at, updated_at;
