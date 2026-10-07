---
name: dragoncourt
description: "Alwaysdata Debian hosting: SSH, PHP/Wasm, Gum."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['dragoncourt', 'alwaysdata', 'debian']
    related_skills: []
---

# dragoncourt — Alwaysdata Hosting Control Plane

Control and manage the Alwaysdata Debian host (`ssh-dragoncourt.alwaysdata.net`) and the webserver for `dragoncourt.alwaysdata.net`.

- **Host**: `ssh-dragoncourt.alwaysdata.net`
- **User**: `dragoncourt`
- **Port**: `22` (standard SSH)
- **SSH Alias**: `dragoncourt` or `alwaysdata` (defined in `~/.ssh/config`)
- **Web Domain**: `https://dragoncourt.alwaysdata.net` (served via Apache + alproxy)
- **Webroot**: `/home/dragoncourt/www`

## Quick Tasks

| Task | Description |
|------|-------------|
| `task dragoncourt:ssh` | Interactive SSH shell into Alwaysdata Debian host |
| `task dragoncourt:exec -- "<cmd>"` | Execute command non-interactively on Alwaysdata (agent-friendly) |
| `task dragoncourt:status` | Health check on `https://dragoncourt.alwaysdata.net` & disk usage |
| `task dragoncourt:audit` | Comprehensive health, quota, web HTTP, and permissions audit |
| `task dragoncourt:harden` | Enforce secure permissions (SSH 700/600, www 750) |
| `task dragoncourt:logs` | Tail live Apache HTTP access/error logs from `~/admin/logs/sites/` |
| `task dragoncourt:backup` | Download compressed tarball of Alwaysdata webroot (`~/www`) |
| `task dragoncourt:build` | Re-render Comrak markdown templates in `~/www/` |
| `task dragoncourt:push -- <local> [dest]` | Transfer local file/dir to Alwaysdata (defaults to `www/`) |
| `task dragoncourt:pull -- <remote> [dest]` | Transfer remote file/dir from Alwaysdata to local machine |
| `task dragoncourt:info` | Query Debian uname, disk quota, and PHP/Node/Go versions |
| `task dragoncourt:menu` | Interactive Charmbracelet Gum / Wish menu for Alwaysdata |

## Web Environment Overview

The `dragoncourt.alwaysdata.net` site runs on Debian 12 with:
- **Apache + PHP 8.4** (`index.php`, `home/wasm.php`)
- **Comrak Markdown Engine** (`~/.local/bin/comrak`) for compiling `index.md`, `sidebar.md`, and `footer.md`
- **Go WebAssembly** (`wasm_exec.js`, `wasm.wasm`)
- **Image Gallery** (`www/jpg/`)

## Agent Usage Examples

```bash
# Query server health and disk usage
task dragoncourt:info

# Check if public website is active
task dragoncourt:status

# Rebuild markdown templates
task dragoncourt:build
```
