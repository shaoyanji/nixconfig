---
name: bountystash
description: Bountystash Console management — modern brutalist 3D spatial systems console (<14KB TCP budget), local preview, and Cloudflare Pages deployments via Wrangler. Derived from taskfiles/bountystash.yml.
---

# bountystash — Bountystash Console & Cloudflare Pages Control Plane

Control and manage the Bountystash Console repository (`/Volumes/data/projects/bountystash-console`, tracking `shaoyanji/bountystash-console`), 14KB TCP envelope validation, and Cloudflare Pages deployments.

- **Local Path**: `/Volumes/data/projects/bountystash-console`
- **GitHub Origin**: `git@github.com:shaoyanji/bountystash-console.git`
- **Cloudflare Pages Project**: `bountystash` (`bountystash.com`)
- **Build Engine**: `node scripts/build.js` -> `dist/index.html` (<14KB gzipped)

## Quick Tasks

| Task | Description |
|------|-------------|
| `task bountystash:login` | Authenticate Wrangler with Cloudflare via OAuth device authorization grant |
| `task bountystash:whoami` | Check current authenticated Cloudflare user/account |
| `task bountystash:build` | Compile modern brutalist console and validate 14KB TCP envelope |
| `task bountystash:preview` | Launch zero-dependency local preview server on `http://localhost:3000` |
| `task bountystash:dev` | Local Cloudflare Edge emulation via `wrangler pages dev dist` |
| `task bountystash:deploy:preview` | Build & deploy preview branch to Cloudflare Pages (generates preview URL) |
| `task bountystash:deploy:prod` | Build & deploy live production to `bountystash.com` |
| `task bountystash:projects` | List all Cloudflare Pages projects in account |
| `task bountystash:git:pull` | Pull latest commits from `origin/main` |
| `task bountystash:git:push` | Push commits to GitHub (triggers interactive Cloudflare deploy nudge) |
| `task bountystash:git:status` | Check local working tree status |
| `task bountystash:hook:install` | Install/update git pre-push Cloudflare deploy nudge hook |
| `task bountystash:menu` | Interactive Charmbracelet Gum menu for Bountystash Console |

## Git Push Deploy Nudge Hook

The repository includes a non-blocking interactive pre-push hook (`scripts/pre-push.sh`, installed to `.git/hooks/pre-push`):
- When running `git push` or `task bountystash:git:push`, it presents an interactive `gum confirm` prompt:
  `Deploy updated build to Cloudflare Pages preview (cv-resume)?`
- **Non-blocking**: Defaults to `No` after a 15-second timeout, allowing unattended pushes to continue unimpeded.
- If accepted, it automatically runs `node scripts/build.js` and deploys to the preview branch on Cloudflare Pages (`https://preview.cv-resume-40q.pages.dev`).

## Architecture & Constraints

- **Zero-Dependency**: No npm packages, Webpack, or Vite. Compiled directly via Node standard library (`scripts/build.js`).
- **14KB Initial TCP Envelope Rule**: The entire document (semantic HTML + minified CSS + inline SVGs) must remain under 14,336 bytes gzipped to load in a single roundtrip.
- **Dual-Mode Engine**: 3D HUD mode (spatial depth camera along Z-axis) and Flat Doc mode (independent left scroll driving right telemetry inspector).
- **Edge Deployment**: Production deployed to Cloudflare Pages edge network under `bountystash.com`.
