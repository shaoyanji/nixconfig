name: parallel-cli
description: >-
  Use this skill for Parallel web intelligence from agents — AI web search,
  deep research, URL extraction to clean markdown, entity discovery
  (FindAll), continuous monitors, and task/monitor recall memory. Requires
  one-time `parallel-cli login` (device OAuth) and prepaid balance.
---

# `parallel-cli` — Web Search / Research / Monitoring for Agents

Managed web-intelligence CLI: AI search, open-ended deep research, clean
markdown extraction from URLs, entity discovery, and change monitoring.
Cloud-backed — check auth/balance before assuming failure is a bug.

## 1. Auth first

```bash
parallel-cli auth        # status
parallel-cli login       # device OAuth flow
parallel-cli balance     # prepaid credit (billed service)
```

## 2. Core commands

```bash
parallel-cli search "best arm64 VPS 2026"      # AI-powered web search
parallel-cli research "compare NixOS CI providers"   # deep research report
parallel-cli extract https://example.com/post  # URL -> clean markdown (alias: fetch)
parallel-cli findall "vendors selling X"       # discover entities from natural language
parallel-cli monitor create ...                # watch a page/topic for changes
parallel-cli memory ...                        # recall saved tasks/monitors/findall results
```

## 3. Agent patterns

- Prefer `extract` over raw `curl` for web pages: returns LLM-clean markdown
  (boilerplate stripped), saves tokens and quoting pain.
- Use `research` for open-ended multi-source questions; use `search` for
  quick lookups; use `findall` to enumerate candidates (vendors, tools).
- Combine with `pdfvision` when a result is a PDF, and `ai-memory` to persist
  findings: `parallel-cli extract <url> | ai-memory write-page --path research/<topic> -`.
