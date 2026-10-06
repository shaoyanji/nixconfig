name: officecli
description: >-
  Use this skill when an agent must read, edit, or create Microsoft Office
  documents (.docx / .xlsx / .pptx) without Microsoft Office — OfficeCLI is
  a single-binary suite purpose-built for AI agents, with a built-in MCP
  server exposing all document operations. Primary fleet use: producing
  DOCX résumés/cover letters in the antigravity-application-workflow.
---

# `officecli` — Office Suite for AI Agents

Reads, edits, and automates Word, Excel, and PowerPoint files. Single
binary, no Office/LibreOffice dependency. Includes an MCP server
(`officecli mcp`) that exposes every document operation as tools.

## 1. Status on this fleet

- Packaged as `pkgs.llm-agents.officecli` (llm-agents overlay) but NOT yet
  in any host's package list — add `pkgs.llm-agents.officecli` to
  `modules/user/ai/default.nix` (or a host profile) to install.
- Until then, run on demand: `nix run github:numtide/llm-agents.nix#officecli -- --help`
  (name resolution may differ; `nix search github:numtide/llm-agents.nix officecli`).

## 2. Document operations

```bash
officecli --help                      # full command surface (read/edit/create per format)
officecli docx read resume.docx       # extract content
officecli docx edit resume.docx ...   # targeted edits
officecli xlsx ...                    # spreadsheets
officecli pptx ...                    # presentations
officecli mcp                         # MCP server (stdio) for Zed/hermes integration
```

(Exact subcommand syntax may vary by version — always consult
`officecli --help` for the installed build.)

## 3. Job-application pipeline (primary use)

In `/Volumes/data/projects/antigravity-application-workflow`, résumés and
cover letters are built from Typst. OfficeCLI closes the gap for recruiters
that demand DOCX:

1. Render the canonical document (Typst → PDF as today).
2. Use `officecli docx create/edit` to produce the .docx variant from the
   same structured content (job-specific keywords via the workflow's JEV
   engine).
3. QA: `officecli docx read` the output back and diff against the source
   content before sending.
