---
name: envs
description: Envs.net Debian hosting management — SSH access, public_html PHP/SPA website (jisifu.envs.net), Gemini/Gopher capsules, markdown rebuilds, and Charmbracelet Gum/Wish menu. Derived from taskfiles/envs.yml.
---

# envs — Envs.net Pubnix Control Plane

Control and manage the Envs.net Debian pubnix host (`envs.net`) and web/gemini services for `jisifu.envs.net`.

- **Host**: `envs.net` (Debian 13 trixie)
- **User**: `jisifu`
- **Port**: `22` (standard SSH)
- **SSH Alias**: `envs` or `envs.net` (defined in `~/.ssh/config`)
- **Web Domain**: `https://jisifu.envs.net` (served via Nginx)
- **Webroot**: `/home/jisifu/public_html`
- **Gemini Capsule**: `gemini://jisifu.envs.net` (`/home/jisifu/public_gemini`)
- **Gopher Hole**: `gopher://jisifu.envs.net` (`/home/jisifu/public_gopher`)

## Quick Tasks

| Task | Description |
|------|-------------|
| `task envs:ssh` | Interactive SSH shell into Envs.net host |
| `task envs:exec -- "<cmd>"` | Execute command non-interactively on Envs.net (agent-friendly) |
| `task envs:status` | Health check on `https://jisifu.envs.net` & disk usage |
| `task envs:audit` | Comprehensive health, active sessions, web HTTP, and permissions audit |
| `task envs:harden` | Enforce strict permissions on pubnix (SSH 700/600, public_html 750) |
| `task envs:clean` | Clean stale vim undo files (`.un~`) and temporary caches |
| `task envs:backup` | Download compressed tarball of markdown content and gemini capsules |
| `task envs:build` | Rebuild JSON, validate tags, export SRS & generate SPA routes in `~/public_html` |
| `task envs:validate` | Validate equation schemas and HTML tag balance |
| `task envs:test` | Run PHP test suite (`test.php`) in `~/public_html` |
| `task envs:push -- <local> [dest]` | Transfer local file/dir to Envs.net (defaults to `public_html/`) |
| `task envs:pull -- <remote> [dest]` | Transfer remote file/dir from Envs.net to local machine |
| `task envs:info` | Query Debian uname, disk quota, runtimes (PHP/Node/Python/Go), and git status |
| `task envs:menu` | Interactive Charmbracelet Gum / Wish menu for Envs.net |

## Environment Overview

The `jisifu.envs.net` site runs on Debian GNU/Linux 13 (trixie) with:
- **Nginx 1.26 + PHP 8.4**
- **Markdown-to-JSON static generator** (`generate_json.php`)
- **Tag validator** (`validate_tags.php`) & **Equation validator** (`validate-equations.php`)
- **SRS flashcard exporter** (`srs-export.php`)
- **Gemini capsule** (`public_gemini/index.gmi`, `*.gmi`)
- **Gophermap** (`public_gopher/gophermap`)

## Agent Usage Examples

```bash
# Query server health and disk usage
task envs:info

# Check if public website is active
task envs:status

# Rebuild site JSON and routes after editing content
task envs:build

# Validate markup and equations
task envs:validate
```
