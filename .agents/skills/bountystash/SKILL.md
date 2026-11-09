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
built by `node scripts/build.js` into `dist/`, deployed to the `cv-resume` Pages
project, whose custom domain is `bountystash.com`. It is the only thing that domain
serves. The Nix-rendered portfolio it replaced is retired, with its flake output and
its deploy tasks; the paths it answered, `/work/<slug>` in both locales, 301 to the
console — from `_worker.js`, because advanced mode runs the worker instead of the
Pages routing layer, with `_redirects` carrying the same rules beside it.

`lib/bountystash/portfolio.json` stays and is not a second site: the Gemini capsule
(`lib/gemini-portal.nix`) still compiles from it.

The project name is a fact about the Cloudflare account, not a typo: its
pages.dev subdomain is `cv-resume-40q.pages.dev` (Cloudflare appends the suffix
when the bare name is taken), `bountystash.pages.dev` does not exist, and both
live addresses serve the same `CV - Shaoyan (Matt) Ji` document (checked
2026-11-08). `PROJECT_NAME` in `taskfiles/bountystash.yml` is the one place it
appears; a deploy to a name nobody created would make a second project.

## The constraint that shapes everything

**14,336 bytes gzipped.** The whole document (semantic HTML + minified CSS +
inline SVG) must fit one TCP initial window, which is why nothing is installed:
no npm, no bundler, no framework, only the Node standard library. `bountystash:build`
validates the size, so a build that succeeds but reports >14 KB is a failed build.

## Deploy

`bountystash:deploy:preview` builds and pushes a preview branch (prints the URL);
`bountystash:deploy:prod` builds and deploys live. Both go through
`scripts/task/pages-deploy.sh`, which polls every page the artifact ships until it
answers 200: Pages reports "Deployment complete" before the asset manifest attaches,
so the CLI's exit code is not a readiness signal. A local pre-push hook
(`scripts/pre-push.sh`, installed by `bountystash:hook:install`) offers a preview
deploy via `gum confirm` and defaults to No after 15 s, so an unattended push is
never blocked.

`bountystash:login` is the Wrangler OAuth device grant; `:whoami` proves which
account is authenticated before a prod deploy, which is the mistake worth
checking twice.

## The crawl surface

Every page carries a canonical, `og:url`, a 1200×630 PNG card per locale, hreflang
alternates and a sitemap entry. `robots.txt`, `sitemap.xml`, the cards and
`_redirects` are emitted by the build, so they belong to the artifact instead of
being answered by the previous site's edge cache.

```bash
task site:check         # live: robots, sitemap, canonical, og:image, hreflang per host
task site:links         # offline: build the Nix sites, resolve every internal href/src
```

`site:check` lists exactly what the console serves (`/ /de/ /contact/ /de/kontakt/`);
the thank-you pages are `noindex` and stay out of both sitemap and gate.
`site:links` covers the remaining Nix surfaces (matt, mockup); the console's own
artifact is checked by `bountystash:build`, which runs the same script over `dist`.

Truth: `taskfiles/bountystash.yml` — the executable contract; this page is the procedure.
