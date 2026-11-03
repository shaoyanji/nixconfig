# selector — M3: stage 1 composes what the executor can already run

Scope, economics and milestones: [`docs/selector-daemon-predesign.md`](../../docs/selector-daemon-predesign.md).
This page records only what the builder decided and measured; the design lives there.

## What runs today

| Piece | Path | What it does |
| :--- | :--- | :--- |
| Executor | `scripts/task/q.sh` | query object → schema check → jq → TOON answer (≤80 tokens, one pointer per row) or a classed refusal |
| Grammar front | `task ops:q` | `REGISTRY=` plus the common filters; every other field through `CLI_ARGS` |
| Stage 1 | `tools/selector/model.py` | question → query object: a Naive Bayes route to the registry, then a scan of the compiled vocabulary for the constraints |
| Dataset | `tools/selector/dataset.py` | questions templated from the compiled registries, entity-held-out split, 20 % abstain |
| Build | `tools/selector/build.sh` | registries → dataset → model → held-out metrics (`task ops:q:train`) |
| Resident | `tools/selector/serve.py` | stage 1 in a process on `$XDG_RUNTIME_DIR/selector.sock`; `q.sh --question` asks it first and falls back to the interpreter |
| Unit | `modules/user/selector-daemon.nix` | `selector.service`, on by default wherever the role imports it |
| Battery | `scripts/task/selector-battery.toon` | 30 questions: 24 with a gold query object and gold row set, 6 abstain |
| Gates | `task checks:selector` · `task checks:selector:sidecar` | scores on the portable path, then proves the resident one is byte-identical |

Measured 2026-11-03 on delphi:

| Number | Value | Meaning |
| :--- | ---: | :--- |
| executor `p` | 1.0 | 22 answered battery cases, every row set equal to gold |
| `S` | 942.94 s | median saved, TOON answer vs the compiled read (bytes/4/50) |
| refusal | 71.5 ms | mean over the 6 abstain cases |
| stage 1 held-out `p` | 0.978 | entity-held-out split, 491 pairs, 27 templates |
| stage 1 held-out coverage | 0.923 | |
| stage 1 battery `p` | 1.0 | 21 of 21 answered questions, every row set correct |
| stage 1 battery coverage | 0.75 | 21 of 28; 1 refused, 6 of 6 abstain declined |
| resident vs cold | 180 vs 250 ms | one answered question, `q.sh --question` |
| resident vs cold (refusal) | 37 vs 105 ms | same, a declined question: the predesign's bar is 100 ms |

`flake/daemons.nix` records this as `wanted = true` with `unit = "selector.service"`,
and `checks:selector:sidecar` is what makes that sentence true rather than
aspirational: the daemon must answer the same bytes, the same exit code, on one
question per registry plus a refusal. It buys the ~70 ms of interpreter start and
import, which is the whole of stage 1's cold cost — the model itself is 107 KB and
loads in 1.7 ms. It does not buy the executor's ~75 ms of jq, and it should not:
the daemon runs `model.py`, never a second copy of the query semantics.

## How stage 1 is put together

The classifier decides **one** thing — which registry the question is about (and,
for a numeric or entity question, which field). A bare number is ambiguous between
`in 10` and `out 30`, so the class supplies the field; everything else is
extraction over the compiled vocabulary, which is `q.sh --schema`, the compiled
rows, and `q.sh --searchable` — one eval per registry, the same cache the query
reads. Nothing here keeps a second copy of the data's vocabulary.

That split is what makes a compound question work. A filtered object holds several
entries and the executor already runs them all (`which active hosts are in the
laptop category` → `status=active`, `category=laptop`), so the old "one slot or
refuse" rule was a limit of this file, not of the query.

Each rule below exists because its absence produced a wrong answer in testing:

1. **Longest span wins, and one span is one constraint.** `microvm` beats `vm`;
   `open` is both a note kind and a status, so a same-span conflict is broken by
   the classifier's preferred field, then by the case the question preserved
   (`which notes are OPEN` is the status, `which open notes` the kind), and
   otherwise dropped rather than guessed.
2. **A value spelled like a mention verb is the operator.** `notes reference
   design` is a search, `reference notes` is a kind: the word after it decides.
3. **A type alone is not a question.** `host` is a graph node type and the fleet's
   own noun, so a `graph` constraint needs the graph's words — otherwise `which
   hosts are in the banana category` came back with every host in the fleet.
4. **The registry must be confirmed by the vocabulary.** A route whose registry
   yields no constraint gives way to the next, bounded to three, which is how
   `which host is a microvm guest` reaches `category=microvm` instead of 36 nodes.
5. **An entity question must name its attribute.** `what is frieren's CPU
   temperature` names no field any registry holds, so it refuses instead of
   answering `role` — a real value about the wrong question.
6. **Balanced classes.** Pair counts are entity cardinality (527 task rows, 8
   statuses), so counts are capped and the prior is uniform — otherwise the
   biggest class wins on arithmetic alone.

## What is not built

- **The encoder.** `train_encoder.py` is the fine-tune + ONNX recipe and it was
  **not run here**: delphi has no torch, transformers, onnx or numpy, 2 cores and
  no GPU, and the predesign puts training on eisen. Until it prints a metric on
  eisen, it has proven nothing — and its held-out row must beat 0.998 before the
  heavier backend earns its place.
- **One battery question refuses**, and it is an honest refusal rather than an
  error: `which task is the selector grammar` names `ops:q` by its description and
  has no mention verb. The predesign question that used to refuse now answers:
  `touches` is an AND over its words, so "the selector predesign" finds
  `docs/selector-daemon-predesign.md` across the hyphens instead of missing it.
- **The executor's own latency.** ~75 ms of jq survives every question. Cutting it
  means moving the query into the daemon, which is the second implementation this
  deliberately does not have.

## Why TOON, in both directions

The labels are agent-authored, so the battery is a `.toon` document
([[flake/policies.nix#agent-boundary-is-toon]]). The converter owns the quoting
and the `[n]`; a miscount fails `checks:selector` with the repair command instead
of quietly decoding to fewer rows. Answers are TOON for the same reason, and
`--json` exists only where a program is the reader.

## Regenerating

```bash
task ops:q:train                       # artifact to ~/.cache/nixconfig/selector
task ops:q Q="which notes are blocked" # stage 1 + stages 2-4, end to end
task checks:selector                   # the gate: self-test, battery, held-out numbers
task ops:q:sidecar -- status           # the resident stage 1 (start|stop|status|ask)
task checks:selector:sidecar           # parity and speed of the resident path
```

The artifact is machine state and never committed; `checks:selector` builds its
own copy in a temp dir, so a stale artifact cannot make the gate pass.
