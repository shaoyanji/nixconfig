---
name: moto
description: "Motorola Android (Termux) over Tailscale."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['moto', 'android', 'termux', 'tailscale']
    related_skills: []
---

# moto — Termux on the phone, over Tailscale

| | |
| :--- | :--- |
| Host | `moto-g35-5g`, `100.75.49.73` (tailnet only), alias `moto` |
| Port / user | `8022` / `u0_a301` (Termux sandbox UID) |
| Entry point | `task moto:exec -- "<cmd>"`; `moto:ssh` is interactive |

Termux `~/storage/*` are symlinks into Android storage, which is why `push`
defaults to `storage/downloads`:

| Shortcut | Android path |
| :--- | :--- |
| `~/storage/downloads` | `/storage/emulated/0/Download` |
| `~/storage/dcim` | `/storage/emulated/0/DCIM` |
| `~/storage/pictures` | `/storage/emulated/0/Pictures` |
| `~/storage/documents` | `/storage/emulated/0/Documents` |
| `~/storage/shared` | `/storage/emulated/0` |

Android kills Termux when it is backgrounded unless Termux holds a wake lock, so
a long job started over ssh can die with the connection still open. Write its
output to a file and poll it instead of holding a session.

The phone has no Nix, so nothing here is declarative: what `task moto:*` does is
whatever `taskfiles/moto.yml` says, and a change to the phone is a change on the
phone.

Truth: `taskfiles/moto.yml` — the executable contract; this page is the procedure.
