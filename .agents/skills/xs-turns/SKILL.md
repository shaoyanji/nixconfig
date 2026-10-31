---
name: xs-turns
description: "Pick me before and after a turn that touches shared work: read the fleet turn log for a live claim, then post one resumable summary. Covers the token, the exact schema, subjects, reachability and the queue fallback."
version: 0.2.0
platforms: [linux]
metadata:
  hermes:
    tags: ['xs', 'agent-turns', 'coordination', 'delphi', 'tailnet', 'protocol']
    related_skills: ['agents', 'knowledge-base', 'prove-it-works']
---

# xs turns — read, then post one summary

The turn log is coordination state, not chat: one entry per agent turn, keyed by
`<repo>:<task-id>`, queryable before you start and after you land. It authorizes
nothing — a builder still does not merge unless a task says so.

Truth: `modules/services/agent-turns.nix`, `modules/services/agent-turns/shim.py`, `hosts/delphi/configuration.nix`; protocol and store in `docs/agent-turns.md`.

## Before a turn: pull, then read

```bash
cd "${NIXCONFIG:-$HOME/Documents/nixconfig}" && git pull --ff-only
X=https://delphi.cloudforest-kardashev.ts.net:8449
export AGENT_TURNS_TOKEN="$(sops -d modules/secrets.yaml | yq -r '.["agent-turns-token"]')"

curl -sS --max-time 10 -H "Authorization: Bearer $AGENT_TURNS_TOKEN" \
  "$X/v1/events?repo=nixconfig&limit=20" | jq -r '.events[] | "\(.ts) \(.source) \(.subject) [\(.outcome)]"'
curl -sS --max-time 10 -H "Authorization: Bearer $AGENT_TURNS_TOKEN" \
  "$X/v1/events?subject=nixconfig:<task-id>" | jq '.events'
```

Stop and report if another agent is `in_progress` on the same subject, or holds a
claim on files you are about to edit. `base_commit` should be the commit you
actually started from after the pull, not one you remembered.

**Never print the decrypted secrets file.** Read one key into a variable, as
above. Piping the whole file to `head`, `grep` or a diff puts unrelated values in
the transcript, and they cannot be retracted.

## After a turn: one JSON body, 201 means stored

Exactly these fields; the shim rejects unknown ones (that is what stops a
transcript being posted under an extra key):

| field | shape |
| :--- | :--- |
| `id` | client UUID, the dedup key |
| `ts` | RFC 3339 |
| `source` | agent name |
| `kind` | `"turn"` |
| `subject` | `<repo>:<task-id>`; the prefix before `:` is what `repo=` filters on |
| `action` | one line, ≤500 chars |
| `rationale` | string or `null`, ≤1000 chars — carry the diagnosis and the next step |
| `base_commit` | hash or `null` |
| `branch` | name or `null` |
| `files_changed` | list (exempt from the credential word scan) |
| `commits` | list of hashes |
| `claims` | list of areas or files |
| `outcome` | `done` \| `in_progress` \| `blocked: <one line>` \| `failed: <one line>` |

`task agents:xs:post` builds the body from `scripts/task/xs-turn.jq` — the
template is the schema — and posts it. You supply prose and never type JSON, and
the values cross as environment variables, so a quote, a backtick or a `$( )` in
a rationale stays literal. (Hand-built JSON is what kept breaking here: a stray
`'` inside a `jq --arg`.)

```bash
cd "${NIXCONFIG:-$HOME/Documents/nixconfig}"
task agents:xs:post \
  SUBJECT=nixconfig:<task-id> \
  ACTION='one line: what landed, and where' \
  RATIONALE='why it was needed, and the exact next step for whoever continues this' \
  OUTCOME=done \
  FILES='taskfiles/agents.yml,scripts/task/xs-turn.jq' \
  COMMITS='c75d2baa' \
  CLAIMS='taskfiles/agents.yml'
```

```
http      201
frame     03h5e0d5wc1gxp1ycyc2oaysa
client    712e6b6f-fe1e-48be-8496-62f1ee085740
subject   nixconfig:<task-id>
outcome   done
```

| var | default | |
| :--- | :--- | :--- |
| `SUBJECT` | required | `<repo>:<task-id>`; the half before `:` is what `repo=` filters on |
| `ACTION` | required | one line, ≤500 characters |
| `RATIONALE` | `""` | ≤1000; the diagnosis and the continuation belong here |
| `OUTCOME` | `done` | also `in_progress`, `blocked: why`, `failed: why` |
| `SOURCE` | `$USER` | short agent name |
| `FILES` `COMMITS` `CLAIMS` | `[]` | comma- or newline-separated |
| `ID` | a fresh UUID | pass the old one to retry; the shim dedups on it |
| `BASE_COMMIT` `BRANCH` | `git HEAD`, current branch | override when the work landed elsewhere |

What the template does that a hand-built body gets wrong: it fills `id`, `ts`,
`source` and `kind`, and renders `rationale`, `base_commit` and `branch` as real
`null` when empty rather than `""` — which the shim refuses on a hash.

- `201` = stored, and `frame` is the xs frame id.
- `200` = that UUID already exists; the post was a safe retry.
- `400` / `401` = rejected, nothing stored; the error line names the field or the
  token, never a value.
- transport failure (`4` when the script is run directly) leaves the body at
  `~/.local/state/agent-turns/last-turn.json`, which is exactly what the fallback
  below appends.
- There is **no update and no delete** (`405` by design). A correction is a new
  entry, not an edit.

## Subjects that can be resumed

One entry per topic beats one blob. A later agent retrieves
`?subject=pythonanywhere:resume-editor-pdf` and gets the diagnosis, the commits
and the sentence that says what is still open. A subject named after a session
("tuesday-work") retrieves nothing.

Put the continuation in `rationale` — the exact host-side step, the gate that has
not run yet, the verification that belongs to someone else. `outcome: done` with
no next step reads as closed, so say `in_progress` when it is.

## Retrieval

```bash
# newest first; limit 1-200 (default 50)
curl -sS -H "Authorization: Bearer $AGENT_TURNS_TOKEN" "$X/v1/events?repo=nixconfig&limit=20" | jq '.count, .events[0]'
curl -sS -H "Authorization: Bearer $AGENT_TURNS_TOKEN" "$X/v1/events?source=buffy" | jq -r '.events[].subject'
```

Events come back newest first with `_frame` added, which is the xs frame id for
cross-checking against `xs get` on delphi. `repo=`, `subject=`, `source=` and
`limit=` combine and are all filters on the same fixed schema.

## When the endpoint does not answer

Measured on 2026-10-30 from delphi itself:

| URL | Result |
| :--- | :--- |
| `https://delphi.cloudforest-kardashev.ts.net:8449` | works |
| `http://127.0.0.1:8449` | connection refused — the serve front is on the tailnet, not loopback |
| `https://<tailnet-ip>:8449` | TLS alert — the certificate is keyed to the DNS name, so use the name |

`curl -sS "$X/healthz"` needs no auth and answers `{"ok":true}` when the shim is
up; a `000` means transport, not auth. If the endpoint is still down: retry once,
then append the body the task already left on disk as one JSONL line —
`cat ~/.local/state/agent-turns/last-turn.json >> ~/.local/state/agent-turns/queue.jsonl`
— continue the turn, and replay when it answers. Replay is idempotent because the
UUID is the dedup key. Report the queue depth in the turn report.

## Rejections

| code | cause |
| :--- | :--- |
| `401` | missing or wrong bearer |
| `400` | unknown/missing field, bad UUID or timestamp, bad `outcome`, blocked/failed without its note, oversize (16 KiB body), credential-shaped free text, key material |
| `405` | update/delete — not a route |
| `000` | transport: check the URL and `--max-time` first, then the units on delphi |

Error bodies name the field, never the value. A `400` on `rationale` is usually
the word scan: an access key, a token or a URL with a password shape must not be
paraphrased into the log either.

## Durability

The store lives on delphi only and is dumped nightly to frieren
(`task infra:xs:export OUT=<dir>` on delphi, then the 03:28/03:30 restic
snapshots). Never delete `/var/lib/xs-agent-turns/store`; there is no second copy
until the next export.
