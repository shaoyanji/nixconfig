---
name: envs
description: "Envs.net Debian hosting: SSH, web, Gemini, Gopher."
version: 0.1.3
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

## twtxt

| | |
| :--- | :--- |
| Feed | `https://envs.net/~jisifu/twtxt.txt` (also `https://jisifu.envs.net/twtxt.txt`), `text/plain` |
| File | `~/twtxt.txt` authoritative, copied to `~/public_html/twtxt.txt` |
| Client | `twtxt` 1.3.1 on the host (`/usr/local/bin/twtxt` → `/opt/services/twtxt/venv`), config `~/.config/twtxt/config`, mode 600 |
| Registries | `https://twtxt.envs.net` (getwtxt v0.5.0) and `https://registry.twtxt.org` |

The feed lives in the home directory, not in `public_html`: `envs:publish` swaps
the web root, so a feed kept only there dies at the next publish. The client's
`post_tweet_hook` refreshes the published copy after every tweet:

    post_tweet_hook = "install -m 644 {twtfile} ~/public_html/twtxt.txt"

Keep the quotes. The client runs `shlex.split(hook)` and then
`subprocess(…, shell=True)`, which executes only the first split element: an
unquoted hook collapses to a bare `install` and fails with `missing file
operand`, while the quoted string survives as one element and the shell sees the
whole command (measured 2026-11-06). If a publish dropped the copy,
`install -m 644 ~/twtxt.txt ~/public_html/twtxt.txt` restores it.

Register with both registries, `nickname` alongside `url`, sent as
`--data-urlencode` so the path is not mangled:

    curl -X POST --get 'https://twtxt.envs.net/api/plain/users' \
      --data-urlencode 'url=https://envs.net/~jisifu/twtxt.txt' \
      --data-urlencode 'nickname=jisifu'

Query by nickname. `?q=jisifu` answers on both, while `?url=…` does not filter:
the envs instance returns an empty body for a feed it holds, and the global one
returns the full user list (18 KB) because it is an Express app, not getwtxt,
and advertises no `/api/plain/version` (404). Registration is immediate on both;
ingestion is not. The envs registry lists a new tweet under
`/api/plain/tweets?q=jisifu` within about 20 s, while the global registry had
not indexed the same feed eight minutes after its `200 OK` (all measured
2026-11-06) — check the feed itself before reporting a tweet as indexed.

Post and read on the host; nothing in this repository wraps the client yet:

    twtxt tweet "text"
    twtxt timeline --limit 20
    twtxt follow <nick> <url>    # [following] starts empty

The file carries the optional header (`# nick`, `# url`, `# avatar`); the avatar
is `https://envs.net/~jisifu/icon.svg`.

## Known issues

The per-user PHP-FPM pool does not answer (measured 2026-11-02) and no longer
matters: every route is a pre-rendered `index.html`. A page that "does not
update" is a publish that did not run — `task envs:report`, then `envs:publish`.

Truth: `taskfiles/envs.yml` — the executable contract; this page is the procedure.
