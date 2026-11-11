# Nix patterns & gotchas

The things that bit this tree once and would bite it again: what fails, why, and
the fix that is actually in the repo.

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

**`yq -i -f script.yq file.toml` silently ignores the script** (2026-10-15, yq
v4.54.1): exits 0, rewrites the file, applies nothing — the identity transform,
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
- **Modules import by name**: `self.modules."profiles.base-node"`, never a sibling
  path. `.#modules` keys every file under `modules/`
  (`flake/nix-registry.nix`); `checks.<system>.nix-registry` fails a duplicate
  or a name that resolves to nothing.
- **Two modules on one key is a build error, not a merge**: home-manager
  asserts when fzf and atuin both bind Ctrl-R, and the message only appears at
  evaluation of the affected host's system. Pick the owner in the same module
  that enables the second one [[flake/policies.nix#one-history-widget]].
- **A file header is one line**, and rationale that is longer than that belongs
  in `docs/` or a skill with one line pointing there.

## Build-budget traps

A module that overrides a package re-derives it, misses the binary cache, and
spends the month's build budget. Both known traps live in one file, and **that
file's comment is the home**: `hosts/frieren/paperless.nix` (§Tika: a
module-level `tika` override → uncached Maven build; §Gotenberg: real chromium,
~300 MiB, for a route Paperless never uses)
[[flake/policies.nix#paperless-closure-traps]].

Before deploying anything referencing Java (Maven/Gradle), Go or Rust, run
`nix build --dry-run` and confirm the closure is substitutable.

### The gate for a fleet fix, and the exception

A fix costs what it changes. A frieren nightly upgrade measured **13 min 37 s**
for a documentation commit — 5 min 46 s of CPU on a 2-core NAS, none of it a
compile: the 03:15 `nix-gc` deleted 90 `-source` paths (a flake's inputs are
unreferenced the moment its evaluation ends) and 04:00 `autoUpgrade` spent 8.5 of
those minutes re-copying ~20 of them. `services.flakeGcRoot` now roots the
deployed flake and its inputs at 05:00, so the GC cannot take them.

**The trap worth remembering** is the other fix: a submodule tree is a *different
source path* from the same commit's GitHub tarball, so a warm from one is worth
nothing to an evaluation of the other — which is why frieren rebuilt 34
derivations on a commit CI had already built. `?submodules=1` is not legal on a
`github:` ref; a plain git tree and the tarball at one commit *do* resolve to one
`/nix/store/…-source`, so `.#` is the ref to warm.

So the gate for a fleet fix is cheap, and stays cheap:

```bash
nix build --builders "" .#hostChecks.<arch>.<host>   # the config evaluates
bash scripts/task/warm-host.sh --check <host>        # the cache already serves the closure
```

A real build — on CI, never on the NAS — is for a change that **adds
derivations**: a Python package, model weights, a Rust or Go binary. Anything else
is a fix, and a fix that needs a closure rebuild was built on the wrong tree.
Long form: [`../AGENTS.md`](../AGENTS.md) §5.

### A config-only delta does not need the CI round trip

The gate answers "is this closure servable", which is the right question when a
change adds derivations and the wrong one when it only alters generated text.
Measured on delphi 2026-11-04 (a SearXNG `search.formats` line): **18
config-generated derivations, 9 s to build** — where the CI path would have spent
a push, a runner, a cachix upload and a cache round trip on the same 18 files.
Compare a real addition: an aarch64 paperless build is 20 derivations, ~41 min.

So measure the pending set and decide on its **contents**:

```bash
nix build --dry-run --json --builders "" <host toplevel>   # counts, builds nothing
```

When every entry is config-generated, build on the target and skip CI. The test is
that list, never the diff size: a one-line module edit can pull a new package, and
that one belongs in CI.

## Reclaiming store space: the collect is only half the job

GC frees paths that **no root reaches**, and a generation is one kind of root: a
stale `result` symlink, a per-user home-manager gcroots link, `/run/booted-system`,
a `nix profile` entry each pins a whole closure. `nix-collect-garbage` then reports
success and frees nothing, which reads as "GC is broken" when the answer is
"something is still alive". **The tell: generations deleted, store size unchanged.**

```bash
sudo nix-store --gc --print-roots | grep -v -e /proc/ -e /sys/      # 2 s
df -h /nix                                 # what is actually left
sudo du -sh /nix/store                     # what the store holds
nix path-info -Sh /run/current-system      # what the running closure costs
```

Store ≈ current system + booted system is healthy; several GiB more is rooted
garbage, not data. Measured on netbook 2026-10-22: 15 GiB in `/nix/store` against
a 6.7 GiB running closure, and three roots held the gap — `/etc/nixos/result` (a
September `nixos-rebuild build`, 5.9 GiB) and two home-manager gcroots links
(3.8 GiB, 380 MiB). Removing the symlinks and collecting again freed **7.2 GiB /
14,702 paths** — remove the **symlink**, never the store path it points at:

```bash
sudo rm /etc/nixos/result
sudo rm ~alice/.local/state/home-manager/gcroots/current-home
sudo nix-collect-garbage -d        # deletes old generations, then collects
sudo nix store gc                  # or collect without touching generations
```

A dangling `gcroots/auto` link is pruned by GC itself. Never `rm -rf` inside
`/nix/store`: GC is the only safe deleter, because only it walks the reference
graph. **A small reclaim is not a failed reclaim**: ten same-nixpkgs generations
returned 140 MiB because they share almost every path, so compare store size
against the closure, not the generation count.

Fleet defaults do the routine half: `nix.gc` runs `--delete-older-than 10d`
(`modules/global/global.nix`) and `nas-client.nix` prunes roots on an absent NAS
before `nix-gc` starts. Neither touches a root outside those two patterns, which
is why `--print-roots` belongs in the operator's hands.

## Service module conventions

- Options live under `services.<name>`; composable profiles under `profiles.<name>`.
- An optional file path is `lib.types.nullOr lib.types.path`.
- A secret is injected with systemd `LoadCredential`, never on a command line
  (`rpcSecretFile` in the aria2 module is the reference).
- **A module asks what a host declares, never what it is called**
  [[flake/policies.nix#capabilities-are-traits-not-names]]. Package lists and
  toolchain tiers read `software.traits` (`ai-full`, `dev-full`, `gpu-low`,
  `gpu-high`, `small-screen`, `tpm-identity`, `nas-server`) and the machine's
  `category` (`cloud`, `laptop`, `workstation`); a host that gains a capability
  states it in `inventory.toml`, next to the hardware that justifies it.
  `checks.policies` fails on `builtins.elem hostName`, `hostName ==`, and any
  comparison against a quoted hostname — `hostName != "frieren"` was the same list
  in the negative, hiding in the profile the NAS server also imports.
- **A unit exists because a capability is declared, not because a hostname is
  listed** [[flake/policies.nix#systemd-units-are-capability-gated]]. The
  capability is the option that installs what the unit needs —
  `programs.niri.enable` for anything bound to `graphical-session.target`, a
  systemd `Condition*` for a file nobody declares — and the compositor's
  `spawn-at-startup` starts that target and imports `WAYLAND_DISPLAY`, so session
  units are pulled in by a session, not by home-manager activation.
- **A daemon states its crash-loop class where it is declared**
  [[flake/policies.nix#systemd-daemons-declare-their-class]]:
  `unitConfig.X-Fleet-Role = "daemon"` (must come back: `Restart` set, and
  `StartLimitIntervalSec = 0` with `RestartSteps`/`RestartMaxDelaySec` so the
  default 5-starts-in-10s limit cannot retire it) or `"bounded"` (carry an
  explicit `StartLimitBurst`). `modules/systemd-policy.nix` asserts both over the
  evaluated unit set, so the failure names the unit, not a daemon that quietly
  stopped days later.

## A mount to a sleeping peer must fail fast

`mount.nfs` retries a failed mount for **2 minutes by default** (`retry=`, in
minutes — not the data-path `retrans=`), and a mount whose peer is off by design
pays that on *every* walk of the table, blocking tools that `statfs()` each entry.

- **`duf` cannot be told to skip it.** `--hide-mp <exact>`, `--hide-mp` with a
glob and `--hide-fs autofs` all still block (measured 2026-10-28), because the
probe runs first, and its output is empty while it waits.
- **`df` is not proof the mount is cheap.** It finished in 17 ms only because
coreutils skips autofs entries without a statfs; name the path and it blocks.
- **`btop` and `updatedb` trip the same wire** — the journal fills with automount
requests naming them.

Before the fix a probe took 90 s and ended in `Result=timeout` (systemd killed
`mount.nfs` mid-retry). A cold-vault mount carries two options: `retry=0` (the
connect itself fails in under a second with "no route to host", so nothing is left
to retry) and `x-systemd.mount-timeout=10s` for the other hang class — peer
reachable, handshake stuck. That lands at ~3 s per probe and `Result=exit-code`,
in `profiles/burgernas-client.nix`. The trade: `retry=0` fails on a transient blip
instead of retrying for two minutes, which for an automount is right.

## CI quirk

CI builds with `nix build -L .?submodules=1#…`: `?submodules=1` makes
`modules/secrets` visible to the evaluator. A local build does not need it (the
submodule is checked out) and CI cannot drop it
[[flake/policies.nix#ci-builds-config-and-gate]] — [`ci-pipeline.md`](./ci-pipeline.md).

## `git push` died on the secrets submodule

**Cause gone 2026-11-10:** `modules/env.nix` sets `submodule.recurse = false`, so a
current clone cannot reproduce this. Recorded because an old one can: `git push`
then asked every submodule whether it can push **the superproject's refspec
source** — here `refs/heads/main`, which the submodule does not have:

```
cd modules/secrets; GIT_DIR=.git git submodule--helper push-check refs/heads/main origin main
fatal: src refspec 'main' must name a ref
```

The superproject push never happens (rc=128, measured 2026-11-02) and reads as an
auth problem, because the submodule pushes fine on its own.
`scripts/task/git-push.sh [--dry-run] [remote] [branch]` pushes each submodule's
missing commits to its remote's default branch first, then the superproject with
recursion off; a bare `--no-recurse-submodules` leaves a dangling pointer whenever
the submodule has commits of its own. Every `dev:git:*` push task calls it.

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
    also catches dropping infrastructure the profile carried. The fork is a
    profile under `modules/profiles/` that imports `desktop-client` and declares
    its own session (`dwl-desktop.nix` is the live example); it leaves
    `base-desktop-environment` unimported rather than disabling what it sets.
12. **A comment is not a home for a fact.** Nothing compiles a `#` block:
    `.#knowledgeGraph`, qmd and the skills index are built from `docs/*.md`,
    `.agents/skills/*` and the registry, so an explanation inside a module is
    answerable only by reading that module. Keep the constraint in the `.nix`
    and put the narrative in `docs/` or a skill, with one line pointing there;
    restating what Nix declares is a second home that drifts (the DSM mount's
    `vers=4.1` lives in `modules/profiles/burgernas-client.nix`).
13. **An inherited `PS0` prints the preexec hook at every prompt.** `bash-preexec`
    (sourced by atuin) appends to `PS0`, and bash prints whatever else `PS0` holds
    at every prompt, with `$_` expanded — so one inherited from a parent shell
    reprints itself in every new terminal. Measured 2026-10-27: a fresh foot window
    printed the whole zoxide init script plus `>&2; }`, then the previous command's
    last argument at each prompt. `modules/shell/atuin.nix` clears an inherited
    `PS0` before bash-preexec installs its hook; a live session needs
    `export -n PS0`.
14. **A `git init` in `$HOME` makes every prompt walk the home tree.** Once `~`
    is a repository starship's `git_status` runs there, and Starship 1.x has no
    per-directory switch; the login after such a session feels broken for
    minutes. `modules/shell/home-not-a-repo.nix` points `~/.git` at `/proc`, so
    `git init` in `~` fails instead of arming the trap, and repositories below
    home are untouched.
15. **A shell fragment is inert without the shell module.** `programs.atuin`
    sets `enableZshIntegration = true` on every host, but the `.zshrc` half is
    only linked where `programs.zsh` is enabled (`modules/shell/zsh.nix`); a host
    that logs in to zsh without it keeps zsh's new-user stub and gets no history
    integration at all. Measured on fern 2026-11-01: a 5-line `~/.zshrc`, no
    atuin, no starship, no aliases. The `.nix` keeps the constraint and points
    here (item 12); the missing half is `modules/shell/zsh.nix`.

## An upstream with no tags

`tildegit.org/solderpunk/molly-brown` publishes neither tags nor releases (both
lists empty, 2026-10-29), so "the newest release" can only be the tip of master.
`overlays/molly-brown.nix` pins `src` to master and keeps nixpkgs' own
`vendorHash` — the go module set has not moved since nixpkgs' 2023-02-10 pin —
verified by building the override locally. Only `src` and `version` differ.

Operational half: [`../AGENTS.md`](../AGENTS.md) routing, `infra` skill (deploy, rebuild, rollback).

## A daemon must clear the Kelly gate

A resident helper is a bet, and the stake is a unit, memory, a surface someone has
to reason about, and a failure mode that appears after a logout — so it must beat
what the counterfactual costs an agent, not a cold start. Tokens generate at
~50/s, so a sub-second local round trip is free: a correct answer saves only the
tokens of *naming the argument*, a handful. So:

```
ev   = p * save - (1 - p) * cost        seconds; save may be NEGATIVE
p      measured probability it answers the way the direct call would
save   what one correct answer saves the agent
cost   what one wrong answer costs: the wasted round trip plus the retry
```

Enable only if `save > 0` **and** `ev > 0`. `ev == 0` is off: a coin flip that
pays rent is not enabled, it is tolerated. `save <= 0` cannot be rescued by
accuracy at any `p < 1`.

`flake/daemons.nix` is the registry, `nix eval --json .#daemons.daemons` prints the
arithmetic, and `[[flake/policies.nix#daemon-clears-kelly]]` requires decision and
numbers to agree both ways — including that a justified daemon is not silently off.

| daemon | p | save | cost | ev | verdict |
| :--- | ---: | ---: | ---: | ---: | :--- |
| `edge-caller` | 0.5 | **−1.0 s** | 1.2 | **−1.1** | disable: the *win case* is a loss |

That row is the lesson: the dispatcher's call is 54 bytes against 40, its answer
605 against 217, its round trip 1073 ms against 145 — it loses even when it is
right. A latency claim means nothing against the alternative.

`kg-sidecar` cleared the same gate on 2026-11-02 (441 ms → 28 ms, `p = 1`) and was
removed on 2026-11-07 because the counterfactual moved: 25 ms saved does not pay
27 MB resident, 1383 lines of engine, a socket protocol and a byte-parity gate.
`save` is a claim about *today's* alternative, so `task ops:kg:speed` re-measures
it rather than restating it.

## The eval the graph reads

`nix eval` never answers from its cache, and the evaluation is the cost: on delphi
(2026-11-07, min of 3) `.#knowledgeGraph.graph` is 1686 ms, `.#policies` 5004 ms —
each 15-18 ms warm through `iets`. The task graph left this table when it stopped
being an eval: `taskfile_graph.py report` is 0.6 s cold, reading only the shards.

| layer | keys on | answers in | answers when |
| :--- | :--- | ---: | :--- |
| `kg-graph.sh` file | `HEAD` + `sha1(git diff HEAD)` | ~53 ms with jq | same tree content |
| `iets` tracing cache | the files an eval read | ~16 ms warm | none of them changed |
| a resident daemon | the committed graph | ~28 ms | never, on a dirty tree |

The last row is why the daemon went: it could not answer for the tree you are
editing, which is what the file cache exists for. The middle row is why that file
cache stays: one eval serves every caller.

Two reads sat outside both layers and are the two an agent makes first.
`task help` / `find:` ran go-task's 2.3 s parse twice through a *nested* `task
--list-all --json`, and `notes.sh` re-evaluated a 1 MB document per query. Both
take the cache now (`taskfile-list.sh`; `iets_eval_json`). A cache answers an
eval, not the read: 350 ms of `near`'s 546 ms was tokenising four fields and
downcasing every body, which a word-boundary regex does in 130 ms — exact for a
plain word (every `[a-z0-9]+` run is a token), not for one with a separator
(`\bnix\-cache` matches inside `nix-cache-info`), so those keep the token
comparison. 547 generated queries rank identically, scores included.

`iets` is **eval only**: it ignores a flake's `nixConfig`, so a build through it
would lose the LAN and substituter set and compile what the cache serves; every
build path keeps `nix`. `checks:kg:iets` compares its bytes against `--no-cache`
— a faster evaluator that renders a different value is a quieter answer, not a
faster one.
