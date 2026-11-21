# MEMORY.md

Boot context primes a session; it is not evidence. The compiled layer map is
`nix eval --json .#memoryLayers`; the contract is
`docs/agent-context/HOME-PREAMBLE.md` (§ Memory, in order).

## Read, in order

1. **Coordination** — `task agents:xs:list LIVE=1`. The newest entry per subject
   decides liveness; `in_progress`, `blocked` and `failed` stay live until a
   `done` lands on top.
2. **Design record** — `task ops:notes:near Q="<intent>"`, then
   `task ops:notes:lineage ID=<id>`. Never read `AGENTS.nix` in full.
3. **Structure** — `task ops:kg:*` for "what touches X"; prose via `qmd`.
4. **Personal prose** — the Obsidian vault; zettels, never repo facts.
5. **Deep consult** — mem0 + supermemory; advisory, never authority.
6. **Scratch** — `ai-memory`; no schema, never authority.

Boot files (`~/.hermes` USER.md / MEMORY.md / SOUL.md) are session priming, not
a memory layer.

## Write

| It is… | Write it to |
| :--- | :--- |
| A proposal / decision | an `AGENTS.nix` note (`agents-notes`) |
| Open work | an `AGENTS.nix` note with `kind = "open"` / `"handoff"` |
| What happened | one xs turn (`task agents:xs:post`) |
| History | `docs/history/` |
| A procedure | `docs/` or a skill |

Never create a markdown file at the repo root. Never duplicate a fleet table.

## No handoff channel

Do not author `~/.hermes/handoff*.md` or an exit interview, do not read one as a
directive queue, and do not send a pane a pointer to one. A new session starts
from `task agents:xs:list LIVE=1` and the repo. Durable continuation goes in the
xs turn's `rationale`.

## Routing

Read `router`, then classify once per turn:

```bash
jev-decide classify --provider typesafe --text-file - \
  --criteria "$HOME/Documents/nixconfig/.agents/skills/router/assets/labels.json" \
  --min-probability 0.8 --min-margin 0.15
```

Exit `0` selected, `2` needs_review, `1` error. Read `margin`, not only
`probability`. A label routes work; it never authorises delete, deploy, push or
send. On error use the rule table and write `jev_called: false`; never invent a
probability or a flag. `jev-decide --help` is the contract for the invocation.

## Pane control

`task agents:tmux` is the name map; `task agents:tmux:show NAME=<lane>` tails a
pane. Never send `Escape` or `Ctrl+C` to a pane that is working — it aborts the
worker's turn and can drop the session. Leave a pane by letting it finish,
detaching (`Ctrl-b d`), or its own `/quit`; kill a window only when it is
confirmed dead. Long text goes in with `load-buffer` + `paste-buffer` + one
`Enter`, and only a fresh working line proves submission.

## Local tooling (verify, do not trust prose)

- `jev-decide` at `~/.local/bin/jev-decide`; provider `typesafe`; key
  `TYPESAFE_API_KEY` in `~/.config/hermes/hermes.env`. There is no
  `TYPESAFEAI_API_KEY` on this host.
- `agy` for one-shot engineering delegation, interactive (no `-p`) for a
  persistent pane. `crush` is deprecated here; do not route work to it.
- Email: `himalaya` v2.0.0. Never send or draft with guessed personal details
  without explicit approval.
- Secrets: read one key into a variable. Never print a value or a decrypted file.
