# Blog drafts: `ideas/` and the graph

A blog post starts as a knowledge-graph node, so the tree answers "what have I
already said about this" before a sentence is written.

## The draft file

`ideas/<slug>.md`, with a frontmatter block naming the entities the piece is
about:

```markdown
---
title: why the graph needed references
about:
  - doc:docs/closure-reduction.md
  - host:frieren
  - skill:knowledge-base
---
```

Three keys, parsed line-wise by `lib/knowledge-graph.nix` (the only parser since
the Elixir engine was retired, 2026-11-07). `about` entries are node ids —
`doc:<repo path>`, `host:<name>`, `skill:<name>` — and an id that does not exist
is not an edge: `edge endpoints resolve to nodes` in `kg-check` reports it.

Drafts are **not** documents. They are not in the `doc` set, so they cannot
answer a query meant for a finished page, and `checks:docs:links` treats them as
any other markdown. They are `idea:` nodes with `about:` edges, which is what
makes these work:

```bash
task ops:kg:blast TARGET=host:frieren                # includes the drafts about frieren
task ops:kg:blast TARGET=doc:docs/nix-patterns.md    # and the drafts about that page
```

## Creating one

```bash
task dev:blog:draft TOPIC="why the graph needed references"
```

It scores nodes against the topic's tokens, takes three seeds, walks two hops
out, and writes a skeleton whose `about` list and citation bullets come from the
walk — seeds, then up to six documents, three hosts, three skills. Hop 1 is the
obvious citation; hop 2 is the page that shares a host or a skill without
linking to the seed, which is where the disagreement usually is.

The script **stages** the file. A flake evaluates the git tree, so an untracked
draft would have no node and the promise above would be false until someone
remembered `git add`.

It does not search the vault or qmd — qmd is not installed on every host — and
the skeleton prints the two `qmd search` commands to run where it does.

## The banner

A post's hero is not a file in that repo. It is a Cloudinary public id, and the
crop lives in the delivery URL:

```bash
task images:post SLUG=why-the-graph-needed-references TITLE="Why the graph needed references"
```

One motion, in this order: the brief goes to `cpg image`, `agy` judges the plate
and a named defect buys one re-roll, ffmpeg crops 1200x630, the JPEG is uploaded
as `assets/blog/<slug>`, the manifest is rebuilt and the asset frontend
redeployed, and only then is `_posts/<day>-<slug>.md` written with that URL in
`image:`. The banner exists before the file does, so a post cannot ship with a
hero that 404s, and no JPEG enters either tree.

`PUSH=0` is the default: the file is committed, the push is yours, because that
repo's CI deploys on push. `PROMPT=` overrides the default banner brief,
`TAGS=`/`CATEGORIES=` set the blog's vocabulary, and `FORCE=1` rewrites the front
matter of an existing post while keeping its body.

The banner is searchable the moment it uploads: `images:publish` writes the
manifest with a lane, a day and tags per asset, and Pages serves a small frontend
that fuzzy-searches and filters it. The bytes never leave Cloudinary, so the
deploy stays a few KB however large the bank gets.

## Publishing one

```bash
task dev:blog:export SLUG=why-the-graph-needed-references
```

Writes `BLOG_REPO/_posts/YYYY-MM-DD-<slug>.md` in the blog's own front matter
(`layout: post`, title, date, author, `categories: [Blog]`, tags) with the body
copied verbatim, then stops. Default checkout is `~/Documents/shaoyanji.is-a.dev`;
`BLOG_REPO=` points elsewhere, `BLOG_AUTHOR=` overrides the blog's `matt`
default. Categories and tags are that blog's vocabulary — set them there
(`task post`) — and a `tags:` line in the idea frontmatter is carried across.

It never commits and never pushes: that repo's CI deploys on push, so
publication stays an operator decision, and an unattended run cannot make it.
It does not make a banner either — run `task images:post` for that, which writes
the same front matter with the hero already on Cloudinary.

## Two traps

- **The site renders every node.** `lib/aki-site.nix` builds a page per graph
  node, so a draft's *title* appears on the fleet docs site; its body does not
  (only `doc` and `skill` nodes carry text). Keep an unpublished headline out of
  `title:` if that matters — the slug is used when the title is blank.
- **A draft is not a doc, and the gates know it.** `ops:docs:budget` covers the
  living documents and the link scan treats a draft as one more markdown file.
  Reachability is the compiled site index now, which lists every graph node, so
  nothing has to link to a draft for the tree to stay green.
