---
name: antigravity
description: "Delegate coding to agy, Google's Antigravity CLI (1.5.9): --settings '{\"modelProvider\":\"gemini\"}' --model gemini-4-hydrogen-high --output-format json -p '<prompt>'. The settings flag is what makes the Gemini 4 models exist at all."
version: 0.2.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [Coding-Agent, Antigravity, Google, AI-Agent, Delegation]
    related_skills: [frieren-offload, agents, prove-it-works]
---

# Antigravity CLI (agy)

Delegate a bounded coding task and read one JSON object back. The model list is
provider-scoped: without `--settings`, `agy models` offers Gemini 3.8 Flash,
Claude Sonnet/Opus and GPT-OSS; the Gemini 4 family (carbon, hydrogen, argon)
exists only under `--settings '{"modelProvider":"gemini"}'`.

## Getting a binary

`agy` is on-demand — no host profile installs it (HM manages only the settings
at `~/.gemini/antigravity-cli/`). Run it fresh:

```bash
nix run github:numtide/llm-agents.nix#antigravity-cli -- -p "Hello!"
```

The exceptions that carry their own pinned copy: the agentScheduler cascade
(`agy -p` by store path), `agy-gemini` and `agy-subagent` — the headless lanes
below. This convention is for an interactive or ad-hoc shell.

## The invocation

```bash
agy --settings '{"modelProvider":"gemini"}' \
    --model gemini-4-hydrogen-high \
    --output-format json \
    -p "Hello from Hydrogen!"
```

Measured 2026-11-17 on 1.5.9: 97 s and 18 661 tokens for a one-line answer, against
2.7 s on the default model for the same prompt. The pair travels together — drop
the settings and the call exits 1 with
`{"status":"ERROR","error":"… model gemini-4-hydrogen-high is not recognized as a known model or custom model in settings"}`.

Ask agy itself which models the provider has, with the same settings you intend
to use — the bare list is a different one:

```bash
agy --settings '{"modelProvider":"gemini"}' models
# gemini-4-carbon-{high,medium,low} · gemini-4-hydrogen-{xhigh,high,medium,low}
# gemini-4-argon-{high,medium,low} · gemini-3.8-flash-{…} · gemini-3.1-pro-{high,low}
```

`--effort low|medium|high|xhigh|max` is a second axis; a Gemini 4 id already
carries an effort, and `--settings` validates its values (an unknown provider is
an error, not a fallback).

## Install and defaults

- `agy` is `pkgs.llm-agents.antigravity-cli` from
  `modules/user/ai/antigravity-cli.nix`; on a nixconfig host that is
  `/etc/profiles/per-user/devji/bin/agy`. Elsewhere:
  `nix run github:numtide/llm-agents.nix#antigravity-cli -- <args>`.
- Never `npm install -g antigravity-cli`: different binary name, and it writes
  outside the store.
- The fleet default model is the module's `$GEMINI_MODEL` (`gemini-3.8-flash`).
  `agy` has no model env var of its own — pass `--model` explicitly, and read the
  module rather than assuming a version.
- Under the hermes gateway the unit exports `AGY_CLI_DISABLE_AUTO_UPDATE` and
  `GEMINI_MODEL`; a login shell gets them from Home Manager.

## Flags that matter

| flag | meaning |
| :--- | :--- |
| `-p`, `--print`, `--prompt` | run one prompt non-interactively and print the answer. **Not** skip-permissions |
| `--settings '<json>'` | `settings.json` keys for this session only, never saved; `modelProvider` is the one that changes the model list |
| `--model <id>` | model for the session; must be one the selected provider lists |
| `--output-format text\|json\|stream-json` | `json` gives `{conversation_id,status,response,duration_seconds,num_turns,usage}` |
| `--dangerously-skip-permissions` | auto-approve every tool call. Long form only, no short alias |
| `--mode plan\|auto\|accept-edits` | `plan` answers with a plan and a question, which is never what a headless caller wants |
| `--json-schema <inline-json-or-path>` | enforce a shape on the final answer |
| `--print-timeout <duration>` | limit on print mode (`180s`); `0` waits for the turn |
| `--input-format stream-json` | one NDJSON message per line on stdin, requires `--output-format stream-json` |
| `--effort`, `--agent`, `--project`, `--add-dir`, `--sandbox` | effort, agent, project, extra workspace dirs, sandboxed tools |

Re-read `agy --help` after an upgrade; this table is what 1.5.9 prints.

## The wrapper subagents call

`agy-subagent`, declared by `modules/user/ai/antigravity-cli.nix`, pins the model
and provider pair and the JSON form, so a parent parses a result instead of
scraping a TUI:

```bash
agy-subagent 'Add a dark mode toggle to settings' --mode plan --dir ~/project
agy-subagent 'Summarise the failing tests' --schema /tmp/schema.json --dir ~/repo --toon
```

It exits 2 outside a git work tree, on a missing argument, and on the default route
with `GEMINI_API_KEY` unset. `AGY_SETTINGS` (default the Gemini provider) and
`AGY_SUBAGENT_MODEL` (default `gemini-4-hydrogen-high`) set the pair,
`AGY_SUBAGENT_TIMEOUT` the 900 s cap; stdout is agy's JSON.

Hydrogen is the default for delegated work and it is an API-key model: the
consumer OAuth account lists no Gemini 4 id at all, so a run without the key
cannot fall back quietly. Pass `AGY_SETTINGS='{}'` (and an account model) when a
call really does belong on the OAuth route. Interactive `agy` stays on the
account route with `$GEMINI_MODEL`, because the provider setting is session-only
by design. `--toon` projects it through `toon -e` — for a record
array, not for the single nested object a conversational answer returns.

## The Gemini API key route

`agy-gemini` is the shared implementation: the provider setting, the hydrogen
default and the `GEMINI_API_KEY` preflight live there, and `agy-subagent` and a
hand-written call go through it. The host cascades do not: a nightly sweep is many
requests, the free tier is ~20 a day, so Tier 1 runs plain `agy` on the account
route with `--model gemini-3.8-flash`. For one delegated task:

```bash
agy-gemini -p 'hello'                       # gemini-4-hydrogen-high, print mode
agy-gemini models                           # what the key unlocks
agy-gemini --model gemini-4-carbon-high -p 'review this diff'
```

It requires `GEMINI_API_KEY` and adds `--settings '{"modelProvider":"gemini"}'`
for that session only, so the Pro account route stays the default and the
HM-owned `settings.json` is untouched. Do not put `modelProvider` in
`settings.json` to get this: it replaces the account route for every run on the
host, not just the one that wants Hydrogen.

Prefixed ids matter. `gemini-4-hydrogen` (unsuffixed) answered
`503 UNAVAILABLE — high demand` after 84 s on the same key and minute that
`gemini-4-hydrogen-high` answered normally, so pin a suffixed id.

Budget is the real constraint, not latency. The free API tier allows a handful of
requests per minute and about 20 a day per project (the live numbers are in AI
Studio), and one agent turn is one request plus retries: a trivial print run
measured 17 226 input tokens. A 429 carrying `quota_exceeded` ends the day, while
`rate_limit_exceeded` clears in seconds. A long sweep belongs on the account
route or a billed project.

## Direct call

```bash
cd ~/project
agy --settings '{"modelProvider":"gemini"}' --model gemini-4-hydrogen-high \
  --dangerously-skip-permissions --output-format json --json-schema schema.json \
  --mode accept-edits --print-timeout 180s -p 'Add dark mode toggle to settings'
```

Scratch work still needs a git work tree:

```bash
d=$(mktemp -d) && cd "$d" && git init -q .
```

## Long tasks

Print mode returns when the turn ends, so anything past the wrapper's timeout
belongs in a detached session (`tmux` skill) with the JSON written to a log. A
detached session has no TTY to approve a tool call, so there
`--dangerously-skip-permissions` is mandatory, and `--mode plan` is the one mode
that will stop and wait for an answer that nobody will type.

## Auth and hosts

Two routes, two credentials. The account route uses the per-user OAuth token at
`~/.gemini/antigravity-cli/antigravity-oauth-token`; a second host reuses it
(`install -m600` or a symlink) instead of signing in again. The API-key route
reads `GEMINI_API_KEY` only when the session says `modelProvider=gemini` — with
the key exported and no provider, agy signs in with the account and ignores it
(measured 2026-11-17: `agy models` with the key listed only account models, and
the same call under the provider listed the Gemini 4 family). That route needs no
OAuth session and bills the key's project rather than the plan. A CPU without
RDRAND cannot run agy at all: `hosts/fern/configuration.nix` disables the module
and the host uses `agy-remote` against frieren. `AGY_CLI_DISABLE_AUTO_UPDATE` is
set by the module, because the self-updater writes to `~/.local/bin` where a
store path owns the binary.

## Rules

1. `--model` and `--settings` travel together for anything newer than the default list;
   only the pair resolves.
2. `-p` is `--print`. Skip-permissions is spelled out in full.
3. A rejected model exits 1 with `{"status":"ERROR"}`, and a produced JSON carries
   `status`: read it, do not infer success from a silent stderr.
4. Run inside a git work tree — agy refuses to start outside one.
5. `--mode plan` is for human review; a headless caller wants `accept-edits` or a schema.
6. Report the exit code, `status`, `duration_seconds` and `usage` — a turn that ran
   is not the same claim as a turn that produced the artifact.

Truth: `modules/user/ai/antigravity-cli.nix` — the module and the wrapper; this page is the procedure.
