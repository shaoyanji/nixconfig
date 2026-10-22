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
`bountystash` Pages project (`bountystash.com`).

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
