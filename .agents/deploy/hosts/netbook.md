# netbook — pinned boot chain, push deploy

Alice's travel netbook (N3060, 1.8 GiB, eMMC). It is a flake host, but the only
one whose boot chain is fixed: **newer kernels produced an initrd this box could
not mount root from**, so the machine builds from `inputs.nixpkgs_25_11` in
`flake.nix`, pinned to the exact revision it boots (25.11.12484.b6018f87da91).
Same revision ⇒ the kernel and initrd derivations are the same store paths the
host already runs, which is what makes a flake deploy safe here.

Moving the host forward means changing that input and **boot-testing it**, not
editing `hosts/netbook/configuration.nix`. The host carries no global module
chain: its own configuration is the whole system, plus `inventoryModules`.

## Deploy

```bash
task infra:apply:host:netbook                               # at home, LAN target
TARGET=root@100.72.110.107 task infra:apply:host:netbook    # travelling (tailnet)
```

`scripts/task/deploy-netbook.sh` stages the tree on frieren, builds the toplevel
there (`--builders ""`: the pinned release is substitutable, so nothing compiles;
`REMOTE_ONLY=1` sends compilation to nixbuild.net instead), guards it on the
target, `nix copy`s the closure over the LAN, then activates the **built** system
with `nix-env -p /nix/var/nix/profiles/system --set` + `switch-to-configuration`.
No flake evaluation and no compiler on the netbook.

Measured 2026-10-22 on frieren: `--max-jobs 0` (nixbuild.net) 2m28s; toplevel
`…-nixos-system-netbook-25.11.20260630.b6018f8`, closure 6.6 GB — only the paths
the host lacks travel, not the closure.

## The two guards (both before anything is copied)

| Guard | Refuses | Override |
| --- | --- | --- |
| boot chain — new kernel/initrd store path ≠ running | exit 3 | `ALLOW_KERNEL_CHANGE=1` |
| `/etc/nixos` drift — `configuration.nix` edited since the last deploy | exit 4 | `ALLOW_CONFIG_DRIFT=1` |

The boot-chain guard is the anti-brick check. The drift guard covers the other
direction: `/etc/nixos` stays on the machine as a fallback, so a local
`nixos-rebuild` from an edited copy would deploy something the flake cannot see.
After activating, the deploy records `system=` and `config-sha256=` in
`/etc/nixos/.flake-managed` (plus a `FLAKE-IS-TRUTH` note), and `ACTION=verify`
reports when the running system or that file no longer matches.

`ACTION=preflight` (or `verify`) is read-only: reachability, what the host is
running, drift against the recorded manifest, failed units, disk. Run it first
when the host comes online.

## Preconditions

- **Root ssh by key from frieren.** `nix copy` writes to the store, so it needs
  root, and the key is declared in `configuration.nix` (`deployKey`, the same one
  alice has). If root does not have it yet the push fails before touching
  anything; add it once with `ssh alice@… 'sudo tee -a /root/.ssh/authorized_keys'`.
- **Port 22 must be the real sshd.** This host does not enable Tailscale SSH, so
  a tailnet target does not hit the browser check that hangs unattended runs on
  delphi. If that ever changes, deploys must go over the LAN.
- **`/etc/nixos` is a fallback, not the source.** Nothing updates it any more.

## Rollback

`task infra:rollback:host:netbook` — `nix-env --rollback` on the system profile,
then that generation's `switch-to-configuration switch`. No rebuild, no eval.
