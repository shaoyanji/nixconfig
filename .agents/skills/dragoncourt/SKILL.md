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

# dragoncourt — Alwaysdata, and the Comrak render step

| | |
| :--- | :--- |
| Host | `ssh-dragoncourt.alwaysdata.net`, Debian 12, alias `dragoncourt` |
| User / webroot | `dragoncourt` / `~/www` |
| Web | `https://dragoncourt.alwaysdata.net`, Apache + PHP 8.4 |

## The API

`alwaysdatatoken` is the account's API token in `modules/secrets.yaml`. It is
read at call time by `scripts/task/alwaysdata.sh` and never written to a file:
Alwaysdata takes the token as the basic-auth *user* with an empty password, and
`ALWAYSDATA_ACCOUNT` names a linked account when one token spans several. The
script always filters through jq, so a task prints a table and an agent reads it.

The listing verbs are read-only and print a row per resource, filtered through
jq: `dragoncourt:sites`, `:services`, `:databases`, `:mailboxes`, `:webdav`,
`:jobs`, `:ssh:users`, `:ftp`, `:subdomains`, `:api:account`.

| Task | What the desc does not say |
| :--- | :--- |
| `dragoncourt:api` | `BODY=` carries the JSON, or `-` for stdin; one call per invocation, so a loop owns its pace |
| `dragoncourt:service:restart` | the answer is `http 204` and that status is the only proof it took |
| `dragoncourt:service:logs` | needs SSH, not the token; it tails the newest file only |

The services on this account are the fleet's own HTTP stubs (`xs` on the
turn log, `sse-demo` on 8311, `api-stub` on 8312): they run in the foreground,
bind `::` on 8300–8499, and are restarted by Alwaysdata when they die. A restart
is the only write task here, and it is a SIGHUP — the unit decides what that
means, so a service that ignores SIGHUP keeps running. Their output is at
`~/admin/logs/services/`, which `dragoncourt:service:logs` tails.

`GET /v1/account/` is the cheapest proof the token still works. Rate limits are
250 rpm for safe methods and 50 rpm for a write. Writes are live: a `POST
/v1/site/` creates a site before anything on this host knows about it.

The page is not a template: `index.md`, `sidebar.md` and `footer.md` are compiled
to HTML by **Comrak** at `~/.local/bin/comrak`, run through `task
dragoncourt:build`. Editing the markdown without the build leaves the old HTML
served, and the generated files are in `~/www`, so a `push` of the `.md` alone is
not a deploy.

`home/wasm.php` serves a Go WebAssembly bundle (`wasm_exec.js` + `wasm.wasm`).
Those two are artefacts: `dragoncourt:build` only re-renders markdown, so a Go
change is a separate build and a separate push.

`task dragoncourt:exec -- "<cmd>"` is the agent entry point (`:ssh` is
interactive). `:info` is uname + quota + runtime versions, `:harden` enforces SSH
700/600 and `www` 750.

Truth: `taskfiles/dragoncourt.yml` — the executable contract; this page is the procedure.
