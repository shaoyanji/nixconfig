-- HTTP POST
-- Remove one role from one language. A separate verb rather than a flag on the
-- upsert: deleting prose is the one write that a mistaken id cannot undo, and an
-- endpoint that only deletes is easy to leave out of a proxy allowlist.
delete from career_role
where id = :id and language = :language
returning id, language;
