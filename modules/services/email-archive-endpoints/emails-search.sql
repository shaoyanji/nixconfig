-- HTTP GET
-- Full-text search over the generated vector. `websearch_to_tsquery` accepts
-- what a person types (quotes, OR, -word) instead of requiring tsquery syntax.
-- The row cap is literal on purpose: with two bind parameters, ts_headline's
-- options argument breaks Npgsql's parameter naming (500: "empty string (key)").
select
  id,
  message_id,
  sender,
  subject,
  sent_at,
  attachment_path,
  ts_headline(
    'english',
    coalesce(body_plain, ''),
    websearch_to_tsquery('english', :q),
    'StartSel=<<, StopSel=>>, MaxWords=24, MinWords=8'
  ) as snippet
from emails
where search_vector @@ websearch_to_tsquery('english', :q)
order by sent_at desc nulls last, id desc
limit 50;
