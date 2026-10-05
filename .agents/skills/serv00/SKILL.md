---
name: serv00
description: Serv00 FreeBSD hosting management — SSH access, Devil CLI controls, webserver lifecycle (jisifu.serv00.net), and Charmbracelet Gum/Wish menu. Derived from taskfiles/serv00.yml.
---

# serv00 — Serv00 FreeBSD Hosting Control Plane

Control and manage the Serv00 FreeBSD host (`s13.serv00.com`), Devil CLI configuration, and the webserver backend for `jisifu.serv00.net`.

- **Host**: `s13.serv00.com`
- **User**: `jisifu`
- **Port**: `22` (standard SSH)
- **SSH Alias**: `serv00` or `s13` (defined in `~/.ssh/config`)
- **Web Domain**: `https://jisifu.serv00.net` (proxied to `127.0.0.1:49613`)
- **Backend Port**: `49613` (TCP reserved via `devil port`)

## Quick Tasks

| Task | Description |
|------|-------------|
| `task serv00:ssh` | Interactive SSH shell into Serv00 FreeBSD |
| `task serv00:exec -- "<cmd>"` | Execute command non-interactively on Serv00 (agent-friendly) |
| `task serv00:devil -- <args>` | Execute Devil CLI command (e.g. `task serv00:devil -- port list`) |
| `task serv00:server:status` | Check running webserver process & curl `https://jisifu.serv00.net` |
| `task serv00:server:start` | Launch backend webserver on port 49613 via `/usr/sbin/daemon` |
| `task serv00:server:stop` | Stop background webserver process |
| `task serv00:server:restart` | Restart background webserver |
| `task serv00:server:build` | Recompile `server.go` on FreeBSD using Go 1.24 |
| `task serv00:cron:enable` | Install keep-alive cron job to ensure 24/7 webserver uptime |
| `task serv00:cron:disable` | Remove keep-alive cron job |
| `task serv00:ports` | List reserved TCP/UDP ports via `devil port list` |
| `task serv00:www` | List domains and reverse proxy targets via `devil www list` |
| `task serv00:push -- <local> [dest]` | Transfer local file/dir to Serv00 |
| `task serv00:pull -- <remote> [dest]` | Transfer remote file/dir from Serv00 |
| `task serv00:info` | Query FreeBSD uname, quota, and running user processes |
| `task serv00:menu` | Interactive Charmbracelet Gum / Wish menu for Serv00 |

## Devil CLI Overview

Serv00 uses the `devil` CLI command on FreeBSD:

```bash
# Check or enable permission to run user binaries:
devil binexec on

# List / add reserved ports:
devil port list
devil port add tcp <port>

# Manage web domains & proxy forwarding:
devil www list
devil www add <domain> proxy <target_url>

# Manage databases:
devil mysql list
devil pgsql list
```

## Agent Usage Examples

```bash
# Query server health and running processes
task serv00:info

# Check if public website is healthy
task serv00:server:status

# Run Devil CLI to check ports
task serv00:devil -- port list
```
