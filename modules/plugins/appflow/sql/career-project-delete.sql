-- HTTP POST
-- Remove one project from one language, for the same reason the role delete is
-- its own endpoint.
delete from career_project
where id = :id and language = :language
returning id, language;
