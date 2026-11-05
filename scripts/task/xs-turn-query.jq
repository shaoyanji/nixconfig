# The xs read model: one filter, one ranking, one verdict, for every renderer.
#
# Input: the shim's {"count","scanned","truncated","events":[...]}. Args: $repo,
# $subject, $source, $q, $id, $claim, $display, $cutoff, $staleDays, $liveonly.
#
# Why this file exists: the ledger this replaces was greppable, and the turn log
# was not — `agents:xs:list` printed raw events, so finding "what happened to
# tika" meant reading fifty 1 KB rationales. Q= is the grep: every whitespace
# token must appear somewhere in the turn (AND), fields are weighted so a subject
# hit outranks a mention inside a rationale, and each row carries the field that
# matched plus a window around it.
#
# Liveness is the rule the shim cannot know and this file states once: the NEWEST
# entry per subject decides, and an unresolved entry (in_progress | blocked |
# failed) older than $cutoff is stale — printed, but not a failed check, because
# an agent that died mid-turn must not red the gate forever.

def trim: gsub("^\\s+|\\s+$"; "");
def kind: (.outcome // "") | sub("\\s.*$"; "") | sub(":$"; "");
def verb:
  (kind) as $k
  | if $k == "blocked" then "is blocked on"
    elif $k == "failed" then "failed in"
    else "is in_progress on" end;
def advice:
  (kind) as $k
  | if $k == "blocked" then "waiting on a decision; read the turn before starting"
    elif $k == "failed" then "failed and unresolved; read the turn before retrying"
    else "stop and report the collision" end;
def clips($n): if length > $n then .[0:$n] + "…" else . end;
def fresh: (.ts[0:19] >= ($cutoff[0:19]));
def areas: [$claim | splits(",") | trim | select(length > 0)];
# Either direction contains the other, so CLAIM=taskfiles/ matches a claim on
# taskfiles/agents.yml and a claim on `scripts/task` matches CLAIM=scripts/task/x.
def clashes($e; $a):
  [$e.claims[]?] as $cs
  | any($a[]; . as $x | any($cs[]; . as $k | ($k | contains($x)) or ($x | contains($k))));

def files: (.files_changed // []);
def words: [$q | ascii_downcase | splits("\\s+") | select(length > 0)];

# [weight, field, text] — the order here is also the snippet preference.
def weighted:
  [
    [3, "subject", (.subject // "")],
    [2, "action", (.action // "")],
    [2, "claims", ((.claims // []) | join(" "))],
    [2, "files", (files | join(" "))],
    [1, "outcome", (.outcome // "")],
    [1, "rationale", (.rationale // "")],
    [1, "source", (.source // "")]
  ];
def haystack: [weighted[][2]] | join(" ") | ascii_downcase;

# `any(gen; cond)` evaluates cond with `.` bound to the gen item, so the haystack
# must be bound by name — writing `$v | ascii_downcase | any($tokens[]; contains(.))`
# compares each token with itself and is true for every field.
def mentions($v; $tokens): ($v | ascii_downcase) as $h | any($tokens[]; . as $t | $h | contains($t));
# A snippet that starts mid-word reads as corruption, so both edges are moved to
# the nearest space before the ellipsis is added.
def window($text; $needle; $w):
  ($text | ascii_downcase | index($needle)) as $i
  | ($text | length) as $n
  | if $i == null then ($text | clips($w * 2))
    else
      ([$i - $w, 0] | max) as $s0
      | (if $s0 == 0 then 0 else (($text[0:$s0] | indices(" ") | .[-1] // -1) + 1) end) as $s
      | ([$i + $w, $n] | min) as $e0
      | (if $e0 >= $n then $n else (($text[0:$e0] | indices(" ") | .[-1]) // $e0) end) as $e
      | (if $s > 0 then "…" else "" end)
      + $text[$s:$e]
      + (if $e < $n then "…" else "" end)
    end;
def snippet($tokens):
  (weighted | map(select(. as [$w, $f, $v] | mentions($v; $tokens)))) as $hit
  | if $hit == [] then ""
    else
      ($hit[0]) as [$w, $f, $v]
      | ($v | ascii_downcase) as $h
      | ($tokens | map(. as $t | select($h | contains($t))) | first) as $t
      | window($v; $t; 70)
    end;
def hitfields($tokens):
  [weighted[] | . as [$w, $f, $v] | select(mentions($v; $tokens)) | $f]
  | unique | join(",");
def score($tokens):
  [weighted[] | . as [$w, $f, $v] | if mentions($v; $tokens) then $w else 0 end]
  | add // 0;

def matches($tokens; $id):
  (($tokens | length) == 0 or ((haystack) as $h | all($tokens[]; . as $t | $h | contains($t))))
  and (($id == "") or (._frame // "" | startswith($id)) or ((.id // "") | startswith($id)));

(.events // []) as $ev
| (.count // ($ev | length)) as $total
| words as $tokens
| areas as $a
| ($ev | reduce .[] as $e ({}; if has($e.subject) then . else . + {($e.subject): $e} end) | [.[]] ) as $newest
| ($newest | map(select(kind as $k | $k == "in_progress" or $k == "blocked" or $k == "failed"))) as $open
| ($open | map(select(fresh))) as $live
| ($open | map(select(fresh | not))) as $stale
| ($ev | map(select(matches($tokens; $id)))) as $hits
# LIVE=1 is the open queue, so it is one row per subject (the newest unresolved
# turn), not every unresolved turn: an older in_progress a later entry carried
# forward is history, and printing it twice reads as two live claims.
| (if $liveonly == "1" then ($live | map(select(matches($tokens; $id)))) else $hits end) as $cand
| ($cand | map(. + {score: score($tokens)})) as $scored
| ($scored
   | sort_by(.score, .ts)
   | reverse
   | map({
       ts: (.ts[0:16]),
       src: (.source // ""),
       subj: (.subject // ""),
       out: (kind),
       act: ((.action // "") | clips(150)),
       claims: ((.claims // []) | join(",") | clips(80)),
       files: ((files | length)),
       id: ((._frame // .id // "") | tostring),
       hit: (if $tokens == [] then "" else hitfields($tokens) end),
       snip: (if $tokens == [] then "" else snippet($tokens) end)
     })) as $rows
| ($live | map(select(.subject == ($subject // "")))) as $same
| ($live | map(select(clashes(.; $a)))) as $clash
| {
    q: {repo: ($repo // ""), subject: ($subject // ""), source: ($source // ""), text: ($q // ""), id: ($id // ""), claim: ($claim // "")},
    scanned: (.scanned // 0),
    truncated: (.truncated // false),
    matched: ($rows | length),
    stored: $total,
    stale_days: ($staleDays | tonumber),
    turns: ($rows[0:$display]),
    live: ($live | map({ts: (.ts[0:16]), subj: .subject, src: .source, kind: (kind), text: ((.action // .outcome) | clips(110))})),
    stale: ($stale | map({ts: (.ts[0:16]), subj: .subject, src: .source, kind: (kind), text: ((.outcome) | clips(110))})),
    verdict: (
      if $same != []
      then {state: "live", text: ([ $same[] | "\(.source) \(verb) \(.subject) — \(advice)" ] | join(" · "))}
      elif $clash != []
      then {state: "live", text: ([ $clash[] | "\(.source) claims \(.claims | join(", ")) and holds a live claim on \(.subject) — overlaps your CLAIM" ] | join(" · "))}
      elif $stale != []
      then {state: "stale", text: ([ $stale[] | "\(.source) left \(.subject) unresolved; post an update on that subject rather than editing in parallel" ] | join(" · "))}
      elif $live != []
      then {state: "note", text: "live claims exist; pass SUBJECT= or CLAIM= to test your own work"}
      else {state: "clear", text: "nothing live for what was asked"}
      end)
  }
