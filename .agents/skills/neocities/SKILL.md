---
name: neocities
description: "Neocities blog: gum post authoring, drafts, render, deploy."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['neocities', 'blog', 'gum', 'static']
    related_skills: ['dev', 'checks']
---

# neocities — the dragon court outpost

| | |
| :--- | :--- |
| Live | https://dragoncourt.neocities.org |
| Source | `projects/neocities-dragoncourt/` |
| Control plane | `taskfiles/neocities.yml` → `scripts/task/neocities-blog.py` |
| Deploy | `task neocities:deploy` (= render → lint → upload → byte-compare) |
| Credential | `NEOCITIES.API.KEY` in `modules/secrets/apikeys.yaml` |

`task neocities:menu` is the whole surface as a gum TUI. Every item in it is a task of
its own (`:new`, `:edit`, `:publish`, `:draft`, `:delete`, `:render`, `:preview`,
`:deploy`), so an unattended path never depends on the menu.

## The one rule

A post is one HTML file with a one-line JSON header:

```html
<!--post {"title": "…", "date": "2026-10-30", "tags": ["court"],
          "status": "published", "summary": "…"}-->
```

Location decides status: `site/blog/<slug>.html` is published, `drafts/<slug>.html` is a
draft and is never uploaded (the push walks `site/` only). `neocities:render` reads the
headers and regenerates the four surfaces that would otherwise drift: the rows in
`site/blog/index.html`, the three cards on `site/index.html`, `site/feed.xml`, and the
entry count. **Those regions are generated — edit the post, not the listing.** The
markers are `<!-- entries:start -->`, `<!-- latest:start -->` and `<!-- count -->`.

Metadata edits go through the gum form, which rewrites the header, `<title>`,
description, canonical URL and `<h1>` together; editing the header by hand leaves those
four stale.

## Deploy

`task neocities:deploy` renders, then `scripts/task/neocities-push.sh` lints every
internal reference and the feed, asks `/api/upload_hash` which files differ, uploads only
those in one request, and downloads each uploaded path back to compare SHA-1. Exit 1 is a
failed round trip even when the upload replied `success`.

Deleting remote files is a separate, opt-in act: `neocities-push.sh --prune` lists what
has no local counterpart before removing it.

## Traps

- Neocities 301s `foo.html` → `/foo`. Internal links, canonical URLs and feed `<guid>`s
  use the extensionless form; a `.html` link is a redirect per visit.
- A markup edit is not a deploy: the site is only live after `neocities:deploy`.
- The landing page, about page and 404 are hand-written; they have no header and render
  ignores them.
- `drafts/` is created on demand and holds local state — it is not a published artifact.
