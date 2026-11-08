# Agent turns: the xs coordination endpoint on delphi

An agent could only learn who was working on what from a chat report, which goes
stale the moment someone opens a branch. This endpoint is the replacement: one
small summary per agent turn, queryable by repo, subject and agent, so a claim
can be checked before work starts and a merge can be checked against the turns
that actually landed. It authorizes nothing — a builder still does not merge
unless a task says so.

Code: `modules/services/agent-turns.nix`, `modules/services/agent-turns/shim/` (Go).
Exposure: `hosts/delphi/configuration.nix` (`services.servicePortal.mounts`).
Protocol: `AGENTS.md` § "Agent turns", `docs/agent-context/HOME-PREAMBLE.md`.

## Shape

| Layer | What | Where |
| :--- | :--- | :--- |
| Store | `xs` 0.15.0 (`cross-stream`), topic `agent.turns`, ttl `forever` | `/var/lib/xs-agent-turns/store`, Unix socket `store/sock` |
| Shim | Go stdlib + pure-Go sqlite, bearer auth, schema + secret allowlist, dedup index | `127.0.0.1:8093`, `dedup.sqlite` beside the store |
| Exposure | `tailscale serve --https=8449` → `http://127.0.0.1:8093` | `https://delphi.cloudforest-kardashev.ts.net:8449` |
| Units | `xs-agent-turns.service`, `agent-turns-shim.service`, `tailscale-serve-agent-turns.service` | delphi |
| Secrets | `agent-turns-token` (fleet) plus one per outside holder (`-netbook`, `-muse`, `-vesper`) in `modules/secrets.yaml` | 0400, owner `xs-agent-turns` |

The shim was Python until 2026-11-07. The read-path benchmark
(`tools/turns-runtime/README.md`) picked Go for the turns stack on the edit loop
(42 ms warm rebuild against 553 ms for Elixir) and the idle process (12.6 MB
against 182 MB), and the shim followed: same routes, same field rules, same
`dedup.sqlite` — so the first replay after the cutover still lands on the frame
the Python shim stored, which is what `main_test.go`'s legacy-database test
pins. It is one static binary with no interpreter to ship.

The store is never exposed. `xs serve` runs without `--expose`, inside
`PrivateNetwork=true`, with `RestrictAddressFamilies = ["AF_UNIX"]`, so there is
no address it could listen on even if a flag changed. `xs` has no authentication
of its own (verified: a bogus `Authorization: Bearer` header is ignored and the
append returns 200) and it does expose `DELETE /{id}` and `POST /import`, which
is why append-only is enforced by the shim's route table rather than promised by
the store.

## Tokens: one per holder, never shared

A holder that is not a fleet agent (the netbook's agent, say) gets its own token,
so revoking it cannot take the fleet credential with it. Each accepted token is a
declared sops secret; the shim's token set is generated from that list, never
scanned off a directory:

```nix
services.agentTurns.enable = true;
services.agentTurns.additionalTokens = ["agent-turns-token-netbook"];
```

That produces `AGENT_TURNS_TOKENS=agent-turns-token=/run/secrets/agent-turns-token:…`
(`name=/path`, colon separated), and every append logs the name that authenticated
it (`append token=agent-turns-token-netbook source=… client=…`; a replay logs
`dedup` instead, so a retry does not read like a second turn).

- **Rotate:** rewrite the value in `modules/secrets/secrets.yaml` — the submodule
  file is the source and `modules/secrets.yaml` is a mirror that
  `task infra:secrets:sync` regenerates, so a value written only into the mirror
  is deleted by the next sync (`task infra:secrets:edit:secrets` does both and
  commits) — then `nixos-rebuild switch`. `restartUnits` restarts the shim,
  because it reads its tokens once at start — without it the new value lands in
  `/run/secrets` and nothing uses it until a reboot.
- **Revoke:** drop the name from `additionalTokens` and switch. The shim's set is
  rebuilt from the declaration, so a file sops leaves behind is no longer read.
- **Deliver to a non-fleet machine:** sops-nix does not manage that host, so the
  operator writes the file over the tailnet, from delphi, with the value on
  stdin — never in argv and never in chat:

```bash
sops -d modules/secrets.yaml | yq -r '.["agent-turns-token-netbook"]' |
  ssh alice@netbook 'umask 077; install -d -m 700 ~/.config/agent-turns &&
    cat > ~/.config/agent-turns/token && chmod 600 ~/.config/agent-turns/token'
```

## Shim API

| Route | Result |
| :--- | :--- |
| `POST /v1/events` | `201` + `{"id": <frame id>}`; `200` + stored id when that client UUID already exists |
| `GET /v1/events?repo=&subject=&source=&limit=` | `200` + `{"count","scanned","truncated","events"}`, newest first, `limit` 1–200 (default 50) |
| `GET /healthz` | `200` + `{"ok":true}`, no auth |
| anything else with `PUT`/`PATCH`/`DELETE` | `405` + `Allow: GET, POST` |

`repo=` matches the prefix of `subject` before the first `:`, because the fixed
schema carries the repo inside `subject` (`<repo>:<task-id>`) rather than in a
field of its own. Entries come back with `_frame` added: the xs frame id, for
cross-checking against `xs get`.

**A filter is a question about the log, not about one page.** An unfiltered read
returns the newest `limit` frames; a query carrying `subject=`, `repo=` or
`source=` scans up to `MAX_SCAN` (2000) frames and returns the newest `limit`
matches, so a turn from last month is still found and `resumability` is not a
claim about the last fifty entries. `count` is every match, `scanned` the frames
read, and `truncated: true` says the scan hit its cap and older matches may exist.
Until 2026-11-03 the filter ran over the page instead, and `?subject=…` answered
`count: 0` for a subject that was in the store — measured against a 113-turn log.

A person without a shell reads the same log over Gemini:
`gemini://delphi.cloudforest-kardashev.ts.net:1966/turns/` — newest turns, a
word search and the open claims ([`gemini-turns.md`](gemini-turns.md)). It is a
reader over this shim, so it adds no second store.

The read side (`agents:xs:list`) adds the one rule the shim cannot know: an
`in_progress` whose newest entry is older than `STALE_DAYS` (7) is **stale** —
printed, and not a failed check, because an agent that died mid-turn must not red
the gate forever.

## Query: `Q=` is the grep, TOON is the shape

The turn log replaced the markdown ledger (`AUDIT.md`, retired 2026-11-05), and a
log only replaces a file if finding something in it is as cheap as grepping that
file. `scripts/task/xs-turn-query.jq` is the read model; the task renders it three
ways and never prints a raw event to an agent.

| | |
| :--- | :--- |
| `Q="tika heap"` | every word must appear somewhere in the turn (AND), case-insensitive. Subject hits weigh 3, action/claims/files 2, outcome/rationale/source 1; matches rank by weight then recency |
| `ID=03h6jhaj` | one turn by frame id or client UUID; a prefix is enough |
| `REPO=`, `SUBJECT=`, `SOURCE=` | pushed to the shim, which scans 2000 frames on a filtered read |
| `LIVE=1` | the open queue: one row per subject (the newest unresolved turn), intersected with `Q=` |
| `CLAIM='a,b'` | exit 1 when a live claim overlaps an area you are about to touch |
| `FORMAT=toon` (default) · `text` · `json` | compact rows for an agent · a person · the whole model for a program |

A row is `ts, src, subj, out, act, claims, files, id` plus `hit` (the fields that
matched) and `snip` (a word-aligned window around the first match), and the
payload always ends with `live`, `stale` and `verdict`:

```bash
$ task agents:xs:list Q="tika heap" LIMIT=3
q: {repo: "", subject: "", text: tika heap, ...}
scanned: 168
truncated: false
matched: 2
stored: 168
stale_days: 7
turns[2]{ts,src,subj,out,act,claims,files,id,hit,snip}:
  "2026-11-05T15:19",buffy,"nixconfig:delphi-microvm-cleanup",done,"Deployed the tika heap-flag fix on delphi…",hosts/delphi,0,03h6jighuo0twatcedwx3d1vt,action,"…"
  "2026-11-05T15:13",buffy,"nixconfig:checks-units",done,"Added checks:units (systemd-analyze verify…","taskfiles/checks.yml,scripts/task/unit-gate.sh",7,03h6jhajs277mthu4nlc3ld0g,action,"…"
live[3]{ts,subj,src,kind,text}:
  …
verdict:
  state: note
  text: live claims exist; pass SUBJECT= or CLAIM= to test your own work
```

`FORMAT=text` lays the same model out for a person — two lines per turn, the
matched field in brackets, then the claims and the verdict. `snip` is suppressed
there when the match is only in `action`/`subject`, which the row already prints.

The row is deliberately not the event: `rationale` (up to 1000 characters), the
full file list and the commit hashes stay in `FORMAT=json` and in the store. An
agent reading twelve rows should be able to answer "did someone already do this,
and where is it written" without spending twelve kilobytes.

Rejections: `401` missing or wrong bearer; `400` unknown field, missing field,
bad UUID or timestamp, bad `outcome`, a blocked/failed outcome without its note,
oversized body (16 KiB) or field, credential-shaped free text, and key material
in any field. Error bodies name the field, never the value.

## Turn schema

```json
{
  "id": "9f1d3c8e-1111-4a2b-8c3d-4e5f60718293",
  "ts": "2026-10-30T18:20:00Z",
  "source": "buffy",
  "kind": "turn",
  "subject": "nixconfig:agent-turns",
  "action": "added the shim and the tailnet mount",
  "rationale": "coordination state must be queryable",
  "base_commit": "3a47a215",
  "branch": "feat/agent-turns-xs-delphi",
  "files_changed": ["modules/services/agent-turns/shim/main.go"],
  "commits": [],
  "outcome": "in_progress",
  "claims": ["modules/services/agent-turns"]
}
```

`task agents:xs:post` renders this body from `scripts/task/xs-turn.jq`: the JSON
above documents the shape, it is not something an agent assembles by hand.

`outcome` is `done`, `in_progress`, or `blocked: <note>` / `failed: <note>`.
On the read side the newest entry per subject decides, and only `done` closes it:
`in_progress`, `blocked` and `failed` all count as live, because an unresolved
subject is open work rather than history.

**`blocked` is a claim about capability, not about preference.** It is for work
whose next step cannot start — missing credentials, a host action only a person
can take, or a decision that changes what gets built. An agent that keeps writing
asynchronously, or that carries on past a choice the operator has not made yet,
is `in_progress` with the open question in `rationale`: a preference does not stop
the work, so labelling it `blocked` hides the work that is actually moving.
An unknown field is a 400, which is what keeps a transcript from being posted
under an extra key. Prose fields are capped (action 500, rationale 1000) and
scanned for credential shapes; `files_changed` and commit hashes are exempt from
the word scan, since `modules/secrets.yaml` is a legitimate path.

## Verification

Run from a tailnet node that is not delphi. The token never goes on a command
line, so read it into a variable:

```bash
X=https://delphi.cloudforest-kardashev.ts.net:8449
export AGENT_TURNS_TOKEN="$(sops -d ~/Documents/nixconfig/modules/secrets.yaml | yq -r '.["agent-turns-token"]')"
curl -sS "$X/healthz"
curl -sS -H "Authorization: Bearer $AGENT_TURNS_TOKEN" "$X/v1/events?limit=5" | jq '.count'
```

A public probe must fail: the mount is `(tailnet only)` in `tailscale serve
status`, port 8449 is not in `networking.firewall.allowedTCPPorts`, and nothing
in nginx points at it. From the open internet the port is closed.

## Export, restore, rollback

The store exists on delphi only, so delphi exports it on a timer and ships the
dumps to frieren, whose 03:28/03:30 restic snapshots carry them off the box.
Everything sits inside frieren's 03:00–05:30 maintenance window:

| Time | Host | What |
| :--- | :--- | :--- |
| 03:05 | delphi | `xs-agent-turns-backup`: dump to `/var/backups/xs-agent-turns/<stamp>`, rsync to `devji@frieren:/srv/backup/agent-turns/`, prune dumps older than 7 days |
| 03:28 | frieren | BurgerNAS restic snapshot (cold vault) includes `/srv/backup/agent-turns` |
| 03:30 | frieren | local restic snapshot (`--keep-daily 7 --keep-weekly 5 --keep-monthly 12`) |

`services.agentTurns.backup` is the one knob (directory, `startAt`, `retain`,
`pushTo`, `pushKeyFile`); delphi sets `pushTo` and nothing else. The unit runs as
root — the store is 0700 between two service users — and authenticates the push
with the fleet key, so a failed export stops the run and the far side keeps
yesterday's frames instead of a fresh timestamp over an empty tree. Retention
lives in two places on purpose: 7 dated dumps locally, and restic's own policy
for history.

One-shot export, same code path:

```bash
task infra:xs:export OUT=/tmp/agent-turns-$(date +%F)   # on delphi
```

Restoring needs the dump on the host that will serve it:

```bash
rsync -a frieren:/srv/backup/agent-turns/<stamp>/ /var/backups/xs-agent-turns/
```

Restore into a fresh store (order matters: contents first, then frames):

```bash
for f in "$DUMP"/cas/*; do xs cas-post /var/lib/xs-agent-turns/store < "$f"; done
while IFS= read -r line; do
  printf '%s' "$line" | xs import /var/lib/xs-agent-turns/store
done < "$DUMP/frames.jsonl"
```

Two xs traps, measured on 0.14.2: `xs cat` fails with `Operation not permitted`
when stdout is a regular file (pipe it, `| cat`), and `xs import` reads exactly
one frame per invocation.

Rollback of the endpoint itself:

```bash
sudo systemctl stop agent-turns-shim.service xs-agent-turns.service
sudo systemctl disable agent-turns-shim.service xs-agent-turns.service
sudo nixos-rebuild switch --rollback      # restores the previous generation
```

The state directory survives a rollback; removing it deletes the turn log, so
export first. Reverting the AGENTS.md protocol is `git revert` of the commit
that added it — the text lives in `AGENTS.md`, `docs/agent-context/HOME-PREAMBLE.md`
and `modules/user/ai/hermes-persona/AGENTS.md`, and nowhere else.

## Open decisions

- Whether `xs` should be built from source instead of the pinned arm64 release
  asset; the asset is the project's own pipeline output and is hash-pinned, but
  a source build is the fleet's usual provenance argument.
- Whether the dump should be encrypted before it leaves delphi. It is 0700 on
  delphi and travelled over the tailnet into restic's encrypted repository, so
  the transport and the archive are covered; the received copy on frieren is
  plain text.
- The preserved `agent.turns` topic grows without bound (`ttl: forever`); a
  retention sweep could use `ttl: last:<n>`, at the cost of losing claims that
  explain an old branch.
