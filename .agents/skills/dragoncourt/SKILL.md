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
