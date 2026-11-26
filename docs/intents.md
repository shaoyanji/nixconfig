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
| Kind | one of seven work classes (`chain-change`, `gate-change`, `flake-change`, `note-change`, `publish`, `drive`, `experiment`), each with a `place` | `kinds` |
| Capability | `{provides, claims, floor, via, place}` keyed by the xs `source` string | `capabilities` |
| Place | where work executes — `eval` (RAM only), `local-gate` (bounded check), `nix-tool` (cache-served, never a closure), `delphi` (prod API), `clanker` (offload for disk-IO spend) | `places` |
| Composition | `admit {intent, capability}` → `{ok, why}` — kind declared, lane provides it, lane reaches the kind's place, every claim inside radius | `admit` |
| Route | `route.<kind>` → `{place, tier, io, gate, cmd}` — the Tier-0 query an agent asks before choosing eval, nix-tool, delphi or clanker | `route`, `planOf` |
| Dedup | `classOf intent` — quotient hash of `kind | sorted claims`; subject does not participate | `keyOf`, `classOf` |

The refusal classes are the point: a `drive` lane admitting a `chain-change` is
"route, do not execute" made a predicate; a claim outside the declared radius
names the paths it would not cover; a lane providing a kind whose `place` it
cannot reach is `capReachMisses` — refused at the gate and at `admit`.
Placement is [[flake/policies.nix#work-places-where-it-costs]]: frieren's
disk is not a build farm, so anything spending local disk IO goes to clanker.

## Reading it

```bash
nix eval --json .#intents | toon -e            # the whole spec
nix eval --json .#intents.route | toon -e      # kind -> place, tier, gate, command
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
