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

`cpg models` lists what the session can see (34 ids on 2026-11-06). Only the free tier answers:
premium ids (`gpt-6.1-sol`, `claude-sonnet-5-5`, `kimi-k3`, `qwen3.8-max`, `glm-5.3`) return
`403 only available to active subscribers`, so listing one is a trap.

The value here is independence, not a ranking. Pick a different vendor from the model you are
running on, and stay with an id whose answer you have already judged. Ids exercised on the free
tier on 2026-11-06: `gpt-6-luna`, `claude-haiku-5-5`, `deepseek-v4.1-flash`, `gemini-3.8-flash-l`,
`kimi-k2.6`, `qwen3.7-plus`, `glm-5.3-flash`, `grok-4.7`.

## Machine surfaces

`models --json` and `status --json` are the parseable forms. The catalog keeps
the entitlement fields, so the free tier is a filter instead of a memory:

```bash
cpg models --json | jq -r '.[] | select(.premium_only | not) | .id'
cpg status --json | jq -e '.authenticated'
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
