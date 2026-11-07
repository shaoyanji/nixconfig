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

## Verdict: Go

Measured on clanker, 2026-11-07, `CLIENTS=1000`, 20 publishes, 20 000 frames
delivered. Every run connected all 1000 clients with 0 errors.

| runtime | cold build | warm build | artifact | cold start | idle RSS | RSS @1000 | p50 | p99 |
| :------ | ---------: | ---------: | -------: | ---------: | -------: | --------: | --: | --: |
| go      |    6 284 ms |     42 ms |  8.9 MB |     32 ms |  12.6 MB |   58.5 MB | 11.8 ms | 20.2 ms |
| rust    |   14 403 ms |  2 186 ms |  2.1 MB |      8 ms |   6.4 MB |   34.4 MB | 10.7 ms | 21.3 ms |
| elixir  |    7 084 ms |    553 ms | 24.3 MB |    472 ms | 181.8 MB |  244.6 MB | 10.8 ms | 21.7 ms |

Stream performance does not separate them: 10.7–11.8 ms p50 and 20.2–21.7 ms
p99 is one spread, and the p99 is a scheduling tick rather than a runtime cost.
The read path is a fan-out of a few thousand small writes, which every one of
these runtimes does the same way.

The decision falls on everything around the stream:

- **Warm rebuild.** Go 42 ms against Rust 2 186 ms and Elixir 553 ms. This is
  the number a person feels on every edit to the dashboard, and it is 50× apart.
- **Idle footprint.** 12.6 MB against Elixir's 182 MB. The turns site sits next
  to the shim on delphi and is idle most of the day; 170 MB of resident BEAM for
  a viewer is a cost with no matching return.
- **Dependencies.** Zero, standard library only. Rust pulls 67 crates through
  `Cargo.lock`, Elixir 3 packages plus OTP 28, and every one of them is a pin
  that has to keep building in the flake. Go has none to pin.
- **Cold start.** 32 ms against 472 ms. Cold start is what a health check and a
  restart see, and the Elixir release spends that in the VM before it answers.

Rust wins on artifact size and idle RSS, and both are real: 2.1 MB single binary
and 6.4 MB resident. That is not enough to pay a 2.2 s edit loop and 67 pinned
crates for a read-only view.

Elixir's advantage — OTP supervision, one process per stream — is the argument
for a stateful service with per-connection logic. This one has none: a stream is
a `text/event-stream` write, and the fan-out fits in one mutex-guarded subscriber
list. If the site later grows per-connection state worth supervising, this table
is what to re-run, not what to re-argue.

The two losing prototypes stay in the tree as the evidence behind this table.
They are frozen: the refactor is Go, and `go/main.go` is its starting point.

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
