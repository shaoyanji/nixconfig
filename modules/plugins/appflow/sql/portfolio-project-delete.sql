-- HTTP POST
-- Remove one project from one language. Its own verb, like the career deletes,
-- so a proxy allowlist can publish the reads without publishing a delete.
delete from portfolio_project
where id = :id and language = :language
returning id, language;
