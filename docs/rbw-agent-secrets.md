# Agent access to the vault: rbw, and why aac is not installed

Agents read credentials with `rbw` (nixpkgs, `.#cli.security.rbw`). The
`bitwarden/agent-access` tunnel (`aac`) was evaluated and is not adopted; the
reasons are below, because the decision costs a security property.

## What `aac` would add, and what it still needs

`aac listen` runs beside the vault and `aac connect` opens a Noise tunnel through
a relay, so the agent side never runs a vault client. That is a real grant
narrower than "read anything".

It does not remove the `bw` dependency. Its Bitwarden provider shells out to
`bw` for `bw status`, `bw unlock --passwordenv` and `bw get item <q>`, and reads
`{id, login:{username,password,totp,uris}}` from the JSON. The fleet would keep a
`bw` shim in front of `rbw` forever, plus a binary outside nixpkgs: the release
tarball is dynamically linked (`libssl.so.3`, `libcrypto.so.3`) and needs
`autoPatchelfHook` and openssl, and the listener is a ratatui TUI that panics
without a pty (`failed to initialize terminal`), so it wants tmux. The default
relay is `wss://ap.lesspassword.dev`, a third party that sees metadata. Licence
is Apache-2.0, so licensing is not the objection.

One unpackaged binary, a shim, a third-party relay and a pty-only listener is a
worse trade than a documented boundary around `rbw`, so `aac` is skipped
[[flake/policies.nix#secrets-are-encrypted]] still governs where secrets live.

## The two sides

| Side | Command | What it means |
| :--- | :--- | :--- |
| unlocker | `rbw unlock` | the agent process holds the key in memory |
| unlocker | `rbw unlocked` | exit 0 = usable, exit 1 = no agent or locked |
| consumer | `rbw get --field password ITEM` | one field, no JSON parse |
| consumer | `rbw get --raw ITEM` | `{id, folder, name, data:{username,password,totp,uris}, fields, notes, history}` |
| consumer | `rbw code ITEM` | current TOTP |
| unlocker | `rbw lock`, `rbw stop-agent` | drop the key and end the agent |

`rbw get --raw` carries the same fields `aac` reads, so a field-scoped read is
available without the tunnel. Config is `~/.config/rbw/config.json` (`email`,
`base_url`, `lock_timeout`, `pinentry`); `#cli.security` already ships the
client, and `nix run nixpkgs#rbw -- …` is the same 1.15.0 binary on a host
without the profile.

## Read into a process, not a file

```bash
PGPASSWORD="$(rbw get --field password 'appflow/db')" psql -h 127.0.0.1 -U appflow
```

The command substitution is the only copy; the value is never echoed and never
written. For a tool that insists on a file, write to `mktemp` with `umask 077`
and `trap 'rm -f "$tmp"' EXIT`, which is what `passkey-fetch.sh` does with the
one credential `rbw` cannot reach.

## Scope is the boundary, not the query

`rbw` has no per-item ACL: an unlocked agent can read the whole vault for that
user. The control is therefore a dedicated Unix user and a short unlock window,
not the item name.

- Run agent jobs as a user whose `rbw` config points at the same server, and
  unlock for the length of the job only:

  ```bash
  rbw unlock
  trap 'rbw lock; rbw stop-agent' EXIT
  ./job.sh
  ```

- Name items `<service>/<purpose>` and gate reads on a glob, so an accidental or
  injected read of another item fails before `rbw` is called:

  ```bash
  #!/usr/bin/env bash
  # rbw-scoped — one field of one allowlisted item, or nothing.
  set -euo pipefail
  item=${1:?usage: rbw-scoped ITEM [FIELD]}
  field=${2:-password}
  allow=${RBW_ALLOW:-appflow/*}
  case $item in
    $allow) ;;
    *) echo "rbw-scoped: $item is outside RBW_ALLOW=$allow" >&2; exit 1 ;;
  esac
  rbw get --field "$field" "$item"
  ```

  The glob is a guard against mistakes, not against a hostile process running
  as the same user — that process can call `rbw` directly.

- `lock_timeout` in the config bounds how long an abandoned unlock survives.
  `rbw unlocked` as the preflight turns "the agent died" into a clean failure
  instead of a prompt.

## Rotation and staleness

`rbw` keeps a local copy of the database, so an entry edited on another device
is invisible until `rbw sync`. A job that must see a fresh value calls `rbw sync`
first; a job that must not touch the network skips it and accepts the cache.
Values in the sops files are a second copy: a credential used both by a service
at activation and by an agent through `rbw` has to be rotated in both places, or
one of them is stale.

## What still needs bitwarden-cli

Two reads are outside `rbw`'s JSON: `fido2Credentials` (a passkey's private key)
and `sshKey`. `scripts/task/passkey-fetch.sh` and
`scripts/task/bitwarden-ssh-test.sh` use `bitwarden-cli` for exactly those, and
`checks:ssh:bitwarden` is the assertion for the second. Nothing else shells out
to `bw`.

## Residual risk

An agent with `rbw` unlocked reads every item the account can see. `aac` would
replace that with a field-scoped tunnel from a host that keeps the vault. If a
grant ever has to be narrow — an agent on a machine where another item must stay
unreadable — that is the moment to revisit `aac`, with the shim and the relay
choice already mapped above.
