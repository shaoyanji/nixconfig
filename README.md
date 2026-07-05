# nixconfig

Multi-host Nix flake for NixOS, nix-darwin, Home Manager, and WSL-style container hosts.

## Layout

- `flake/*`: flake outputs and wiring.
- `hosts/*`: host entrypoints plus local identity, storage, and networking.
- `modules/profiles/*` and `modules/services/*`: canonical reusable host and service logic.
- `modules/user/*`, `modules/roles/*`, and `modules/shell/*`: user and role commitments.
- `pkgs/*`: package definitions.
- `docs/*`: operator and architecture references.

## Quick Start

1. **Prerequisites**: NixOS/Darwin system with flakes enabled
2. **Clone repo**: `git clone <repo-url> && cd nixconfig`
3. **List tasks**: `task --list-all` to see all available tasks
4. **Build a host**: `task infra:plan:host:thinsandy`
5. **Deploy**: `task infra:deploy:host:thinsandy` (plan + apply + validate)

## Module chains

Module chains compose as follows:

```
globalModulesNixos      → global → nixos → home-manager-shared → role:heim
globalModulesImpermanence → globalModulesNixos → +impermanence module
globalModulesContainers  → global → noDE (lean home-manager, no dms/niri)
globalModulesMacos       → global → macos (nix-darwin, no dms/niri)
```

`base-node.nix` (profile) provides the common NixOS baseline: kernel packages, SSH, keyd, networkmanager, console, sops, user `devji`, common dev packages, and boot loader defaults (systemd-boot + EFI). Container and desktop hosts import it via `globalModulesContainers` or `desktop-client.nix`.
`base-node.nix` also imports `modules/profiles/firewall-baseline.nix`, which enables the firewall and only opens TCP/22 by default. Hosts should add service/interface-specific allowances explicitly.

## Add a host

1. Add a host module under `hosts/<name>/configuration.nix` (or `hosts/<name>.nix` for simple cases).
2. Add hardware/storage modules as needed (for example `hardware-configuration.nix`, `disko.nix`, or profile imports).
3. Register the host entry in `flake/host-inventory.nix` with:
   - target platform (`system`)
   - module chain (`globalModulesNixos`, `globalModulesImpermanence`, `globalModulesContainers`, etc.)
   - host module path(s)
4. Let `flake/host-projection.nix` project inventory data into outputs (no manual output wiring needed).
5. Build/check through the Task control plane (`Taskfile.yml` + `taskfiles/*`) and then switch on the target host.

## Disko install from a NixOS minimal ISO

```bash
# Boot the NixOS minimal ISO, fetch your flake, and partition:
sudo nix run github:nix-community/disko -- --mode disko --flake /path/to/flake#hostname
# Then install:
sudo nixos-install --flake /path/to/flake#hostname
# Reboot into the freshly partitioned system.
```

Disko handles partitioning, formatting, and mounting — no manual `fdisk`/`mkfs` needed. Device paths are parameterised per-host (e.g. `disko.nix {device = "/dev/sda";}`).

## Supported Hosts

| Host          | nullclaw | hermes-agent | ollama | xs | pancakes-harness |
|---------------|----------|--------------|--------|-----|------------------|
| thinsandy     | yes      | yes          | yes    | yes | yes              |
| mtfuji        | yes      | no           | yes    | no  | no               |
| garnixMachine | yes      | no           | no     | no  | no               |
| kellerbench   | no       | no           | yes    | no  | no               |

Per-host quirks and exceptions: `.agents/deploy/hosts/*.md`

## Pinning and updates

`nixpkgs` and all inputs are pinned via `flake.lock`. Update intentionally with lockfile bumps (for example `nix flake update` or targeted input updates), then review and commit `flake.lock` with the corresponding config changes.

## Flake outputs

- `nixosConfigurations`
- `darwinConfigurations`
- `homeConfigurations`
- `packages`
- `checks`
- `devShells`

Canonically assembled from [`flake/outputs.nix`](flake/outputs.nix) and [`lib/mk-nixos-host.nix`](lib/mk-nixos-host.nix).

## Secrets & SSH CA

Secrets use `sops-nix`. Two separate encrypted files:

| File | Decryptors | Contents |
|------|------------|----------|
| `modules/secrets.yaml` | All hosts (via their `ssh_host_ed25519_key` age keys in `.sops.yaml`) | App secrets, `hashedPassword`, API keys |
| `modules/ssh-ca-key.yaml` | Workstations only (`*devji`, `*sopsposeidon`) | SSH User CA private key |

### SSH CA workflow

Instead of managing per-host `authorized_keys`, servers trust a **single CA public key** embedded in `modules/ssh-ca.nix`. Workstations hold the CA private key (decrypted by sops-nix) and sign short-lived certificates.

**As a workstation user, daily flow:**

```bash
# Sign a 1-week cert for yourself
rotate-ssh-cert

# That's it. All hosts that trust the CA accept this cert automatically.
ssh thinsandy
```

The `rotate-ssh-cert` script is available on any host with `ssh.ca.enableClient = true`. The cert is cached in `~/.ssh/id_ed25519-cert.pub` and used automatically via `CertificateFile` in the SSH config.

### Provisioning a new server

1. Add entry to `flake/host-inventory.nix` with the appropriate module chain
2. The host's age key (from `ssh_host_ed25519_key`) must already be in `.sops.yaml` for `hashedPassword` decryption — it is if you followed the existing `.sops.yaml` setup
3. Build and deploy — `ssh.ca.enable = true` is inherited from `base-node.nix`, so the CA is trusted automatically
4. SSH in using a certificate signed from your workstation

No `.sops.yaml` changes needed. No `authorized_keys` updates. No per-host config changes.

### Provisioning a new workstation

A workstation is any machine you SSH *from* and sign certificates on. This includes a fresh laptop or a new home-manager-only machine.

1. Build the flake on the new machine
2. Add the machine's age public key as a recipient in `modules/ssh-ca-key.yaml`:

   ```bash
   sops --rotate --add-age <NEW_AGE_KEY> modules/ssh-ca-key.yaml
   ```

3. Commit and push the rekeyed file
4. Rebuild on the new workstation — sops-nix places `~/.ssh/user_ca_key`
5. Run `rotate-ssh-cert` to sign your first certificate

### Bootstrap caveat

The first SSH connection to a *bare-metal* machine (before NixOS is installed) is outside the CA model — you still use a USB installer, rescue ISO, or temporary password. The CA eliminates ongoing management once the host is in the fleet.

### TOTP secrets with cloak

TOTP tokens are managed via [cloak](https://github.com/evansmurithi/cloak) — a CLI OTP authenticator — with the accounts file encrypted in SOPS.

**Viewing a TOTP:**

```bash
task dev:cloak:view          # pick from a list (gum filter)
task dev:cloak:view:github   # or directly by name
```

**Editing TOTP accounts:**

```bash
task dev:cloak:edit          # opens the full SOPS file, navigate to the `cloak` key
```

**Importing from Bitwarden:**

Export from Bitwarden (Settings → Export → Unencrypted JSON `.json`), then:

```bash
task dev:cloak:sync-bw -- ./bitwarden_export.json
```

This prints the TOML to pipe into `sops modules/secrets.yaml --extract '["cloak"]'`. The `scripts/bw-to-cloak.sh` converter is also usable standalone:

```bash
./scripts/bw-to-cloak.sh bitwarden_export.json > ~/.cloak/accounts
```

`totp-cli` was replaced by `cloak` — it covers the same use case with simpler TOML storage.

### Removing authorized-keys legacy

Once all hosts have been rebuilt with `ssh.ca.enable = true`, the `authorized-keys.nix` / `authorized-keys.json` gist fetch in `base-node.nix` is dead weight — it falls back silently and can be removed at your leisure.

- The NAS client recovery profile now lives in `modules/profiles/nas-client.nix`, which automounts `/Volumes/data` from `thinsandy` for non-`thinsandy` hosts so the compatibility path stays available without relying on `hosts/common/localmounts.nix`.
- The `xs` runtime, `xs-helper` CLI, and `xs-materializer` binary are packaged via the flake (`packages.*.xs`, `packages.*.xs-helper`, and `packages.*.xs-materializer`). Fleet members should consume those packaged outputs rather than ad-hoc `go build` from the repo.
- `xs-helper` remains the shell-first operator wrapper, while `xs-materializer` is the Go implementation used for `task_view` context-pack materialization. They are versioned in lockstep inside this repo: `pkgs/xs-helper.nix` wires the wrapper to the packaged `pkgs/xs-materializer.nix` output, and `scripts/task/xs-helper.sh materialize` now hydrates CAS-backed xs envelopes before piping normalized events into the materializer.
- Direct `xs` usage is still the source-of-truth debugging path when validating stream shape or CAS retrieval behavior, but normal operator/fleet flows should go through the packaged wrapper/tasks instead of bespoke local build steps.
- Service-user OAuth/session management uses `task agents:oauth:*` wrappers (e.g., `agents:oauth:login:nullclaw:codex`, `agents:oauth:exec:nullclaw:codex -- whoami`). The helper sets `HOME` and `XDG_*` correctly for each service user, so you do not need to remember raw `sudo -u ...` incantations.
- The experimental devcontainer configuration was reverted; there is no current repo-provided devcontainer image, so use the Taskfiles, flake outputs, and hosted workflows directly.

## Recent changes

**Last updated: 2026-05-08**

**2026-04-30 — Task system consolidation.** Deprecated legacy task aliases and menus, directing users to new `infra:` and `dev:` prefixed tasks. Simplified `checks:nullclaw:smoke` tasks and enhanced `dev:git` tasks with AI commit integration.

**2026-04-23 — Manifest and dead-code cleanup.** The AI-host manifest system (`taskfiles/ai-host-manifest.json`, `scripts/task/ai-host-*.sh`, and `taskfiles/services-ai-hosts.yml`) was removed. Host menus and validation tasks now use static host lists and direct smoke checks. The `modules/user/ai/` directory and `modules/goodies.nix` were also removed; nothing in active host configs imported them. See `AUDIT.md` for the full decision log.

## Documentation

### Quick Reference
- `AGENTS.md` - Agent routing helpers and task namespace summary
- `docs/task-control-plane.md` - Task namespace policy and workflow examples
- `taskfiles/README.md` - Taskfile ownership map and shard reference

### Deployment
- `.agents/deploy/README.md` - Deploy routing and guardrails
- `.agents/deploy/hosts/*.md` - Per-host deployment exceptions
- `docs/nullclaw-fleet-pattern.md` - Nullclaw deployment standardization
- `USB.md` - Sledgehammer live USB creation guide

### Development
- `docs/codex-handoff.md` - Codex session orientation
- `NIX-REFERENCE.md` - Nix patterns and gotchas used in this repo
- `docs/userland-module-map.md` - Userland module structure and ownership
- `docs/userland-package-ownership.md` - Package ownership and role wiring

### Historical
- `AUDIT.md` - AI module cleanup audit (April 2026)
- `HANDOFF-REFACTOR.md` - Refactoring progress (April 2026)
- `TODO.md` - Current work tracking and completed tasks

### Site Management
Manage site targets with `task dev:site:list`; build/preview/deploy the default target with `task dev:site:build`, `task dev:site:preview`, and `task dev:site:deploy`.
