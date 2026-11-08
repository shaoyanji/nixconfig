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
data the Gemini capsule serves). It is not what production runs. Its
`bountystash:deploy:nix:*` tasks publish it on purpose, and a `main` deploy
replaces the console until the next console deploy.

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

Truth: `taskfiles/bountystash.yml` — the executable contract; this page is the procedure.
