---
name: envs
description: "Envs.net Debian hosting: SSH, web, Gemini, Gopher."
version: 0.1.2
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['envs', 'debian']
    related_skills: []
---

# envs — the pubnix, and the pipeline its site needs

| | |
| :--- | :--- |
| Host | `envs.net`, Debian 13 trixie, alias `envs` |
| Web | `https://jisifu.envs.net` → `~/public_html` (nginx + PHP 8.4; also `https://envs.net/~jisifu`) |
| Gemini | `gemini://envs.net/~jisifu` → `~/public_gemini` |
| Gopher | `gopher://envs.net/1/~jisifu` → `~/public_gopher` |

The capsule and the gopher hole are served by path, not by vhost: `gemini://jisifu.envs.net`
answers `53 …proxy requests`, and `jisifu.envs.net:70` returns the banner instead
of your gophermap. Use the `~jisifu` forms (measured 2026-11-02).

The web address is the same shape: the site links to `https://envs.net/~jisifu/`,
and the builder emits every internal `href`/`src` absolute under that prefix
(`SITE_BASE`; empty for a site that owns its domain root). `public_html` carries
a `~jisifu -> .` self-link so the vhost answers those paths too — `publish.sh`
recreates it after each web-root swap and then fails unless both addresses
answer 200. Remove that link and every page loads unstyled with a nav pointing
off the site, which is what the tilde address looked like on 2026-11-05.

The content is markdown; the site is generated in its own private repository,
`~/Documents/envsdotnet` (override `ENVS_SITE_REPO`). Nothing on the host builds
any more: the PHP generator, the validators and the SRS export are retired.

`task envs:build` runs the builder locally: markdown to finished HTML, gemtext,
a gopher menu and the finger plan, then the hard assertions (one `h1` per page,
ISO dates that are not in the future, every post carrying its three mirrors,
both protocol roots listing every post) and the 14 KiB page budget under
`--strict`. `envs:publish` builds and rsyncs all four targets, moving the old
web root to `public_html.bak-<stamp>` first. `envs:report` prints the last
build's assertions and its ten heaviest pages.

Sources: `src/posts/`, `src/notes/`, `src/pages/`; `src/capsule.md` is the one
front door rendered for both gemtext and gopher. A note that exists only as
`.gmi` is imported once with `tools/import_gemtext.py`, which records its old
address in `src/capsule-redirects.tsv` so `/name.gmi` keeps resolving.

`task envs:exec -- "<cmd>"` is the agent entry point; `envs:ssh` is interactive.
Permissions matter here (pubnix): `envs:harden` enforces SSH 700/600 and
`public_html` 750.

## Known issues

The per-user PHP-FPM pool does not answer (measured 2026-11-02) and no longer
matters: every route is a pre-rendered `index.html`. A page that "does not
update" is a publish that did not run — `task envs:report`, then `envs:publish`.

Truth: `taskfiles/envs.yml` — the executable contract; this page is the procedure.
