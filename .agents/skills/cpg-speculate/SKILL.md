---
name: cpg-speculate
description: Speculative rounds — four cheap models answer in parallel, Jev grades, one winner comes back. Uses the prompt budget, not the image allowance.
version: 1.0.0
tags: [ai, chatplayground, jev, sampling, routing]
platforms: [linux, macos]
---

# cpg-speculate

A speculative round: N cheap lanes answer the same question at once, Jev picks
the best, and the caller reads one answer. The main agent spends its context on
the winner instead of on four drafts. The client it drives is declared in
`modules/user/ai/hermes-user.nix`.

```bash
.agents/skills/cpg-speculate/scripts/speculate.sh \
  "In two sentences: when should a NixOS module use mkDefault instead of mkForce?"
# → the winning answer, nothing else
# stderr: speculate: 4 lanes, Jev chose c0 (gpt-6-luna) p=0.94 m=0.88 [selected]
```

`--json` returns `{question, candidates, decision, winner:{label,model,text}}`.
`--all` adds `all: [{label, model, chosen, text}]` and, without `--json`, prints
every lane under a `--- cN (model)` header with the chosen one marked. It exists
because the winner alone discards the evidence: a Jev verdict at p=0.65 with a
0.48 margin is `needs_review`, and a reader deciding something irreversible wants
the other three answers rather than a draft with no priors. Without the flag the
output is unchanged.

## Why the budget allows it

Measured with `cpg usage` (2026-11-11): `dailyQueryCap` 350 prompts per day and
`compareSlots` 4, so four concurrent streams. `unlimitedQueries: true` and the
monthly `pro` counter are the plan's name, not the day: 350 is the cap. One
four-lane round is four prompts and zero image allowance, and the concurrency cap
is exactly four, so a round is the largest fan-out the plan serves without
queueing.

- 350/day ÷ 4 = **87 rounds a day**. No hourly counter is in the payload, so a
  429 is a burst refused: space the round out rather than retry into it.
- Jev grading is not a prompt: it is a Typesafe call, ~1 s, and its input is the
  candidates (2,000 characters each).

## The context packet — these models have no tools

A lane is a chat completion: no filesystem, no clock, no repository, no memory
of this conversation. Anything it is not told, it invents. So the round takes a
packet, and the packet is the whole world the model gets:

```bash
speculate.sh --label "storybook dedication" --context /tmp/sb-context.md "…"
```

The script prepends it as `CONTEXT — facts you cannot look up; treat as given`.
Rules that keep it useful:

- **Under 1,500 characters.** The prompt cap is 15,000 per lane; a packet that
  fills it leaves no room to answer. Facts only — names, invariants, the current
  state, the constraints. No instructions (those belong in the question).
- **State today's date and the host** when the question can turn on them.
  "Latest release" without a date is a hallucination with a timestamp.
- **Restate what the model cannot see**: the repo's conventions, the schema it
  must satisfy, the audience. A model that is told the audience writes for it.
- **One packet per project, reused across rounds.** Rewriting it per round is
  how two lanes end up answering different questions.

This is the lever that makes a cheap lane worth its prompt: the packet supplies
what the model lacks, so its quality — not its context window — is what shows.

## The winner ledger

Every graded round appends one JSONL row (default
`~/.local/state/cpg-speculate/winners.jsonl`):

```bash
jq -r '[.label, .winner_model, .probability, .status] | @tsv' \
  ~/.local/state/cpg-speculate/winners.jsonl | sort | uniq -c | sort -rn | head
```

That table is the only answer to "which model should write this?" that survives
more than a week. `CPG_SPECULATE_LEDGER` or `--ledger PATH` retargets it;
`--no-ledger` is for experiments that would pollute the record.

`--xs SUBJECT` also posts one fleet turn per round (`SOURCE=cpg-speculate.<model>`),
so the winners are visible to the other agents. Use it for rounds that produced
work; skip it for smoke tests, or the turn log becomes a prompt dump.

## What the grader is, and is not

The script grades with `jev-decide decide` over a `choice` question whose
criteria are the candidate labels. That is a classifier, not a model writing a
review: it returns a label, a probability and a margin.

`needs_review` is a draft signal, not a veto — the script still emits that top
choice and says so on stderr. Read the `p=`/`m=` line before trusting a round
where the winner was close.

A "Sonnet 5.5 grader" is not available on this plan: 10 of the 11 premium ids
answer `403 only available to active subscribers` on the lifetime pool, and
`claude-sonnet-5-5` is one of them. The only premium id measured to answer is
`gemini-3.8-flash`, and adding it as a fifth lane costs a prompt while leaving
Jev as the decider. Re-test when the plan changes (`cpg usage`).

## Default lanes

`gpt-6-luna`, `mimo-v2.6-pro`, `gemini-3.8-flash-l`, `deepseek-v4-pro` — all
basic-tier, all served on this account, deliberately different vendors. Override
by passing model ids after the question; a lane that 403s or times out is
dropped and the round continues on the rest.

Pick lanes for disagreement, not for a leaderboard: the value is that four
different models rarely fail the same way.

## When to run a round

- A design trade-off where a wrong, confident answer is expensive.
- Diagnoses with several plausible causes: four independent reads are a cheap
  differential.
- Naming, wording and framing, where the first idea is usually the obvious one.

Not for: anything needing tools, files or the web (no lane has them), a question
you can settle yourself, or a long document — the 15,000-character prompt cap is
per lane and the script does not chunk.

## Pacing a long project

Rounds are the unit to plan in, not prompts:

- 200 rounds is about 2.7 hours at 75/h, ignoring burst windows.
- A burst of 12 rounds (48 prompts) exhausts the ten-minute window; space rounds
  or accept the wait instead of retrying into a 429.
- Check the window before a batch: `cpg usage --json | jq '.entitlement.rateLimits.prompt'`.
  The counters there are prompts sent, not rounds.

## Failure behaviour

- One lane dies → dropped, round continues (`speculate: <model> produced nothing …`).
- All lanes die → exit 1, nothing emitted.
- One lane survives → emitted as-is, no Jev call spent on a one-option choice.
- Jev fails → the first surviving lane is returned with a warning on stderr.

Related: `cpg-advice` (single lane), `cpg-image` (the other budget), `jevdecide`
(the grader's contract).
