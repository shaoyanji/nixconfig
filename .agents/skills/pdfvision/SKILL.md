name: pdfvision
description: >-
  Use this skill when an agent needs to read, extract, or convert PDF
  documents — text extraction, quality-aware re-reads, term search with
  bounding boxes, region rendering as image evidence, and a built-in MCP
  server (`pdfvision mcp`) for editor/agent integration.
---

# `pdfvision` — PDF Understanding for Agent Pipelines

Extract text, images, metadata, and layout from PDFs for AI agents. Reports
per-page quality and names the next flag to use when the default pass is not
enough (e.g. scanned pages need `--ocr`). Pairs with `officecli` for Office
formats; pdfvision is the PDF-side tool.

## 1. Common flows

```bash
pdfvision doc.pdf                          # read; page quality + warnings guide next steps
pdfvision doc.pdf --search "term" --matches-only
                                           # locate a term without reading everything;
                                           # each match reports page + bbox
pdfvision doc.pdf -p 3 --render-region 100,200,500,300
                                           # crop a reported bbox as image evidence
pdfvision doc.pdf -p 4,5 --ocr             # re-read scanned pages (quality: empty_but_visual_content)
pdfvision --remote https://example.com/x.pdf   # fetch and process a remote PDF
pdfvision --clear-cache                    # drop cached extractions
```

## 2. Agent strategy

1. Default pass first (`pdfvision doc.pdf`), read the per-page quality notes.
2. Long docs: `--search` + `--matches-only` to navigate, then read target
   pages with `-p <page>`.
3. Visual/scan problems: use the exact flags the warnings suggest (`--ocr`,
   `--render-region`) instead of re-reading blind.
4. Evidence for claims: render the bbox of the matching text as an image.

## 3. MCP integration

`pdfvision mcp` exposes extraction over Model Context Protocol — add it to
Zed context_servers or hermes the same way as ai-memory's server.
