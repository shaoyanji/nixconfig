# Agent turns: the xs coordination endpoint on delphi

An agent could only learn who was working on what from a chat report, which goes
stale the moment someone opens a branch. This endpoint is the replacement: one
small summary per agent turn, queryable by repo, subject and agent, so a claim
can be checked before work starts and a merge can be checked against the turns
that actually landed. It authorizes nothing — a builder still does not merge
unless a task says so.

Code: `modules/services/agent-turns.nix`, `modules/services/agent-turns/shim.py`.
Exposure: `hosts/delphi/configuration.nix` (`services.servicePortal.mounts`).
Protocol: `AGENTS.md` § "Agent turns", `docs/agent-context/HOME-PREAMBLE.md`.

## Shape

| Layer | What | Where |
| :--- | :--- | :--- |
| Store | `xs` 0.14.2 (`cross-stream`), topic `agent.turns`, ttl `forever` | `/var/lib/xs-agent-turns/store`, Unix socket `store/sock` |
| Shim | Python 3 stdlib, bearer auth, schema + secret allowlist, dedup index | `127.0.0.1:8093`, `dedup.sqlite` beside the store |
| Exposure | `tailscale serve --https=8449` → `http://127.0.0.1:8093` | `https://delphi.cloudforest-kardashev.ts.net:8449` |
| Units | `xs-agent-turns.service`, `agent-turns-shim.service`, `tailscale-serve-agent-turns.service` | delphi |
| Secrets | `agent-turns-token` (fleet) plus one per outside holder (`-netbook`, `-muse`, `-vesper`) in `modules/secrets.yaml` | 0400, owner `xs-agent-turns` |

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
| `GET /v1/events?repo=&subject=&source=&limit=` | `200` + `{"count","scanned","events"}`, newest first, `limit` 1–200 (default 50) |
| `GET /healthz` | `200` + `{"ok":true}`, no auth |
| anything else with `PUT`/`PATCH`/`DELETE` | `405` + `Allow: GET, POST` |

`repo=` matches the prefix of `subject` before the first `:`, because the fixed
schema carries the repo inside `subject` (`<repo>:<task-id>`) rather than in a
field of its own. Entries come back with `_frame` added: the xs frame id, for
cross-checking against `xs get`.

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
  "base_commit": "2754b781",
  "branch": "feat/agent-turns-xs-delphi",
  "files_changed": ["modules/services/agent-turns/shim.py"],
  "commits": [],
  "outcome": "in_progress",
  "claims": ["modules/services/agent-turns"]
}
```

`task agents:xs:post` renders this body from `scripts/task/xs-turn.jq`: the JSON
above documents the shape, it is not something an agent assembles by hand.

`outcome` is `done`, `in_progress`, or `blocked: <note>` / `failed: <note>`.
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
