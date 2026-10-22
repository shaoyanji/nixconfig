# CI Pipeline

One workflow, `.github/workflows/nixcachix.yml`, builds the fleet on GitHub
runners and pushes to the `shaoyanji` cache. There is **no build matrix to
edit**: which hosts build is derived from `inventory.toml` on every push.

## What decides

`scripts/ci/detect-affected-hosts.py` maps the changed paths to hosts, then to a
runner; the workflow dispatches one job per affected host.

| Field in `inventory.toml` | Becomes                                                                |
| :------------------------ | :--------------------------------------------------------------------- |
| `arch`                    | runner OS: `x86_64-linux → ubuntu-latest`, `aarch64-linux → ubuntu-24.04-arm`, `aarch64-darwin → macos-latest` |
| `kind`                    | flake attribute: `nixosConfigurations.*`, `darwinConfigurations.*`, `homeConfigurations.*` |
| `ci = false`              | excluded (unfree NVIDIA on `stark`/`kellerbench`)                      |
| `status = "preserved"`    | excluded (dormant hosts are not check targets)                          |

Path rules:

- Documentation and meta changes (`*.md`, `docs/`, `taskfiles/`) allocate **zero
  build** runners. The `docs-budget` job is not in the matrix and runs anyway, so
  a doc-only push still has a gate.
- `hosts/<host>/**` builds that host only, on its own architecture.
- Shared Nix (`modules/**`, `flake.lock`) anchors to `frieren` by default; the
  manual dispatch input `shared_strategy` switches to `all` or `none`.

Commit-message overrides, checked before anything else: `[skip ci]` / `[ci skip]`
builds nothing, `[ci all]` builds every CI-eligible active host, `[ci h1,h2]`
builds the named hosts even if their inventory entry excludes them.

## What it builds

Each affected host gets two builds, both with `?submodules=1` (the `modules/secrets`
submodule is not optional in CI):

```bash
nix build -L .?submodules=1#<attr>                          # the closure
nix build -L .?submodules=1#hostChecks.<arch>.<host>        # the module-system gate
```

The runner is configured with `experimental-features = nix-command flakes
pipe-operators`: the tree uses `|>`, and a runner without it cannot parse the
flake at all. That is why the prefix is set in `install-nix-action` rather than
in a host config.

A separate `sops-drift` job runs `scripts/task/sops-drift-check.sh --repo-only`
with `continue-on-error`, so recipient drift is reported without failing a build.

The `docs-budget` job runs on every push and builds
`checks.x86_64-linux.docs-budget` — the same gate as `task ops:docs:budget` and
`nix flake check`, not a second implementation. It counts lines at eval time
(manual 1200, ledger 150, root stubs 10 and pointing at `AGENTS.nix`) and fails
the job on a violation, so documentation cannot grow past its `SCHEMA.md` §2
budget just because the change touched no host.

## The boot canary (`modules/services/**`)

Neither of the two builds above proves the system reaches userspace: a host can
evaluate, assert and build, then die in stage-1 (netbook generation 50 booted a
systemd-initrd that never handed off, with every gate green). The third gate
runs the config.

When a push touches `modules/services/**`, the `boot-canary` job boots each host
in `plan`'s matrix — the affected hosts, not the fleet — with:

```bash
nix build -L .?submodules=1#hostBootChecks.<arch>.<host>
```

That is a NixOS VM test (`flake/boot-checks.nix`) over the host's own module
list, asserting `multi-user.target` and PID 1 being systemd. It runs after
`build-machines`, so the closure is already substituted, and it needs `/dev/kvm`
(the job enables it); without KVM a boot falls back to TCG and takes tens of
minutes. Locally the same gate is `task checks:boot HOST=<host>` — one host,
under the OOM watchdog, `--builders ""` so it can never spend nixbuild.net
budget.

What it cannot see: hardware. QEMU has no eMMC, NVIDIA or TPM, so a regression
that only reproduces on the target's storage controller or GPU is out of reach —
that half of netbook gen 50 was never a VM bug. The gate is still the only one
that runs the configuration it is about to promote.

## Operating it

| Task                        | What                                                              |
| :-------------------------- | :---------------------------------------------------------------- |
| `task dev:ci:plan`          | affected hosts for unpushed commits vs `origin/main`              |
| `task dev:ci:plan:worktree` | the same for the current working tree                             |
| `task dev:ci:trigger:<host>`| re-run the workflow for one host (`all`, `auto` accepted)          |

Making a host CI-eligible is an inventory edit (`ci = true`, `status = "active"`);
retiring it is `status = "preserved"` or removing the entry. Anything that edits a
matrix is editing a list this pipeline does not read:
[[flake/policies.nix#ci-matrix-is-inventory]]
[[flake/policies.nix#ci-dormant-hosts-excluded]]
[[flake/policies.nix#ci-builds-config-and-gate]]
[[flake/policies.nix#ci-doc-budget]]
[[flake/policies.nix#ci-task-graph-pin]]
