# Selector daemon — predesign packet

Handoff for `AGENTS.nix` → `daemon-earns-it-by-compression` (IN FLIGHT). M0–M3 are
built (2026-11-03: `task ops:q`, `task checks:selector`,
`task checks:selector:sidecar`, measurements in
[`tools/selector/README.md`](../tools/selector/README.md)); stage 1 turns the
question into a query object in 0.978 of held-out cases and answers 21 of the
battery's 28 scored questions with every row set correct, declining 6 of 6
abstain, and `selector.service` is the resident copy behind it. The rule this has
to clear is
`[[flake/policies.nix#daemon-clears-kelly]]` — do not read past §2 without it,
because the arithmetic is what decides whether any of the rest is worth building.

---

## 1. Scope

**It is a selector.** Natural language → a *query object* over the compiled
registries → execute → **≤ 80 tokens** with pointers, or a refusal cheaper than the
call it saves.

**It is not:**

- a generator or summariser — prose has no ground truth, so its `p` is unmeasurable
  and unmeasurable `p` is how `edge-caller` died;
- a router for the six graph lookups — the keyword router already resolves **6/6**
  in 265 ms with no model (`ops:ask`), so that class is closed;
- a chat surface, a code assistant, or anything that needs a conversation.

## 2. The economics it must clear

`ev = p·save − (1−p)·cost`, enable only if `save > 0` and `ev > 0`. Break-even:
`p* = cost / (save + cost)` with a wrong answer costing `cost ≈ 1.2 s`.

| replaces | save | p* |
|---|---:|---:|
| naming an argument | 0.16 s | 0.88 |
| one tool call | 1.2 s | 0.50 |
| `ops:kg:host` (960 B) | 3 s | 0.29 |
| `ops:kg:blast` (18,025 B) | 20 s | 0.06 |
| `task --list-all --json` (274,574 B) | 300 s | 0.004 |

Only the last three rows are winnable, and they are winnable *by almost any
selector*. So the design maximises `save`, not accuracy.

Derived from bytes: `tokens = bytes / 4`, `seconds = tokens / 50`.

## 3. Architecture

```
question
  ├─ 0  shortlist        lexical + vector over registry terms       ≤5 ms   CPU, no model
  ├─ 1  selector         grammar first, model only if it exists     5–220 ms
  ├─ 2  validate         fields ∈ compiled schema?  → else REFUSE    ~1 ms
  ├─ 3  execute          jq over the compiled JSON                  ~40 ms
  └─ 4  render           ≤80 tokens + pointers, or REFUSE           ~1 ms
```

Hard rules:

- **Stage 0 decides most refusals.** An empty shortlist refuses in ~5 ms, which is
  what keeps abstention free. A refusal costing more than the direct call is a loss
  even when it is honest.
- **Stage 2 is a schema check, not a vibe check.** A field the registry does not
  have is rejected before execution.
- **Stage 3 empty result = refusal**, so `p` is measured over answered cases.
- **Stage 4 carries pointers** (`notes.<id>.status`, `host.<name>.role`) so the
  agent verifies with one cheap call instead of trusting prose.

## 4. The query object (real field names)

```json
{"registry": "notes|inventory|host|graph|ledger|tasks",
 "filter":   {"status": "OPEN", "touches": "sops"},
 "fields":   ["id", "title", "status"],
 "limit":    5}
```

Field vocabulary, taken from the compiled data rather than invented:

| registry | filterable fields |
| :--- | :--- |
| `inventory.hosts.<h>` | `role`, `kind`, `arch`, `status`, `status_detail`, `category`, `persona`, `managed`, `is_nix`, `system_type`, `desktop_environment`, `builder`, `ci`, `flake`, `network`, `hardware`, `software`, `users`, `notes` |
| `agentsNotes.notes.<id>` | `kind`, `status`, `priority`, `date`, `title`, `summary`, `body`, `refs.{modules,tasks,docs,hosts}`, `from`, `supersedes`, `replacedBy` |
| `knowledgeGraph` | node type (`host`, `skill`, `doc`, `tag`), edge kind (`mentions`, `references`, `tagged`), the six patterns |
| `taskfileGraph` (`taskfile_graph.py by-name`) | `name`, `desc`, `params`, `body` (build verbs), shard |
| ledger | job name, host, exit, duration, age |

## 5. Data and ground truth

Generated, never hand-labelled:

1. For each registry row and each filterable field, template 3–4 question phrasings
   (`which hosts are in the <category> category`, `what is <host>'s role`).
2. The label is the **query object**, and the gold result is the rows that query
   returns. Both come from the compiled data, so labels regenerate whenever
   `inventory.toml`, `AGENTS.nix` or the taskfiles change.
3. **Abstain examples** are 20 % of the set: questions whose answer is not in the
   data (`what is frieren's CPU temperature`). Their label is refusal, and they are
   what stop the model learning to always answer something.
4. **Split by entity, never by template** — a question about `frieren` may not
   appear in train and test, or the metric measures memorisation.

Estimated size: ~14 hosts × 20 fields + 200 notes × 12 + graph edges + 525 tasks
≈ 6–8 k facts × 4 phrasings ≈ 25–35 k pairs, ~60 tokens each ≈ 2 M tokens. That is
a *small* dataset, which is the argument against training from scratch.

## 6. Model

- **v0 — grammar only, `p = 1`.** `task q:notes STATUS=OPEN TOUCHES=sops`. If this
  clears the gate, stop: the model is decoration. Build this first, always.
- **v1 — fine-tune, not pre-train.** A 17–22 M sentence encoder
  (all-MiniLM-L6-v2 / bge-micro class) as a classifier over the closed label space
  (registry × filter-field × operator), plus a cross-encoder reranker over the
  top-5 shortlist for the "which of these docs should I read" class. 2 M tokens and
  a small label space are far below what a from-scratch model needs to learn
  English; fine-tuning a pretrained encoder is minutes, training one from scratch
  is a research project with a worse encoder at the end.
- **Export ONNX**, inference ≤20 ms on CPU, `onnxruntime` from nixpkgs (works on
  aarch64 — check this first, some wheels do not).
- No Python at runtime if avoidable: the daemon is a small Rust/Go binary loading
  the ONNX graph, or the ONNX is called from the existing scripts.

## 7. Compute

| option | fit | note |
| :--- | :--- | :--- |
| **eisen** (fleet GPU host, already runs the LLM stack) | **best** | a 22 M fine-tune is minutes; the data never leaves the fleet; `compute_tier` already says it is the heavy node |
| **GitHub Codespaces** | good fallback | no GPU, but a 22 M encoder over 30 k pairs is ~30–60 min on 4 cores; reproducible devcontainer, and `codespace:*` tasks already exist in this repo |
| **Oracle $300 trial** | poor for this | GPU shapes are capacity-gated in practice and the credit expires in 30 days; one hour of training does not justify provisioning a VM, drivers and a dataset transfer. Keep it for the case this design avoids: a ≥100 M model or a from-scratch run |

Decision: train on **eisen**; if it is gaming-occupied, use a codespace. Do not
spend the trial credits on a job that fits in a coffee break.

## 8. Evaluation

- A 30-question battery with gold result sets, in the shape of
  `toolcall-battery.jsonl` but with an expected *row set*, not an expected tool.
- Metrics, all printed: `answered p`, `coverage` (answered / asked), `S` in
  bytes→tokens→seconds, `refusal ms`, and the resulting `ev`.
- The battery runs as `checks:selector` and reads the numbers into
  `flake/daemons.nix`; the policy refuses `wanted = true` without them.

## 9. Milestones and kill criteria

| milestone | deliverable | passes when |
| :--- | :--- | :--- |
| M0 | grammar + battery, no model | `p = 1` on the grammar's own class; `S` measured on real questions |
| M1 | `S` and coverage measured | ≥3 s median save, ≥40 % of the battery answered (met: 943 s, 71 %) |
| M2 | model front over M0 | answered-case `p ≥ 0.3` at the M1 `S`, refusal ≤100 ms (met: 1.0 at 70 ms) |
| M3 | gate flips | `ev > 0` from the battery (met: 942.94 s at p 1.0) · resident unit (met: `selector.service`, parity by `checks:selector:sidecar`) |

Kill it if: `S` amortises to zero because the grammar is learnable in one session;
refusal exceeds 100 ms; answered-case `p < 0.3`; or the daemon needs prose to answer.

## 10. What the builder creates

```
scripts/task/q.sh              query object -> jq over compiled JSON, ≤80 tokens
taskfiles/ops.yml              ops:q (grammar), documented exit codes
scripts/task/selector-battery.jsonl  30 questions + gold row sets
scripts/task/selector-check.sh       p, coverage, S, refusal ms, ev
scripts/task/selector-sidecar.sh     lifecycle + client for the resident stage 1
tools/selector/                training + ONNX export, README with the recipe
modules/user/selector-daemon.nix     the unit: selector.service
flake/daemons.nix              one entry, `wanted = true` behind that unit
flake/packages.nix             the ONNX artifact if it is bundled
```

Acceptance: `task ops:q` answers the battery without a model; `checks:selector`
prints the four numbers; the policy holds; nothing in the path needs network.

## 11. Open questions

- Does `onnxruntime` build and run on aarch64-darwin and aarch64-linux here, or is
  the fallback a pure-Rust inference (`candle`)?
- Is the label space small enough that a classifier beats a 5-line intent matcher?
  M0 answers this cheaply.
- What is `cost` for a *plausible but empty* answer — does the agent retry twice?
  Measure it; it moves `p*` more than any model improvement.
