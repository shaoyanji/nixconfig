---
name: agent-browser
description: "Headless Chrome automation via agent-browser CLI."
version: 0.2.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [browser, chrome, automation, agent-browser, llm-agents]
    related_skills: ['nix-eval', 'agent-browser']
---

# `agent-browser` — Headless Browser Automation for Agents

Rust CLI over headless Chrome built for AI agents. Instead of CSS selectors,
it takes accessibility-tree **snapshots** and addresses elements by stable
refs (`e1`, `e2`, ...), producing compact text output that minimizes context
usage. Default is headless; switch to headed for debugging.

## 1. Getting the binary (it is usually NOT installed)

The package is `pkgs.llm-agents.agent-browser` from numtide's llm-agents.nix,
and it is installed only on the `full` AI tier (`modules/user/ai/default.nix`) —
its closure carries its own Chromium (~700 MiB), which is why light hosts leave
it out. Absence is not a blocker: the flake is prebuilt on `cache.numtide.com`,
so a cold `nix shell` is ~17 s and a warm one is instant.

```bash
nix shell --option builders "" github:numtide/llm-agents.nix#agent-browser \
  -c agent-browser open https://example.com
```

Inside this repo the same flake is an input (`flake.nix` → `llm-agents`, wired
as the `pkgs.llm-agents` overlay in `flake/module-sets.nix`), but the output set
is `packages.{artifacts,cli,servers,sites}` — there is no passthrough, so an
ad-hoc run still goes through `github:`. On a `full`-tier host it is simply
`agent-browser` on PATH.

`--option builders ""` keeps the invocation off nixbuild.net: a cache hit costs
nothing, a compile would bill the free tier.

### Authenticated pages (Basic auth)

Chrome drops credentials embedded in a URL, so send the header yourself. It is
scoped to that origin for the session:

```bash
B64=$(printf 'user:password' | base64 -w0)
agent-browser open https://host/admin/ \
  --headers "{\"Authorization\":\"Basic $B64\"}"
```

Verified 2026-10-30 against a Basic-auth admin UI: the snapshot came back with
the authenticated page, not a 401.

### When `open` appears to hang

Observed 2026-10-30: on some runs `open` spawns the wrapped chromium and then
sits with no output for minutes. Bound every call (`timeout 60 agent-browser
open …`), and clear the daemon between attempts — `pkill -f agent-browser` —
because a stale one makes the next launch queue behind it. A plain
`agent-browser open https://example.com` is the control that separates "the
tool is wedged" from "that site is slow".

## 2. Core loop (snapshot → act by ref)

```bash
agent-browser open https://example.com       # launch + navigate
agent-browser snapshot                        # a11y snapshot with element refs
agent-browser click @e12                      # act on a ref from the snapshot
agent-browser fill @e4 "search terms"         # type into a field
agent-browser screenshot /tmp/shot.png        # visual evidence
agent-browser get text @e7                    # read element text
agent-browser close
```

Headed for debugging: `agent-browser open --headed <url>`.

## 3. Agent patterns

- Always `snapshot` immediately after navigation or actions — refs are
  stable within a snapshot generation and re-printed on change.
- Prefer `get text` over screenshots for data; use screenshots only when
  layout/visuals matter (then read them with a vision-capable model).
- For PDFs found while browsing, hand off to `pdfvision --remote`.
- Persist a browse session's findings into `ai-memory` when the task is
  research-shaped.
- When a site blocks automation or needs login, prefer `extract` from
  `parallel-cli` (clean markdown, no browser) before fighting the browser.
