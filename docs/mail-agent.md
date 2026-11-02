# mail-agent — natural-language mail actions on delphi

An autonomous-ish email manager: `mail-agent "archive all newsletters from last
week"` on delphi, with the intent routed by Needle 3 (121M params, CPU-only,
74 MB resident) and the action executed by the himalaya account the fleet already
has. A nightly timer sweeps bulk mail.

**One rule about model roles, because it decides the schemas.** Needle 3 is a
tool caller: it captures a sentence into a tool name plus typed arguments, and
that is the only job it gets here. A *classification* — one label out of a set,
with a threshold — is a different question and does not go to a tool-caller
model; it goes to a decision model (Jev, Laya, Julia-1) and, in this fleet's
policy, to a rule first. The mail sweep is the case that proved it: all three
models answer the keep/archive question at 3/10, so the sweep asks none of them.

The design was chosen after measuring the alternatives, not before. Everything
below was run on delphi against the live account on 2026-11-02.

## What is declarative, and what is not

| Layer | Home |
| :--- | :--- |
| module, options, timer, package | `modules/services/mail-agent.nix` |
| tool schema the model may call | `modules/services/mail-agent-tools.json` |
| harness | `modules/services/mail-agent.py` |
| engine + weights (one hash, shared) | `modules/scripts/needle-model.nix` |
| this host's trust list and limits | `hosts/delphi/configuration.nix` (`programs.mailAgent`) |

The secrets stay where they were: himalaya reads the account password from
`sops.secrets.gmail` at runtime, so nothing about mail auth is in this module.

## Tool assessment

The brief listed six candidates. Verdicts, with the reason each one carries
weight here:

| Candidate | Verdict | Why |
| :--- | :--- | :--- |
| **needle3** | **adopted** | Already packaged and running on delphi (`needle-router.nix`). 74 MB peak, ~250 decode tok/s, deterministic across runs, no network. |
| **neverest + pimdir** | **deferred** | A local mirror is the right answer *for a large corpus*. This inbox answers `envelope search` server-side in about a second, and Gmail's search is not rate-limited at this volume; a sync daemon plus a store would add a moving part before any measured need. Revisit past ~1k envelopes or if search latency bites. |
| **mxr** | rejected | Unpackaged (no Nix derivation), and its value — a queryable local index — is the same role neverest+pimdir already owns in this stack. Two indexes is one too many. |
| **mailbox-autopilot** | rejected as a service, **copied as a policy** | Python+uv CLI built for raw IMAP, overlapping the dispatch loop below. Its safety model — dry run by default, append-only audit, reversible actions only — is what this module implements. |
| **himalaya-mcp** | rejected | An MCP server means a Node runtime and a listening surface for a capability that a CLI plus a systemd timer already gives. Nothing in the fleet speaks MCP yet. |
| **himalaya 2.x** | **used as-is** | `envelope list/search --json`, `message move`, `flag add`. v2.2.1 with IMAP+Gmail. |

## Measured behaviour

**Routing.** `mail-agent --self-test` runs an eleven-sentence battery against the
shipped schema. Current result: **10/11**, with the miss being "what is the
weather tomorrow" → `search_mail` (read-only, returns nothing, and the CLI says
so). Tool descriptions decide this: verb-first, one sentence each lifted the
battery from 7/11 to 10/11. Two earlier findings shaped the harness:

- A `trash_mail` tool was **never selected** — "delete the spam from today" went
  to `mark_read` twice out of two. The capability was removed from the schema
  instead of being gated: with no delete tool, the model cannot delete.
- "send an email to matt" routed to `archive_mail` at 0.13. A deterministic
  guard now refuses send/reply/forward/compose **before** the model is asked.

**Confidence is not a safety gate.** Needle's confidence is the joint probability
of its own output, so it falls as the schema grows: the same phrase scored 0.10
with a `period` enum present and 0.33 without. It separates senders it knows
(0.05) from ones it doesn't (0.71 for "no tool needed"), but a fixed threshold
cannot tell a good `archive_mail` at 0.20 from a bad one at 0.36. So:
`--apply` is the human gate for commands, and the sweep uses a trust list.

**No model classifies mail, measured 2026-11-02.** A ten-item labelled battery
(four marketing newsletters, six must-keep: a security alert, an SSH-key notice,
a new-app notice, an order, a classifieds inquiry, a statement) was put to the
keep/archive question three ways. needle3's `sort_mail` tool called everything
archive but one at 0.12–0.34; `systemone-decision --type classify` (julia-1) and
laya each called nine of ten archive, and got Go City *wrong in the other
direction* at 0.71/0.84. **All three: 3/10.** needle3 is a tool caller, so asking
it for a label was a role error; the decision models are a lexical scorer on this
host, so the label was noise. Both schemas are gone and the sweep decides by
rule — the bulk-sender pattern, the `PROTECTED` subject guard, and the declared
sender allowlist, which was always the real gate:

| decision | owner | why |
| :--- | :--- | :--- |
| which tool, which arguments | needle3 (`mail-agent-tools.json`) | schema capture, 10/11 on the dispatch battery |
| keep or archive one message | rule: `BULK_*`, `PROTECTED`, `sweep.trustedSenders` | every model tested scored 3/10 |
| a label that genuinely needs judgement | Jev → Laya → Julia-1 (`decide`, `/v1/systemone`) | typed decision, one forward pass, calibrated |

Widening this is a schema edit plus a measurement, in that order: a label tool
comes back only with a battery it passes and a threshold that separates its own
correct calls from its incorrect ones.

**The sweep needed a trust list, not a better prompt.** A dry run over the real
inbox approved 13 messages, among them a Dropbox "you connected a new app", a
GitHub "a new SSH authentication key was added", a Stripe "unrecognized device
signed in" and a real Kleinanzeigen inquiry — at confidences 0.22–0.47, above any
threshold that still lets honest newsletters through. Instructions and blocklists
did not fix it; changing the default did. The sweep now archives **only** from
`sweep.trustedSenders`, and holds everything else with a printed reason:

```
sweep: scanned 60, bulk candidates 22, protected 21, approved 7, held 15
  ARCHIVE  2026-10-30  Go City     A Halloween treat for longer trips
  held     2026-11-01  Stripe      Unrecognized device signed in ...  sender not in sweep.trustedSenders
```

`sweep.mode` defaults to `report`; delphi sets `apply` with six marketing senders
that earned their place in a dry run.

## Shape of a run

```
himalaya envelope search -m inbox --json   ->  selector →  himalaya query
        ^                                                    ^
        |                                                    |
  mail-agent.py  --  needle3 --tools mail-agent-tools.json  --+
        |
        +-> dry run (default) | --apply  ->  message move / flag add  ->  audit.jsonl
```

- Read-only (`search_mail`) always executes: it changes nothing.
- Mutations are dry-run until `--apply`, and a call the router *suppressed* rather
  than emitted additionally needs `--force`.
- Every applied action appends `ts, mode, tool, args, query, moved[message-id],
  confidence` to `~/.local/state/mail-agent/audit.jsonl`. The `message-id` header
  is recorded, not the IMAP uid: Gmail reassigns uids per mailbox, so a uid is
  useless after a move (measured — the same message was 310172 in INBOX and 621165
  in All Mail).
- Archiving is a move to `[Gmail]/All Mail`. Gmail has no Archive folder;
  dropping the INBOX label *is* archiving. Restoring is the reverse move.

## Operating it

```bash
mail-agent "find mail from my bank"                    # read-only, runs
mail-agent "archive all newsletters from last week"    # prints the plan, changes nothing
mail-agent --apply "mark the newsletter as read"       # mutates
mail-agent --sweep                                     # what the timer would do tonight
mail-agent --self-test                                 # routing accuracy, no mail touched
systemctl --user list-timers 'mail-agent*'             # 06:30 daily
tail -f ~/.local/state/mail-agent/audit.jsonl
```

Add a sender to `sweep.trustedSenders` in `hosts/delphi/configuration.nix` after
watching it land in `held` for a few nights. With the list empty the sweep can
never archive anything — fail closed is the default.

Undo one message:

```bash
id=$(himalaya envelope search -m '[Gmail]/All Mail' --json -s 5 'subject "Halloween treat"' | jq -r '.envelopes[0].id')
himalaya message move -f '[Gmail]/All Mail' -t inbox "$id"
```

## Known edges

- **The model misroutes roughly one sentence in ten**, so `--apply` on a sentence
  the router merely *suppressed* is the risky path and asks for `--force` too.
- **`--limit` is what bounds a run.** The timer scans 25 envelopes and calls no
  model at all, so a sweep is one himalaya query plus moves.
- **No send, no reply, no delete.** If you want those, they are new tools and a
  new trust decision, not a flag.
- **`[Gmail]/All Mail` is Gmail-specific.** `archiveMailbox` and `inbox` are
  options; a non-Gmail account needs its own archive mailbox name.
