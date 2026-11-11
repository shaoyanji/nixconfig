---
name: cpg-advice
description: Second opinion from a different model through the `cpg` CLI — one prompt, no tools, no daemon. For review, brainstorming and cross-model sanity checks.
version: 1.0.0
tags: [ai, advice, review, chatplayground, jev]
platforms: [linux, macos]
---

# cpg-advice

`cpg` is the fleet's chatplayground client (packaged in
`modules/user/ai/hermes-user.nix`). This skill is its **advice lane**: one self-contained question
to a model that is not the one you are running on, one answer back. No tools, no agent loop, no
service to keep alive.

It is deliberately a CLI call and not a provider. The chatplayground endpoint takes exactly one
message of at most 15,000 characters ("Send only the new prompt. Conversation history is not
accepted."), while a hermes turn's system prompt plus tool schemas is ~29,000 characters — so
`--provider chatplayground` always falls back to the next provider. Shelling out is the only shape
that works.

## One question

```bash
cpg chat -m gpt-6-luna -s advice-nix "A NixOS module sets services.foo.enable = true but the
unit starts before network-online.target. What breaks first?"
```

- Prints the reply and exits; exit status 1 on failure.
- `-s NAME` is the session. The thread lives server side under a chat id; the transcript is
  mirrored to `~/.chatplayground/sessions/NAME.json` (0600). Reuse a name to continue, use a new
  name for a clean thread.
- Output is ANSI-coloured. Strip it when you will parse or quote the reply:

```bash
cpg chat -m gpt-6-luna -s advice-nix "..." | sed -e $'s/\x1b\\[[0-9;]*m//g'
```

## The material goes in the prompt, not on stdin

Piped stdin is read **only** when no prompt argument is given: `git diff | cpg "review this"`
sends `review this` alone and drops the diff (measured 2026-11-06). Put the content inside the
prompt and keep the whole thing under 15,000 characters:

```bash
cpg -m deepseek-v4.1-flash "Review this diff for bugs. Ten lines max, no preamble.
$(git diff)"
```

The model cannot read files, fetch URLs or run commands. If the material is larger than the
budget, summarise it yourself first, or split it into two questions; do not truncate silently.

## Choosing a model

`cpg models` lists 34 ids (2026-11-06). `premium_only` is a **global** flag, not an
answer about this account: this one holds a lifetime pool, and 10 of the 11 premium
ids still answered `403 only available to active subscribers` — `gpt-6.1-sol`,
`claude-sonnet-5-5`, `claude-opus-5-5`, `kimi-k3`, `qwen3.8-max`, `glm-5.3` and the
two perplexity ids among them. `gemini-3.8-flash` was the single exception that
worked. So treat `premium_only` as unavailable and re-test when the plan changes.
`cpg usage` is the authority on the plan; the catalog is not.

The value here is independence, not a ranking. Pick a different vendor from the model you are
running on, and stay with an id whose answer you have already judged. Ids exercised on
2026-11-06: `gpt-6-luna`, `claude-haiku-5-5`, `deepseek-v4.1-flash`, `gemini-3.8-flash-l`,
`kimi-k2.6`, `qwen3.7-plus`, `glm-5.3-flash`, `grok-4.7`.

## Budget: prompts are rate-limited, not metered

Measured 2026-11-11 on the lifetime pool (`cpg usage`): `dailyQueryCap` is
**350 prompts per day**, `compareSlots` 4 concurrent streams, and
`unlimitedQueries: true` means the monthly `pro` counter is not the ceiling. The
350 is the budget to plan against:

- One question, one call. A three-model `compare` costs three prompts, so a
  fan-out over every free id is 29 prompts for one answer.
- 350/day is about 15 an hour across a working day; a review loop that fires
  every diff still fits, and there is no hourly counter in the payload to pace
  against, so the day count is what `cpg usage` answers.
- On a 429, back off 60 s, then 120 s, then 240 s rather than retrying; the CLI
  has no queue.

## Machine surfaces

`models --json`, `status --json` and `usage --json` are the parseable forms:

```bash
cpg models --json | jq -r '.[] | select(.premium_only | not) | .id'
cpg status --json | jq -e '.authenticated'
cpg usage --json | jq '.usage.dailyQueries'
```

A one-shot `cpg chat` writes bare text when stdout is not a TTY — no prompt
glyph, no colour — which is what makes the section below work.

## Piping an answer into Jev

The reply is text and `jev-decide` reads text, so one model can write and the
classifier can score what it wrote. Keep the criteria about the *answer*
(`actionable`, `hedged`, `off_topic`), not about the original question:

```bash
cpg chat -m gpt-6-luna -s advice-review "Critique this plan in three bullets: …" \
  | jev-decide classify --provider typesafe \
      --text-file - --criteria /tmp/answer-quality.json
```

`--text-file -` is stdin, and the pipeline is clean because the CLI is. A low
probability means "read it yourself", never "discard it". The full decision
contract is the `jevdecide` skill.

## Borrowing a better writer than yourself

A fast local agent is good at tools and truth and often worse at prose and
long-chain reasoning. The lane is the fix, but only if the split is honest:

- **The agent owns facts, the lane owns voice.** Anything checkable — a path, a
  version, a count — the agent verifies and puts in the packet; the lane gets
  "write this". A lane that is asked to recall facts writes confident fiction.
- **Send the material, not a reference to it.** "Review the module in
  modules/foo.nix" is unanswerable; paste the module. Under 15,000 characters,
  and say so when you had to cut.
- **Ask for the shape you will consume.** "Three bullets, no preamble", "one
  sentence", "JSON with keys a,b" — a lane's default is an essay, and an essay
  costs the local agent more context than writing it would have.
- **Draft wide, then narrow.** For anything with a taste component, use
  `cpg-speculate` (four cheap drafts, one graded winner) rather than asking one
  model twice; the winner comes back as text you can edit.
- **Edit, do not adopt.** The reply is a draft with no access to the repo. Read
  it, check every claim, keep the sentences that are better than yours.
- **Record what won.** `speculate.sh` appends a ledger row per round; over a
  week that table says which model writes which kind of thing on this account
  far better than any benchmark does.

## Six one-prompt lanes

`scripts/task/cpg-review.sh` (behind `task agents:review:*`) is the advice lane
for the places one prompt buys more than it costs. Each is a single call, so 350
a day is not a budget to ration:

```bash
task agents:review:gate FILE=scripts/task/site-check.sh   # or: git diff HEAD
task agents:review:plate PROMPT_FILE=/tmp/plate.txt SIZE=1536x1024
task agents:review:plan  PROMPT_FILE=docs/proposal.md
task agents:review:schema FILE=.sops.yaml OUT=/tmp/schema.yaml
task agents:review:adversary FAIL=/tmp/fail.txt CODE=scripts/task/site-check.sh
task agents:review:draft   SHAPE=/tmp/step.yaml FILE=/tmp/material.md OUT=/tmp/step-out.yaml
```

- **gate** — a change to a check, before it ships. The question is not whether
the code is right but what input makes the check pass while the guarded thing is
broken. Ask it of a guard that has never been seen to fail; that is where the
vacuous pass hides.
- **plate** — a generation prompt, before the image is spent. The model cannot
see the plate, so it reads the request and names the defects to expect; one
prompt against a batch of twenty is the cheapest protection the image allowance
has.
- **plan** — a design doc or a proposal, before it becomes work. Ordered
objections with their cost, and the cheapest test that settles the first one.
- **schema** — a config, a manifest, a payload you are about to write a parser
for. It postulates the schema in YAML instead of prose, and the answer is only
accepted if it parses into the fixed shape with a non-empty `fields[]`: every
field cites its `evidence` from the sample, and anything the sample cannot settle
comes back under `open_questions` instead of hardening into a requirement.
- **adversary** — an assertion failure or a checkpoint, with the code that
asserts it. The call that turns a bad night into a good decision: what else the
evidence could mean, what the reading takes on trust, and the one probe that
settles it. YAML, so `could_mean[]` is worked through instead of skimmed.
- **draft** — a caller's skeleton plus the material. See the bridge below; this
is the lane a harness calls, not a person.

## Bridging a tool-calling harness and a drafting model

hermes is the harness: it holds the tool loop, a file, a shell, the cron. Its base
models (Nemotron 3.5 / 3) are weak drafters and cannot be swapped per task. The
models here are the opposite — they draft and structure better, and cannot call a
tool at all. So the split is not "one agent or the other":

- **hermes decides and executes.** It owns state, permissions, retries and the
  schedule. It never asks this lane to run anything.
- **this lane fills shapes.** `agents:review:draft` takes a skeleton the harness
  wrote and returns the same keys with real content, parsed and key-checked. The
  harness then reads fields by name with `yq` instead of re-parsing prose.
- **the artifact is the handoff.** A validated YAML file in the work directory is
  what crosses between them; neither side needs the other's conversation.

That is why the shape check matters more than the prose quality: a draft whose
keys do not match is refused, so the harness fails loudly instead of silently
consuming a plausible-looking wrong field.

Measured 2026-11-11: `claude-sonnet-5-5` and `gpt-6.1-sol` still answer `403
premium_only` on this pool, so the lanes default to `claude-haiku-5-5` with
`gpt-6-luna` as the one fallback; both answered a 5,000-character packet in
15-30 s. A premium id is a refusal in one second, not a slow call — check it
before naming it in a plan.

`DRY=1` prints the packet and sends nothing. `MODEL=` names the vendor; pick one
that is not the model whose work is under review. The packet is capped at 15,000
characters and the script refuses rather than truncating, so cut the material
rather than letting it be silently dropped.

## YAML in, YAML out

Ask these models for structured answers as YAML in a shape you name, never for
"a schema" in prose. The reply is cleaned by `scripts/task/llm-yaml.sh` — fence
lines, a leading "here it is" sentence, CRLF, a stray wrapping backtick — then
parsed, with `--map` rejecting the reply that is technically YAML because a bare
scalar is YAML. A `schema` or `adversary` answer that does not parse, or parses
into the wrong shape, exits 1: the shape is the contract, so "it looked right" is
not a result. Clean it in one script, never by eye at each call site.

## The loop: a validated command per turn

`scripts/task/cpg-loop.sh` (`task agents:loop:run`) is what makes these models
into an executor rather than an adviser. It asks for one command per turn in the
same YAML contract, refuses it against a deny list (delete, push, service
restart, decrypt, sudo, a pipe into a shell), runs it under `timeout` in a
scratch work directory — inside `bwrap` when that is installed, which on the
netbook it is not — and returns the exit status and the output tail to the next
turn.

```bash
task agents:loop:run GOAL=/tmp/goal.md STEPS=6 VERIFY='test -s out.txt'
task agents:loop:run GOAL=/tmp/goal.md DRY=1                       # first packet, no cost
bash scripts/task/cpg-loop.sh --check-command 'rm -rf /'          # deny list, no cost
```

A turn's answer is `thought`, `run`, `expect`, `stop`, and `stop: true` is a
request, not a result: the run exits 0 only when `VERIFY=` exits 0, and exits 4
with the goal unverified otherwise. The budget is the wall, not the step count —
one answered call costs about 7 of the 350 queries, so about 50 turns a day, and
the loop exits 6 rather than begin a turn the counter cannot pay for. Ledger and
per-turn actions land in `~/.cache/cpg-loop/<goal-slug>/` beside a lock file that
makes a second run refuse instead of interleaving.

There is no `crontab` on the netbook, and a scheduled goal is not an ad-hoc one:
the fleet's declarative path is `services.agentScheduler.jobs` on frieren
(`frieren-offload` skill), which is a deploy. Until a goal earns a job, run it in
a `tmux` session (`tmux` skill) so it outlives the shell.

## Use it for

- A design choice you are 60/40 on, where a second model's objection would change the decision.
- Adversarial review of something you wrote: a diff, a plan, a schema, a paragraph.
- Naming and wording when the first three attempts all read the same.

## Do not use it for

- Anything needing tools, the filesystem, the web or the current state of the host.
- Secrets, tokens, keys, private mail, or personal data. The prompt goes to a third-party web chat.
- A task you can simply do, or a question whose answer is in this repo.
- Authorization. A second model agreeing is not permission; a destructive step still goes through
  `confirm-before-destructive`.

## If it fails

- `not authenticated`: `~/.chatplayground/auth.json` (0600) holds a Clerk `__client` cookie
  harvested from a signed-in browser; it is not a sops secret because the session rotates. The
  hourly `chatplayground-refresh` timer keeps a live session warm but cannot resurrect a dead one:
  re-harvest from a browser instead of minting a token by hand. `cpg status --json` says whether
  the session is alive and how old the credential is.
- `Message cannot exceed 15,000 characters`: shrink or split the prompt. Do not retry it.
- `403 only available to active subscribers`: a premium id. Pick a free one from `cpg models`.

The `chatplayground-serve` unit on 127.0.0.1:8799 is for aichat's OpenAI-compatible client; this
skill never needs it.

## Routing the advice call with Jev

Jev is installed as a classifier: `jev-decide` (uv tool at `~/.local/bin/jev-decide`), with
`TYPESAFE_API_KEY` and `OPENROUTER_API_KEY` in `~/.hermes/.env`. It returns a label with
probabilities and never generates text, so it can route the call but cannot write the advice.

```bash
cat > /tmp/advice.json <<'EOF'
{
  "ask_another_model": "A second, independent model's opinion would change the answer or catch an error.",
  "do_it_locally": "The agent can settle this itself with tools and its own reasoning.",
  "review_my_work": "A claim, diff or plan that needs adversarial review before it ships."
}
EOF
jev-decide classify --provider typesafe \
  --text "Should I ask another model to review this 40-line Nix module before I switch?" \
  --criteria /tmp/advice.json
```

```json
{"decisions": {"category": {"status": "selected", "value": "ask_another_model",
                            "probability": 0.91, "margin": 0.86}}}
```

- `status: "selected"` with probability ≥ 0.8 is a routing hint; `"review"`, a null or a low
  margin means decide it yourself and move on.
- Route the **lane** (ask / review / skip), not the model. Jev cannot choose which provider
  answers a hermes turn — that is `fallback_providers` in `config.yaml`, resolved by the agent.
- `--dry-run` validates the request offline; it is not a judgment.
- One call is ~1 s and ~400 input tokens (measured 2026-11-06, `typesafe`).
- Never let a decision model approve a destructive action.

Related: `cpg-image` (same client, image generation).
