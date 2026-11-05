-- HTTP POST
-- Close a general command once it has been carried out (or refused), with one
-- line of what happened. The instruction is never rewritten.
update mail_command
set
  status    = :status,
  closed_at = now(),
  result    = nullif(:result, '')
where id = :id::bigint
returning id, instruction, status, closed_at, result;
