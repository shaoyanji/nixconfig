# Render one page of xs turns for `task agents:xs:list`.
#
# Input: the shim's {"count": N, "events": [...]}. Subject is what resumability is
# keyed on, so liveness is decided per subject by its NEWEST entry: an older
# `in_progress` that a later `done` superseded is closed, not a live claim.
#
# The last line is machine-only (`status<TAB>live|clear`); the script drops it from
# the display and turns it into the exit code, so the rule exists once.
def trim: gsub("^\\s+|\\s+$"; "");
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
| ($ev | newest | [.[]] | map(select((.outcome // "") | startswith("in_progress")))) as $live
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
  "== live claims (newest entry per subject says in_progress)",
  (if $live == []
   then "  none"
   else ($live[] | "  \(.subject)  \(.source)  \(.action | clips(100))")
   end),
  "== verdict",
  (if $same != []
   then ($same[] | "LIVE  \(.source) is in_progress on \(.subject) — stop and report the collision")
   elif $clash != []
   then ($clash[] | "LIVE  \(.source) claims \(.claims | join(", ")) and holds a live claim on \(.subject) — overlaps your CLAIM")
   elif $live != []
   then "note  live claims exist above; pass SUBJECT= or CLAIM= to test your own work (not an error here)"
   else "clear  nothing live for what was asked"
   end),
  (if ($same != [] or $clash != []) then "status\tlive" else "status\tclear" end)
