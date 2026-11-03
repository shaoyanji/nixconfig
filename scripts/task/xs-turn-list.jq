# Render one page of xs turns for `task agents:xs:list`.
#
# Input: the shim's {"count": N, "events": [...]}. Subject is what resumability is
# keyed on, so liveness is decided per subject by its NEWEST entry: an older
# `in_progress` that a later `done` superseded is closed, not a live claim.
#
# Unresolved is not only in_progress. `blocked` is a decision waiting on a human
# and `failed` is a run that needs a second attempt, so a rule that counts only
# in_progress renders both as closed work and the operator's queue becomes
# invisible at exactly the moment an agent reads the log before starting.
#
# The last line is machine-only (`status<TAB>live|clear`); the script drops it from
# the display and turns it into the exit code, so the rule exists once.
def trim: gsub("^\\s+|\\s+$"; "");
def kind: (.outcome // "") | sub("\\s.*$"; "") | sub(":$"; "");
def verb:
  (kind) as $k
  | if $k == "blocked" then "is blocked on"
    elif $k == "failed" then "failed in"
    else "is in_progress on" end;
def advice:
  (kind) as $k
  | if $k == "blocked" then "waiting on a decision; read the note before starting"
    elif $k == "failed" then "failed and unresolved; read the note before retrying"
    else "stop and report the collision" end;
def areas: [$claim | splits(",") | trim | select(length > 0)];
def newest:
  reduce .[] as $e ({};
    if has($e.subject) then . else . + {($e.subject): $e} end);
def clips($n): if length > $n then .[0:$n] + "…" else . end;
# Either direction contains the other, so CLAIM=taskfiles/ matches a claim on
# taskfiles/agents.yml and a claim on `scripts/task` matches CLAIM=scripts/task/x.
def clashes($e; $a):
  [$e.claims[]?] as $cs
  | any($a[]; . as $x | any($cs[]; . as $k | ($k | contains($x)) or ($x | contains($k))));

(.events // []) as $ev
| (.count // ($ev | length)) as $total
| ($ev | newest | [.[]] | map(select(kind as $k | $k == "in_progress" or $k == "blocked" or $k == "failed"))) as $live
| areas as $a
| ($live | map(select(.subject == $subject))) as $same
| ($live | map(select(clashes(.; $a)))) as $clash
| (
    "turns \($ev | length) of \($total)"
      + (if $subject != "" then "  subject=\($subject)" else "" end)
      + (if $claim != "" then "  claim=\($claim)" else "" end)
  ),
  (
    $ev[]
    | "\(.ts[0:16])  \(.outcome)  \(.source)  \(.subject)"
      + (if (.claims // []) != [] then "\n    claims: \(.claims | join(", "))" else "" end)
      + (if (.action // "") != "" then "\n    \(.action | clips(160))" else "" end)
  ),
  (if $ev == [] then "  (nothing matches — widen REPO or drop SUBJECT)" else empty end),
  "== live claims (newest entry per subject is in_progress, blocked or failed)",
  (if $live == []
   then "  none"
   else ($live[] | "  \(.subject)  \(.source)  \(kind)  \(if kind == "in_progress" then (.action | clips(80)) else (.outcome | clips(100)) end)")
   end),
  "== verdict",
  (if $same != []
   then ($same[] | "LIVE  \(.source) \(verb) \(.subject) — \(advice)")
   elif $clash != []
   then ($clash[] | "LIVE  \(.source) claims \(.claims | join(", ")) and holds a live claim on \(.subject) — overlaps your CLAIM")
   elif $live != []
   then "note  live claims exist above; pass SUBJECT= or CLAIM= to test your own work (not an error here)"
   else "clear  nothing live for what was asked"
   end),
  (if ($same != [] or $clash != []) then "status\tlive" else "status\tclear" end)
