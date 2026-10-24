# Nix patterns & gotchas

The things that bit this tree once and would bite it again. Each entry says what
fails, why, and the fix that is actually in the repo.

## Formats go through tools, not text edits

[[flake/policies.nix#toml-through-a-tool]] — a hand-edited `inventory.toml`
produced unparseable TOML and nothing noticed until another tool read it.

**yq picks its parser from the path extension.** `yq -i '<expr>' some.toml` is
correct; hand the same expression `/tmp/inv.test` and yq falls back to YAML, reads
`[metadata]` as a flow sequence, and dies with `cannot index array with
'metadata'` while writing nothing. Keep the `.toml` extension, or pass
`-p toml -o toml` explicitly (`scripts/task/modules-menu.sh` does).

**yq's TOML output collapses multi-line arrays**, so *any* yq write reformats
`inventory.toml` — formatting, not data loss.

**`yq -i -f script.yq file.toml` silently ignores the script** (found 2026-10-15,
yq v4.54.1): exits 0, rewrites the file, applies nothing — the identity transform,
which is why `git diff` looks like it worked. `yq --from-file script.yq -i
file.toml` applies. Prefer an inline expression, put `--from-file` before `-i`, and
verify the *effect* (`nix eval --raw .#inventory.json` before/after), not the diff.

```bash
yq '.hosts | to_entries | length' inventory.toml          # read; exits 1 on parse error
yq -i '.hosts.eisen.managed = true' inventory.toml        # write (path must end .toml)
yq -p toml -o toml -i '.hosts.eisen.managed = true' f.toml # explicit, safe in scripts
task checks:toml:lint                                     # prove every tracked .toml parses
```

Better still: `inventory.toml` is compiled by `lib/inventory.nix` — read it with
`task dev:inventory:json` instead of re-parsing it. How the file is *shaped*:
[`inventory-schema.md`](./inventory-schema.md).

## Non-obvious Nix

- **`//` is shallow and right-biased**: `{ a.x = 1; } // { a.y = 2; }` loses
  `a.x`. Use `lib.recursiveUpdate` for a deep merge.
- **Conditionals**: `lib.mkIf`/`lib.mkMerge`, `lib.optionalAttrs` for attrsets,
  `lib.optionals` for lists.
- **Priorities**: `lib.mkDefault` < `lib.mkOverride N` < `lib.mkForce`. A weaker
  override (`mkOverride 1500`) lets a hardware module win without a conflict.
- **Pipes, not `let` chains**, for 2+ transformations
  [[flake/policies.nix#pipe-operators-declared]] — a box that cannot parse the
  tree is on an older Nix: add the flag, do not rewrite the code.
- **Boot options** are `config.profiles.boot.systemd-boot` / `.efi`, not
  `boot.loader.*`.
- **The user is a constant**: import `modules/global/user.nix`; do not hardcode a
  path or the login name.
- **A file header is one line** [[flake/policies.nix#nix-header-budget]].

## Build-budget traps

A module that overrides a package re-derives it, misses the binary cache, and
spends the month's build budget. Two are fixed in place and must stay fixed:

Both live in one file, and **that file's comment is the home** — the rationale is
next to the code that would break: `hosts/frieren/paperless.nix` (§Tika,
§Gotenberg). The index is all this page keeps:

| Where | Trap |
| :--- | :--- |
| `hosts/frieren/paperless.nix` | module-level `tika` override → uncached Maven build |
| `hosts/frieren/paperless.nix` | real chromium (~300 MiB) for a route Paperless never uses |

[[flake/policies.nix#paperless-closure-traps]]

Before deploying anything referencing Java (Maven/Gradle), Go or Rust, run
`nix build --dry-run` and confirm the closure is substitutable.

## Reclaiming store space: the collect is only half the job

GC frees paths that **no root reaches**. A generation is one kind of root, not
the only kind: a `result` symlink from a build nobody uses, a per-user
home-manager gcroots link, `/run/booted-system`, a `nix profile` entry — each one
pins a whole closure. `nix-collect-garbage` then reports success and frees
nothing, which reads as "GC is broken" when the answer is "something is still
alive".

**The tell: generations deleted, store size unchanged.**

```bash
sudo nix-store --gc --print-roots | grep -v -e /proc/ -e /sys/      # 2 s

df -h /nix                                 # what is actually left
sudo du -sh /nix/store                     # what the store holds
nix path-info -Sh /run/current-system      # what the running closure costs
```

Store ≈ current system + booted system is healthy. A store several GiB larger
than those two is rooted garbage, not data.

Measured on netbook 2026-10-22, after pruning to a single generation: 15 GiB in
`/nix/store` against a 6.7 GiB running closure, and three roots held the gap.
Removing them and collecting again freed **7.2 GiB / 14,702 paths**.

| Root | Held |
| :--- | :--- |
| `/etc/nixos/result` (a `nixos-rebuild build` from Sep 30) | 5.9 GiB |
| `~devji/.local/state/home-manager/gcroots/current-home` | 3.8 GiB |
| `~alice/.local/state/home-manager/gcroots/current-home` | 380 MiB |

Remove the **symlink**, never the store path it points at, then collect:

```bash
sudo rm /etc/nixos/result
sudo rm ~alice/.local/state/home-manager/gcroots/current-home
sudo nix-collect-garbage -d        # deletes old generations, then collects
sudo nix store gc                  # or collect without touching generations
```

A dangling `gcroots/auto` link is pruned by GC itself; a root that is still
valid stays until the symlink goes. Never `rm -rf` inside `/nix/store` — GC is
the only safe deleter, because only it walks the reference graph.

**A small reclaim is not a failed reclaim.** Ten same-nixpkgs generations on
netbook returned 140 MiB: they share almost every path, so there was little to
free. Compare store size against the closure, not against the generation count.

Fleet defaults that do the routine half: `nix.gc` runs `--delete-older-than 10d`
(`modules/global/global.nix`) and `nas-client.nix` prunes roots that live on an
absent NAS before `nix-gc` starts. Neither touches a root outside those two
patterns — which is why the `--print-roots` check belongs in the operator's hands.

## Service module conventions

- Options live under `services.<name>`; composable profiles under `profiles.<name>`.
- An optional file path is `lib.types.nullOr lib.types.path`.
- A secret is injected with systemd `LoadCredential`, never on a command line
  (`rpcSecretFile` in the aria2 module is the reference).
- **A unit exists because a capability is declared, not because a hostname is
  listed** [[flake/policies.nix#systemd-units-are-capability-gated]]. The
  capability is the option that installs the thing the unit needs —
  `programs.niri.enable` for anything bound to `graphical-session.target`, a
  systemd `Condition*` for a file nobody declares — and the compositor's
  `spawn-at-startup` starts that target and imports `WAYLAND_DISPLAY`, so
  session units are pulled in by a session instead of by home-manager activation.
- **A daemon states its crash-loop class where it is declared**
  [[flake/policies.nix#systemd-daemons-declare-their-class]]:
  `unitConfig.X-Fleet-Role = "daemon"` (must come back: `Restart` set, and
  `StartLimitIntervalSec = 0` with `RestartSteps`/`RestartMaxDelaySec` so the
  default 5-starts-in-10s limit cannot retire it) or `"bounded"` (retiring is the
  point, so carry an explicit `StartLimitBurst`). Both the class and its
  consequence are asserted per host by `modules/systemd-policy.nix`, over the
  evaluated unit set — so the failure names the unit, not a daemon that quietly
  stopped days later.

## CI quirk

CI builds with `nix build -L .?submodules=1#…`: `?submodules=1` is what makes
`modules/secrets` visible to the evaluator. A local build does not need it because
the submodule is already checked out — and CI cannot drop it
[[flake/policies.nix#ci-builds-config-and-gate]]. Pipeline itself:
[`ci-pipeline.md`](./ci-pipeline.md).

## Agent failure modes

Failure modes that do not exist on an FHS distro, in the order they cost time:

1. **A non-login SSH shell has no profile `PATH`.** `ssh host 'python3 …'` →
   `command not found` (127) although the package is installed: non-interactive
   sessions never run `/etc/profile`. Use `ssh host 'bash -l -c "…"'`, a full
   `/run/current-system/sw/bin/…` path, or `nix shell nixpkgs#<pkg> -c <bin>`.
2. **`python3` + `python3Packages.foo` in one `nix shell` does not import.** Two
   store paths, no ambient `site-packages`. Compose with
   `nix shell --impure --expr '…pkgs.python3.withPackages (ps: [ ps.websockets ])'`.
3. **Flakes ignore untracked files.** A new module is invisible to `nix build`,
   `nix eval` and `nixos-rebuild` until `git add -N <file>`.
4. **A stale ControlMaster socket hangs every ssh.** Use
   `ssh -o ControlMaster=no host …` for unattended calls, or
   `rm -f ~/.ssh/sockets/*`.
5. **`os.replace` across a symlink into `/run/secrets` fails** (`EXDEV`, then
   `EACCES` on the `0400` tmpfs file). Mutable runtime config gets its own `0600`
   file or a systemd `EnvironmentFile`, never a symlink into rendered secrets.
6. **Upstream FHS binaries** die on `/lib64/ld-linux…`, and even patched ones
   fail on subprocesses: package with `autoPatchelfHook` + full `buildInputs`, and
   give the unit a `systemd.services.<name>.path` with `openssl coreutils bash`.
7. **A `lib.mkForce` firewall scope drops ports you thought you opened.** On a
   scoped host, a new service port also goes in `scopedTCP` in
   `hosts/<host>/firewall-scope.nix`.
8. **Interactive CLIs crash on piped stdin** (`simplex-chat: Prelude.undefined …
   System.Terminal.Platform`). Use the non-interactive flag (`-e "…"`) or the
   daemon's JSON-RPC.
9. **Heredocs over ssh expand on the wrong machine.** Quote the tag (`<< 'EOF'`),
   or pipe the script in: `ssh host 'python3' < script.py`.
10. **A negative narinfo cache makes a warmed path look missing** for an hour.
    Pass `--option narinfo-cache-negative-ttl 0` on every cache query
    [[flake/policies.nix#negative-cache-disabled]].
11. **Disabling a compositor is not a port.** `base-desktop-environment` plus
    `programs.niri.enable = lib.mkForce false` leaves niri, DMS, zen and the
    portal/keyring stack installed behind whatever WM you added; the session
    changes and nothing it opens does. Fork the profile and the HM module list
    instead — enforced by [[flake/policies.nix#desktop-fork-not-disable]], which
    also catches dropping infrastructure the profile carried (tailscaled, the NAS
    mount behind `~/Documents/nixconfig`).

Longer-form procedure for the operational half: [`../AGENTS.md`](../AGENTS.md)
(routing) and the `infra` skill (deploy, rebuild, rollback).
