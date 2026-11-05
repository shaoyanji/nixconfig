-- HTTP GET
-- The taxonomy as compiled data: every category with its glyph, its tags and how
-- many letters sit under it. The frontend renders its nav from this, so a
-- category exists in exactly one place (mail_category) and never in markup.
--
-- `mail_count` is DISTINCT messages, not tag associations: one letter carries
-- several tags, and summing the tag counts would report 2909 letters for a
-- mailbox of 2050.
select
  c.id,
  c.glyph,
  c.label,
  c.description,
  c.position,
  (
    select count(distinct et.message_id)::int
    from mail_tag t
    join email_tag et on et.tag = t.id
    where t.category = c.id
  ) as mail_count,
  coalesce(
    (
      select json_agg(
        json_build_object('id', k.tag, 'count', k.n)
        order by k.n desc, k.tag
      )
      from (
        select t.id as tag, count(et.message_id)::int as n
        from mail_tag t
        left join email_tag et on et.tag = t.id
        where t.category = c.id
        group by t.id
      ) k
    ),
    '[]'::json
  ) as tags
from mail_category c
order by c.position;
