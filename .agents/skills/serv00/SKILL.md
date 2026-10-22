---
name: serv00
description: "Serv00 FreeBSD hosting: SSH, Devil CLI, webserver."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['serv00', 'freebsd', 'ssh', 'devil']
    related_skills: []
---

# serv00 — FreeBSD hosting

| | |
| :--- | :--- |
| Host | `s13.serv00.com`, port 22 (ssh alias `serv00`/`s13`) |
| User | `jisifu` |
| Site | `https://jisifu.serv00.net` → proxied to `127.0.0.1:49613` |
| Backend | Go webserver on TCP `49613`, kept alive by cron |

22 tasks, all named and described:

```bash
task --list-all --json | jq -r '.tasks[] | select(.name|startswith("serv00:")) | .name'
```

Three of them carry a caveat a description cannot:

```bash
task serv00:exec -- "<cmd>"     # non-interactive; the agent-safe entry point
task serv00:devil -- port list   # every Devil call goes through this
task serv00:server:build        # Go 1.24 on FreeBSD, not the local toolchain
```

`serv00:ssh` is interactive, so it is for the human only.

## Devil CLI

```bash
devil binexec on                       # allow user binaries (needed once)
devil port list                        # reserved TCP/UDP ports
devil port add tcp <port>              # reserve one before binding
devil www list
devil www add <domain> proxy <target_url>
devil mysql list
devil pgsql list
```

## What bites

- Reserved ports are per-account and finite. `devil port add` before a new
  listener, or the process dies with `EADDRINUSE` that looks like a crash.
- FreeBSD userland: `sed -i ''`, `ps -aux`, no GNU `date -d`. Anything you write
  for Linux and paste here fails on the flags, not the logic.
- `~/.ssh` must be 700/600 and domains 750, or the webserver cannot read them;
  `task serv00:harden` enforces that and `task serv00:audit` reports drift.
- Quotas are real (512 MB RAM, process and disk caps): `task serv00:limits`. A
  build that passes locally can be OOM-killed by the jailed limit.

Truth: `taskfiles/serv00.yml` — the executable contract; this page is the procedure.
