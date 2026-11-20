---
name: agent-browser
description: "Headless Chrome automation via agent-browser CLI."
version: 0.2.1
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [browser, chrome, automation, agent-browser, llm-agents]
    related_skills: ['nix-eval', 'agent-browser']
---

# `agent-browser` — headless browser automation for agents

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

### Authenticated pages (basic auth)

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
open …`), and clear the daemon between attempts because a stale one makes the
next launch queue behind it. A plain `agent-browser open https://example.com` is
the control that separates "the tool is wedged" from "that site is slow".

### Clearing the daemon: `-x`, never `-f`

`pkill -f agent-browser` kills the calling script. `-f` matches the whole
command line, and a wrapper script that names the tool — in an `ab() { …
agent-browser "$@"; }` helper, a `pkill` line, even a comment-free variable
assignment — carries that string in its own `/proc/<pid>/cmdline`, so `pkill`
selects its own parent. The whole run then exits 0 with no output, which reads
exactly like "the tool produced nothing". Two consecutive browser sweeps were
lost this way on 2026-11-20 before the cause was obvious.

```bash
pkill -x agent-browser   # matches the process NAME only, so a shell is never a target
```

Verified 2026-11-20: run from a script whose body contains the literal string,
`pkill -x` returned 1 (no daemon up) and the shell printed its next line. Note
`-x` stops the Rust CLI but not its chromium children — `close` is the clean
shutdown; `pkill -x chromium` is the blunt one.

### Downloads: a PDF link is two traps, not one

Verified 2026-11-20 against the CV links on `matt.bountystash.com` (headless
Chrome 157):

- The primitive is `agent-browser download <sel> <path>` — 34,886 B saved in
  0 s. Set `--download-path <dir>` (or `AGENT_BROWSER_DOWNLOAD_PATH`) as well: a
  bare `click` on a download link saves into `~/Downloads` under the server's
  filename, which looks like a timeout to any checker watching its own path.
- `open <pdf-url>` is the real hang. Headless Chrome has no PDF viewer, so the
  tab is blank — empty `document.title`, `bodyLength 0`, zero embeds — and a
  `snapshot` or `wait` after it has nothing to settle on. Never judge a PDF by
  navigating to it.
- The save happens only because the anchor carries `download=""`: Cloudflare
  Pages serves `Content-Type: application/pdf` with no `Content-Disposition`, so
the URL on its own displays rather than downloads. A link that loses its
`download` attribute still answers 200 and still looks fine to a link checker.

```bash
agent-browser --download-path /tmp/dl open https://host/page
agent-browser download 'a[download][href="cv.pdf"]' /tmp/dl/cv.pdf
head -c 4 /tmp/dl/cv.pdf        # %PDF, not an HTML error page
```

`scripts/task/cv-links-check.sh [base-url]` is that loop over the live site:
headers, a click per anchor, a `%PDF` magic byte test, `pdfinfo`, and a sha256
comparison against a built artifact (`ARTIFACT=/tmp/matt-site`).

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
- **Google account sign-in refuses headless, not automation as such.** Verified
  2026-11-15 with 0.43.0 on aarch64: `chromium --headless=new` gets as far as the
  email field and then answers `Couldn't sign you in — This browser or app may not
  be secure`; a desktop user-agent changes nothing. The same Chromium binary under
  `xvfb-run` is accepted, driven by CDP over `node`'s built-in `WebSocket`
  (`--remote-debugging-port`, then `Runtime.evaluate` + `Input.insertText`).
  `agent-browser` exposes no `--user-data-dir`, so anything needing a persistent
  login profile has to launch Chromium directly.
