---
name: agent-browser
description: "Headless Chrome automation via agent-browser CLI."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [browser, chrome, automation, agent-browser]
    related_skills: []
---

# `agent-browser` — Headless Browser Automation for Agents

Rust CLI over headless Chrome built for AI agents. Instead of CSS selectors,
it takes accessibility-tree **snapshots** and addresses elements by stable
refs (`e1`, `e2`, ...), producing compact text output that minimizes context
usage. Default is headless; switch to headed for debugging.

## 1. Prerequisites

- `chromium` is installed alongside (fleet-wide in
  `modules/user/ai/default.nix`). First run may need `--no-sandbox` inside
  exotic sandboxes; on NixOS the wrapped chromium handles patching.

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
