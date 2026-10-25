---
name: atuin
description: "Pick me to finish atuin sync on a fleet host: one script does login, the one-time nu+bash seed, sync and the count check. The traps are the two key forms, the public-server fallback, and a non-idempotent import. Temporary migration skill."
version: 0.2.0
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

## One command, after the rebuild

The rebuild renders the key; `scripts/atuin-bootstrap.sh` (next to this file) does
everything else in one pass — login, the one-time history seed, two syncs, and the
count check. It is idempotent: a second run only syncs.

```bash
FLEET=24520    # the item count a converged host reports; ask a live one, it grows

# on the host
bash .agents/skills/atuin/scripts/atuin-bootstrap.sh --expect "$FLEET"

# or from here, no copy, no login for the target to work out
ssh <host> "bash -s -- --expect $FLEET" < .agents/skills/atuin/scripts/atuin-bootstrap.sh
```

Credentials come from sops (`ATUIN_PASSWORD`/`ATUIN_KEY`) when the host can read
the repo, else from the environment. Output is the whole proof on six lines:

```
host        stark
atuin       18.23.0
key         key · 60-char base64
login       done
seed        done: nu-hist-db bash
items       24520
verdict     synced
```

| code | meaning | what to do |
| :--- | :--- | :--- |
| 2 | not ready: no binary/key, mnemonic in the key file, or no fleet `sync_address` | rebuild the host |
| 3 | no usable credentials | export them, or point `NIXCONFIG` at a readable repo |
| 4 | login or sync failed | read the message; the landmines below |
| 5 | count ≠ `--expect` | this host's seed, or the server, is behind |

## The trap that costs an hour

The key has **two representations and they are not interchangeable**:

| sops field | shape | consumed by |
| :--- | :--- | :--- |
| `atuin/key` | 24-word mnemonic, ~150 chars | `atuin login -k` |
| `atuin/key_base64` | 60-char base64 | the **key file** at `~/.local/share/atuin/key` |

Writing the mnemonic into the key file fails with
`failed to decode the loaded key: failed to base64 decode`. Writing base64 into
`-k` fails with `key mnemonic was not valid`. Sops renders the base64 one;
humans paste the mnemonic one. The script checks both shapes before it logs in.

## Two more traps it now catches

- **`atuin import` is not idempotent.** Running `import bash` twice doubled the
  rows (measured 1,940 → 3,880), so the seed is guarded by
  `~/.local/share/atuin/.fleet-seeded`; `--force-seed` overrides it deliberately.
  `import nu-hist-db` reads `~/.config/nushell/history.sqlite3` (nu ≥ 0.100);
  plain `import nu` is the pre-0.100 `history.txt` and is empty on this fleet.
  Skip `import auto` — it guesses wrong in a non-interactive shell.
- **A host without `modules/shell/atuin.nix` logs into the public
  `api.atuin.sh`** and reports `invalid credentials`, which reads exactly like a
  wrong sops password. The script refuses an unset or public `sync_address` first.

### Hosts without a tailnet (guckloch)

`modules/shell/atuin.nix` points every host at the **tailnet** address. A host
that is not on the tailnet cannot route it, and atuin reports
`invalid credentials` — indistinguishable from a wrong password, which is why
login was failing on guckloch with credentials that work everywhere else.
`hosts/guckloch/configuration.nix` overrides `sync_address` with frieren's LAN
address taken from `config.fleet.inventory`, so the fact still has one home.
burgernas is the hand-written equivalent (below).

Test an address without a rebuild — atuin honours `ATUIN_CONFIG_DIR`:

```bash
mkdir -p /tmp/atuin-cfg
printf 'sync_address = "http://192.168.3.25"\n' > /tmp/atuin-cfg/config.toml
ATUIN_CONFIG_DIR=/tmp/atuin-cfg bash .agents/skills/atuin/scripts/atuin-bootstrap.sh
```

## Proof, not vibes

Two numbers must agree — the server's record count and the host's item count, and
the server sits a constant **+2** above the item count (bookkeeping rows, not history):

```bash
# on frieren (server)
sudo -u postgres psql -d atuin -tAc "select count(*) from store"
# on any client
sqlite3 ~/.local/share/atuin/history.db 'select shell, count(*) from history group by shell'
```

`--expect` is the same check in one step. `systemctl is-active atuin` proves
nothing about sync; an empty `history` table on the server is normal (v18 keeps
records in `store`).

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
explicitly instead — the same is true on Nix-managed hosts, where the atuin hook is
one `source` line in `config.nu`:

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
  rebuild (for the key) and one run of the script. `guckloch` is only reachable
  from its Windows box (no tailnet, and `guckloch.frieren.lan` resolves to
  frieren), so its run is `ssh`-less and local.
- Syncing is per-account, so the count is the fleet's: a host that shows fewer
  items has not finished its own import, not a sync problem.
