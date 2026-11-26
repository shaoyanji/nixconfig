-- HTTP DELETE
-- Remove one saved view by id. This touches only operator state; no mail, tag,
-- triage verdict or box history is deleted with it.
delete from saved_view
where id = :id::bigint
returning id, name;
