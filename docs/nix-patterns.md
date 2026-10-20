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

## Service module conventions

- Options live under `services.<name>`; composable profiles under `profiles.<name>`.
- An optional file path is `lib.types.nullOr lib.types.path`.
- A secret is injected with systemd `LoadCredential`, never on a command line
  (`rpcSecretFile` in the aria2 module is the reference).

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

Longer-form procedure for the operational half: [`../AGENTS.md`](../AGENTS.md)
(routing) and the `infra` skill (deploy, rebuild, rollback).
