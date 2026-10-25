---
name: atuin
description: "Pick me to finish atuin sync on a fleet host: shared sops key, login with the mnemonic (not the base64 file form), import nu + bash history, then the count check that proves convergence. Temporary migration skill."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['atuin', 'shell-history', 'sync', 'nushell', 'bash', 'sops']
    related_skills: ['infra', 'knowledge-base']
---

# atuin — finish shell-history sync on one host

**Temporary.** Delete this directory once every active host reports the fleet's
item count. It exists because sync had to be bootstrapped by hand per machine,
not because atuin needs a permanent runbook.

Server: `modules/services/atuin-server.nix` (frieren, postgres, nginx in front,
registration closed). Client: `modules/shell/atuin.nix`. Shared key:
`modules/sops.nix` renders `atuin/key_base64` to `~/.local/share/atuin/key`.

Truth: `modules/sops.nix`, `modules/shell/atuin.nix`, `modules/services/atuin-server.nix`, `modules/secrets.yaml`; fleet membership from `inventory.toml`.

## The trap that costs an hour

The key has **two representations and they are not interchangeable**:

| sops field | shape | consumed by |
| :--- | :--- | :--- |
| `atuin/key` | 24-word mnemonic, ~150 chars | `atuin login -k` |
| `atuin/key_base64` | 60-char base64 | the **key file** at `~/.local/share/atuin/key` |

Writing the mnemonic into the key file fails with
`failed to decode the loaded key: failed to base64 decode`. Writing base64 into
`-k` fails with `key mnemonic was not valid`. Sops renders the base64 one;
humans paste the mnemonic one.

## Procedure, one host at a time

Run on the host (or over ssh). `sops` must work there, and the host needs its
declarative generation — the key file is written by activation, so rebuild first
if `~/.local/share/atuin/key` is missing.

```bash
# 1. Log in. Not `atuin register`: registration is closed server-side.
atuin login -u devji \
  -p "$(sops -d --extract '["atuin"]["password"]' modules/secrets.yaml)" \
  -k "$(sops -d --extract '["atuin"]["key"]' modules/secrets.yaml)"

# 2. Seed the history that predates atuin (both shells, both importers).
atuin import nu-hist-db    # ~/.config/nushell/history.sqlite3 (nu >= 0.100)
atuin import bash          # ~/.bash_history

# 3. Push, then confirm it landed.
atuin sync
atuin sync 2>&1 | tail -1     # expect: Sync complete! <N> items
```

`atuin import nu` (no `-hist-db`) is for the pre-0.100 `history.txt`; it is
essentially empty on this fleet. Skip `atuin import auto` — it guesses wrong in a
non-interactive shell.

### Non-interactive shells need a session id

Scripted syncs that trigger a store init die with
`Failed to find $ATUIN_SESSION in the environment`. Interactive shells export it
from the hook; for a script, supply one:

```bash
export ATUIN_SESSION=$(cat /proc/sys/kernel/random/uuid)
```

Nothing persists from that variable; it only labels the session.

## Proof, not vibes

Two numbers must agree — the server's record count and the host's item count:

```bash
# on frieren (server)
sudo -u postgres psql -d atuin -tAc "select count(*) from store"
# on any client
sqlite3 ~/.local/share/atuin/history.db 'select shell, count(*) from history group by shell'
```

`systemctl is-active atuin` proves nothing about sync; an empty `history` table on
the server is normal (v18 keeps records in `store`).

## Hosts that are not Nix-managed (burgernas)

The NAS runs atuin without a flake: a pinned **static aarch64-musl** release in
`~/.local/bin/atuin`, installed by piping the binary over `ssh 'cat > …'` because
DSM refuses `scp`. It syncs to `http://192.168.3.25` (LAN), because its tailscale
link is not up and the tailnet address returns nothing. Two files are hand-written
there and say so in their own comments: `~/.config/atuin/config.toml`, and
`~/.config/nushell/{env,config}.nu` — nushell reaches atuin only through
`~/.local/share/atuin/init.nu`, and DSM's PATH does not include `~/.local/bin`.

**`nu -c '…'` does not load those config files.** A verification run that way
reports zero atuin commands and looks like a broken install; pass the configs
explicitly instead:

```bash
nu --env-config ~/.config/nushell/env.nu --config ~/.config/nushell/config.nu \
  -c 'print (scope commands | where name =~ "_atuin_" | length)'
```

## Landmines

- **A host that ran atuin before login has a private key in its store.** Its
  records carry a different key id, sync aborts with *"cannot decrypt the data on
  the server"*, and `atuin store rekey` **cannot fix it** — rekey needs the old
  key to unwrap the CEKs. What works: a plain `atuin sync` re-uploads from the
  plaintext `history.db` under the account key, then `atuin store purge` clears
  the undecryptable local rows. Delete the matching orphan rows server-side first
  if a sync still refuses (back up `store` with `pg_dump -t store atuin`).
- **Never rotate the account key** with clients still holding the old one: run
  `atuin store rekey` on every host first, or the old-key records become
  permanently unreadable.
- **Remaining hosts.** Derive them, do not trust a list:
  `nix eval --json .#inventory.hosts | jq -r 'to_entries[] | select(.value.status=="active") | .key'`.
  Done so far: `frieren`, `poseidon`, `delphi`, `fern`, `stark`. Each remaining host needs a
  rebuild (for the key) and the three steps above.
- Syncing is per-account, so the count is the fleet's: a host that shows fewer
  items has not finished its own import, not a sync problem.
