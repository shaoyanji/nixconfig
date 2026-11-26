# Intents and capabilities: the request side of a turn

An xs subject is a coordination label, not a description of work — jev-decide
selected 0/15 on them because nothing said what the classes were
(`agent-lane-plane`). The intent/capability schema is the declaration that was
missing: what an intent is, which lanes may serve it, and how a dispatch is
admitted or refused before it starts.

Code: `flake/intents.nix` (spec), `lib/quotient-hash.nix` (dedup key),
`scripts/task/intents-check.sh` (gate), `tests/intents/run.sh` (fixture).
Lenses: `flake/philosophy.nix`. Projection: `lib/knowledge-graph.nix`
(`capability`/`intent` nodes, `serves` edges). Gate: `task checks:intents`,
wired into `checks:quick` and the pre-commit hook.

## Shape

| Layer | What | Where |
| :--- | :--- | :--- |
| Intent | `{subject, kind, claims, gate}` — the coordination key, work class, path radius, ending gate | `flake/intents.nix` `intentFields` |
| Kind | one of six work classes (`chain-change`, `gate-change`, `flake-change`, `note-change`, `publish`, `drive`) | `kinds` |
| Capability | `{provides, claims, floor, via}` keyed by the xs `source` string | `capabilities` |
| Composition | `admit {intent, capability}` → `{ok, why}` — kind declared, lane provides it, every claim inside radius | `admit` |
| Dedup | `classOf intent` — quotient hash of `kind | sorted claims`; subject does not participate | `keyOf`, `classOf` |

The three refusal classes are the point: a `drive` lane admitting a
`chain-change` is "route, do not execute" made a predicate; a claim outside the
declared radius names the paths it would not cover.

## Reading it

```bash
nix eval --json .#intents | toon -e            # the whole spec
nix eval --json .#intents.gateReport | toon -e # the gate's evidence
task checks:intents                            # the gate
task ops:kg                                    # the projected nodes/edges
```

## The philosophy layer

`flake/philosophy.nix` records the mathematical lenses as data: `quotient-class`
is adopted (`classOf` above); `zeckendorf-epoch` and `cassini-checksum` are
deferred on the `kg-zeck-cache` measurement — 589 ms incremental vs 562 ms
HEAD+diff miss, 761 ms vs 35 ms hit, which fails the Kelly `save > 0` gate.
Each deferred lens names the condition that reopens it; `task checks:kg:zeck`
stays green so re-measuring is one command.
