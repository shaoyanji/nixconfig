-- HTTP GET
-- Fuzzy tag completion: what a typed prefix or a misspelling could mean, ranked
-- by how close it is and then by how much mail it holds. The search box calls
-- this as you type; a tag with no mail is never suggested over one with mail.
select
  t.id,
  t.label,
  t.category,
  c.glyph,
  count(et.message_id)::int as mail_count,
  similarity(t.id, lower(:q)) as score
from mail_tag t
join mail_category c on c.id = t.category
left join email_tag et on et.tag = t.id
where t.id like '%' || lower(:q) || '%'
   or similarity(t.id, lower(:q)) > 0.25
group by t.id, t.label, t.category, c.glyph, t.id, lower(:q)
order by score desc, mail_count desc, t.id
limit :lim;
