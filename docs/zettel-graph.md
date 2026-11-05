# Zettel graph

The vault in a browser: one note at a time, its `[[links]]` as a force-directed
web, a fuzzy finder over the whole box — plus write and publish when a host
serves the page rather than a folder opening it.

```
https://delphi.cloudforest-kardashev.ts.net:8453        # tailnet only
```

Why it is here and not in the vault: the reader is a private repo, the vault is
a private repo, and nothing about either belongs in the Nix store. delphi holds
both as working trees under `/var/lib/zettel-graph`, fetches them with the
fleet's GitHub token, and serves what the vault's own exporter produces.

## The units

| unit | what it does |
| --- | --- |
| `zettel-graph-sync` | oneshot: fetch both repos, fast-forward or push the vault, export `graph.json`, copy the page into `www/` |
| `zettel-graph-sync.timer` | the same every 15 minutes, so the page tracks the vault without a deploy |
| `zettel-graph` | the loopback listener on `:8083`: the static page plus `/api/*`; the tailnet mount proxies it |

`services.zettelGraph` (`modules/services/zettel-graph.nix`) owns all of it; the
host file only enables it and reads `tailnetHost` from the service portal so the
mount card and the write guard cannot disagree.

## What is served

```
/                 the reader (index.html from the frontend repo)
/graph.json       an export by <vault>/scripts/export_graph.py — the vault's own
                  link resolution and cluster rules, not a second copy of them
/api/health       {notes, links, vault HEAD, write, publish}
/api/note/<id>    the real file, frontmatter included
/api/new          POST {title, type, tags} -> the vault's create_note.py
/publish/<x>.pdf  a rendered PDF
```

`<id>` is the export's id — the vault-relative path without `.md`
(`zettels/2026…-slug`); an explicit `.md` is accepted too. The three writable
directories are `zettels/`, `010 - MOCs/` and `journal/`; anything else is
refused, as is a path that resolves outside the vault.

## Writing

`POST /api/new` captures a note: the form sends a title (and optionally a type and
tags), the vault's `create_note.py` decides the timestamped filename and the
schema-v2 frontmatter, and the result is committed and pushed like an edit
before the page opens it for writing. Only `zettel` and `moc` are offered — the
other types target `zettels/notes` and `zettels/ideas`, which the id shape this
service writes does not cover, and a button that 400s is worse than two buttons.

`PUT /api/note/<id>` with `{"text": "<whole file>"}` writes atomically, commits
in the checkout (`zettel-graph: edit <path>`), pushes to the vault branch, and
re-exports the graph. `POST /api/publish` runs the vault's `publish_md.py`, so
the PDF comes out of the same template and presets the vault already uses.

Two headers make a write a write: `X-Zettel-Write: 1`, and — when the browser
sends one — an `Origin` equal to `https://<tailnetHost>:<tailnetPort>`. A public
page can send a cross-site request at a tailnet address without reading the
answer; the pair is what stops that. There is no second credential: the listener
is loopback and `tailscale serve` is the fence.

The page asks `/api/health` once at boot. When it answers, `e` opens the **file**
rather than the export's body — the export strips frontmatter, so writing the
body back would delete a note's title and tags — and `⌘S` saves. A folder with
no service keeps the old scratch behaviour and says so.

## The token

`sops.secrets."zettel-graph/github-token"` reads `ghsudo` from
`modules/secrets.yaml` and reaches the units as a systemd `LoadCredential`, so
it is never in argv, `.git/config`, or the store. It is **not** the `GITHUB`
entry in `modules/secrets/apikeys.yaml`: that directory is a submodule outside
the flake, and delphi builds from a GitHub tarball that carries only the
gitlink, so a `sopsFile` pointing at it is a path that does not exist in the
store.

The token needs read access to both private repos; push access to the vault is
what makes a page write land on the other machines.

## Traps

- **`Origin` carries the mount port, not the loopback one.** 8453 is the
  `tailscale serve` port; the service listens on 8083. The module takes both,
  and the portal mount reads `tailnetPort` rather than repeating the literal.
  (8452 was the first choice and is occupied by another project.)
- **The sync must never `reset --hard` the vault.** A page write leaves a local
  commit; the timer merges forward, or pushes when the tree is ahead. A tree
  that has diverged is left alone and named in the journal — losing a note to a
  timer is the one failure this service cannot have.
- **A failed export keeps the previous `graph.json`.** The exporter writes a
  temporary file and it is moved into place only on success.
- **A failed fetch does not take the page down.** The daemon `Wants`, not
  `Requires`, the sync unit: the last good tree keeps serving.
- **A bad reader release** is held back by `services.zettelGraph.frontend.ref`
  — a branch or a commit; `fetch` leaves it in `FETCH_HEAD` either way.

## Checking it without building a host

```bash
nix eval --raw .#nixosConfigurations.delphi.config.systemd.services.zettel-graph.serviceConfig.ExecStart
nix eval --json .#nixosConfigurations.delphi.config.services.servicePortal.cards
nix eval --json .#nixosConfigurations.delphi.config.assertions \
  --apply 'as: map (a: a.assertion) as'
```

The same code runs by hand against a scratch vault:
`modules/scripts/zettel-graph-server.py --www … --vault … --origin …`.
