---
name: nixos-deploy
description: Rebuild and activate a NixOS configuration on Eisen (or any fleet host) over SSH — the systemd-run detachment, done-file polling, and the polkit activation workaround. Encodes the traps: no pgrep, no nohup, no direct activation over SSH.
---

# nixos-deploy

**Runs on:** any NixOS fleet host, via SSH from your workstation. Written for Eisen (`devji@eisen`), same pattern elsewhere.
**Use when:** rebuilding a host after a flake change (`nixos-rebuild test`), activating a built closure, or checking a build's result.
**Pick me over:** `infra` (host lifecycle) when you need the exact SSH-safe rebuild/activate sequence, not the task wrapper.

## The traps (read first)

- **Tailscale SSH kills the whole session's processes on disconnect.** `nohup` / `setsid` / `disown` do **not** survive it. Long jobs must run under `systemd-run --user` (survives disconnects).
- **Never detect a build by `pgrep -f "nixos-rebuild …"`.** The pattern self-matches the remote bash wrapper. Poll a **done-file** marker instead.
- **Activation over SSH fails on polkit** ("requires interactive authentication"). Build with `nixos-rebuild test`, then activate the built closure directly via `switch-to-configuration test`.
- **SSH tunnel drops frequently** (broken pipes). Keep every SSH call short. Run long jobs detached and poll.
- Use `test`, not `switch` (boot entry unchanged) unless you intend to change the boot entry.

## Rebuild (detached, poll a done-file)

```bash
ssh devji@eisen 'rm -f /tmp/eisen-rebuild.done /tmp/eisen-rebuild.log; \
  systemd-run --user --unit=eisen-rebuild.service --collect --quiet bash -c \
  "cd /home/devji/Documents/nixconfig && nixos-rebuild test --flake .#eisen \
  > /tmp/eisen-rebuild.log 2>&1; echo \$? > /tmp/eisen-rebuild.done"'
```

Poll (short calls, sleep between):

```bash
ssh devji@eisen 'cat /tmp/eisen-rebuild.done 2>/dev/null || echo BUILDING'
```

## Activate (the polkit workaround)

Get the built closure from the log, then activate it directly:

```bash
# From the log: the switch-to-configuration path
grep -o /nix/store/.*nixos-system-eisen.*switch-to-configuration /tmp/eisen-rebuild.log | tail -1
# Activate (exit 0 = success)
sudo -n /nix/store/<hash>-nixos-system-eisen-26.11.20261005.aa48d34/bin/switch-to-configuration test
```

`sudo -n` works on Eisen (passwordless sudo for devji). If the grep finds no path, the build failed — read the log's `error:` lines first.

## After activation

- Restart any service whose config changed (e.g. `sudo systemctl restart llama-swap.service` after a model-cmd change). A config change does not restart the service by itself.
- If a service holds a port and you are replacing its binary, stop the old one first (two processes cannot hold the same port).

## Repo (which checkout)

Work in `~/Documents/nixconfig` (the NAS copy, current main). The `~/nixconfig` checkout is behind and has an unrelated history — do not merge between them by hand. Commit with conventional messages (`feat(eisen): …`, `fix(eisen): …`, `docs(eisen): …`, `perf(eisen): …`).

**Confirm before:** `switch-to-configuration switch` (changes the boot entry), any `git push --force` (history rewrite — see `confirm-before-destructive`).
