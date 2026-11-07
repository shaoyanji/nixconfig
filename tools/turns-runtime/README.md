# turns-runtime

Three prototypes of the turns **read path**, measured on one box, to choose the
runtime for the refactor. Not production code: the point is the comparison.

Read path means what a reader actually touches — static bytes, one history frame
per connection, and a fan-out of new turns to every open stream. The per-row
prompt POST is out of scope: it is one `hermes` process per request, identical
work in any language, and it would measure the agent, not the server.

| | |
| :--- | :--- |
| Go | `go/main.go` — standard library only |
| Rust | `rust/src/main.rs` — axum + tokio |
| Elixir | `elixir/` — Plug + Bandit, `mix release` |

Each serves the same three static files from the real dashboard, renders the
same 120-turn fixture (`fixture/turns.json`, made by `fixture.py`), speaks the
same SSE frames, and exposes two bench-only routes the page never calls:

- `GET /healthz` — the cold-start probe.
- `POST /api/broadcast` — publish one turn the way the shim relay would, with
  `: bench <seq> <epoch-ms>` in the frame so `load.py` can time the fan-out.
  The dashboard's own parser skips comment lines, so the page is unaffected.

## Running it

On a box that can afford three toolchains — clanker is the one this exists for:

```bash
task clanker:devshell -- ./tools/turns-runtime#default \
  'bash tools/turns-runtime/bench.sh'
```

`CLIENTS=1000 LOAD_SECONDS=20` by default. Results print as a table and as JSON
(`/tmp/turns-runtime-bench/results.json` on the box).

Local, with `agent-browser` not needed and nothing published:

```bash
nix develop ./tools/turns-runtime -c bash tools/turns-runtime/bench.sh
```

## What it measures, and why these

- **Cold build** — clean toolchain caches, so dependency fetch is included. This
  is the number that decides how a change feels, not how it runs.
- **Warm build** — touch the main source and rebuild. The loop a person lives in.
- **Artifact** — bytes to ship. An Elixir release carries the ERTS; a Rust or Go
  binary carries a libc's worth of nothing.
- **Cold start** — spawn to first `200`.
- **Idle and loaded RSS** — what holding N streams costs.
- **p50/p99** — publish to reader, across N streams.

The decision this feeds weighted build and deploy ergonomics; the stream numbers
are reported alongside so the next reader can re-weigh them.
