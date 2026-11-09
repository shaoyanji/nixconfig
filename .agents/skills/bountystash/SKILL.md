---
name: bountystash
description: "Bountystash Console & Cloudflare Pages control."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['bountystash', 'console', 'cloudflare']
    related_skills: []
---

# bountystash — one page, 14 KB, Cloudflare Pages

`/Volumes/data/projects/bountystash-console` (GitHub `shaoyanji/bountystash-console`),
built by `node scripts/build.js` into `dist/index.html`, deployed to the
`cv-resume` Pages project, whose custom domain is `bountystash.com`.

The project name is a fact about the Cloudflare account, not a typo: its
pages.dev subdomain is `cv-resume-40q.pages.dev` (Cloudflare appends the suffix
when the bare name is taken), `bountystash.pages.dev` does not exist, and both
live addresses serve the same `CV - Shaoyan (Matt) Ji` document (checked
2026-11-08). `PROJECT_NAME` in `taskfiles/bountystash.yml` is the one place it
appears; a deploy to a name nobody created would make a second project.

The repo also renders a second, different page: `.#sites.bountystash-site`
(`lib/bountystash-site.nix`, from `lib/bountystash/portfolio.json` — the same
data the Gemini capsule serves). **Production is that page now**: a
`bountystash:deploy:nix:prod` deploy onto `cv-resume` put the Nix portfolio on
`bountystash.com`, and a `bountystash:deploy:prod` (console) would replace it
until the next Nix deploy. The two templates share one Pages project and one
custom domain; they do not share a stylesheet or a URL.

## The constraint that shapes everything

**14,336 bytes gzipped.** The whole document (semantic HTML + minified CSS +
inline SVG) must fit one TCP initial window, which is why nothing is installed:
no npm, no bundler, no framework, only the Node standard library. `bountystash:build`
validates the size, so a build that succeeds but reports >14 KB is a failed build.

## Deploy

`bountystash:deploy:preview` builds and pushes a preview branch (prints the URL);
`bountystash:deploy:prod` builds and deploys live. A local pre-push hook
(`scripts/pre-push.sh`, installed by `bountystash:hook:install`) offers a preview
deploy via `gum confirm` and defaults to No after 15 s, so an unattended push is
never blocked.

`bountystash:login` is the Wrangler OAuth device grant; `:whoami` proves which
account is authenticated before a prod deploy, which is the mistake worth
checking twice.

## Both published surfaces

Every page carries a canonical, `og:url`, a 1200×630 PNG card per locale, hreflang
alternates and a sitemap entry; `site:check` asserts that over HTTP and
`site:links` asserts the pages can actually load their own CSS.

```bash
task site:check         # live: robots, sitemap, canonical, og:image, hreflang per host
task site:links         # offline: build both sites, resolve every internal href/src
```

`site:links` is the one that catches a stylesheet 404. The case studies live at
`/work/<slug>` — one directory deeper than the home pages — so a href built from
the locale's depth (`style.css`) is served from `/work/style.css`, which does not
exist: the page returns 200 and renders unstyled, and no status check sees it.
Every internal link on the Nix site is therefore root-relative.

Truth: `taskfiles/bountystash.yml` — the executable contract; this page is the procedure.
