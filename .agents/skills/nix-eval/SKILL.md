---
name: nix-eval
description: "Cheapest-instrument ladder for answering Nix questions — one-off /tmp files, flake attr names, host assertion checks, substitutability — with measured costs and the evals that must never run on this fleet."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['nix', 'eval', 'performance', 'verification', 'one-off']
    related_skills: ['task-plane', 'host-facts', 'checks', 'dev']
---

# nix-eval — ask the cheapest question that can answer you

The rule from `AGENTS.md`, restated because it is the whole skill:

> **eval to catch a config error · build to prove a closure · size to plan a build**

Most "I need a script for this" questions are one `nix eval` away. Write the
expression to `/tmp`, evaluate it, delete it. Do not add a `scripts/task/*.sh`,
do not add a Taskfile task, and above all **do not build** to answer a question.

## Instrument ladder (measured 2026-10-17 on `frieren`, 11.5 GiB, warm eval cache)

| Question | Instrument | Measured | Forces |
| :--- | :--- | :--- | :--- |
| Does this file parse? | `nix-instantiate --parse f.nix` | 0.030 s | syntax only |
| Evaluate a standalone file | `nix eval --file /tmp/q.nix --json` | 0.030 s | that file, pure |
| Trivial expression | `nix eval --expr '1 + 1'` | 0.030 s | nothing |
| One host's registry record | `nix eval --json .#inventory.hosts.<h>` | 0.315 s | registry, **no host config** |
| Which hosts exist? | `nix eval --json .#nixosConfigurations --apply builtins.attrNames` | 2.42 s cold / 0.08 s warm | attr NAMES only |
| Does host X's config type-check + assert? | `nix eval --raw .#hostChecks.x86_64-linux.<h>.drvPath` | 21.6 s | module system + every assertion |
| Is a path substitutable? | `nix path-info --store http://192.168.3.25:5000 <path>` | 0.344 s | nothing (HTTP) |
| Would a build compile locally? | `nix build .<attr> --dry-run` | evaluates drv graph | derivation graph, **no build** |
| Whole toplevel for one host | `nix eval --raw .#nixosConfigurations.<h>.config.system.build.toplevel.drvPath` | **>120 s, swaps** on frieren | whole system graph |
| Every flake output | `nix flake check` | **339.78 s / 6078.5 MiB / SIGKILL 137** | **never on this NAS** |

**Never point any row at a preserved host.** `status = "preserved"` hosts are
dormant and some are known-broken (cassini's `homeDirectory` conflict predates
the current tree), so an eval that fails there says nothing about your change.
The deploy/apply/warm gates treat them as a warning and exit before evaluating;
do the same by picking an **active** representative per chain.

Stop at the first row that can fail for the reason you care about. The 21.6 s
`hostChecks` row is the real config gate: it is the same conditions the toplevel
asserts, without instantiating the closure. A local `nixos-rebuild switch` already
forces the toplevel, so never run the `.drvPath` eval as a pre-rebuild step — that
is a duplicate evaluation. Reach for the toplevel `.drvPath`
only when the change is about derivation-level wiring, and scope it to the hosts
the change reaches — never the fleet, never in one process.

## One-off file: the replacement for a throwaway script

```bash
# 1. pure evaluation of a standalone expression
cat >/tmp/q.nix <<'EOF'
let
  hosts = [ "frieren" "fern" "poseidon" ];
  pick = h: builtins.replaceStrings [ "-" ] [ "_" ] h;
in
  map pick hosts
EOF
nix eval --file /tmp/q.nix --json | toon -e      # 0.03 s, no flake, no network
rm /tmp/q.nix
```

```bash
# 2. project ONE attribute out of a large value instead of dumping it
nix eval --json .#inventory.hosts.frieren --apply 'h: { inherit (h) hostname arch kind status role; }' | toon -e

# 3. probe whether something exists WITHOUT forcing it
nix eval --json .#nixosConfigurations --apply 'cs: builtins.attrNames cs' | jq 'index("delphi")'
#   attrNames gives null/0 when absent; nothing is evaluated.
#   builtins.getFlake on a local path needs --impure and re-parses the flake,
#   and tryEval does NOT catch "cannot call getFlake on unlocked flake reference".

# 4. read a repo file inside an eval (impure, local only)
nix eval --impure --raw --expr 'builtins.readFile ./inventory.toml' | head -5
```

Rules that keep these cheap:

- `--apply` projects **before** printing: `.#nixosConfigurations` alone forces
  every config, `. … --apply builtins.attrNames` forces none.
- `--raw` only for strings. Use `--json` for ints/attrsets (`--raw` on an int
  prints it but breaks scripted comparisons silently).
- A one-off file that needs `pkgs` is no longer cheap: `import <nixpkgs>` pulls
  NIX_PATH and a full nixpkgs eval. If you need packages, you want a real
  `nix build`/`nix shell`, not an eval.
- `nix eval --file` is pure by default; anything reading the filesystem, env or
  `builtins.currentSystem` needs `--impure` and should say so in the comment.

## Anti-patterns this repo has already paid for

| Anti-pattern | What actually happens |
| :--- | :--- |
| `nix eval .#nixosConfigurations.<h>.config.networking.hostName` as a "smoke test" | Forces ONE option, type-checks nothing else. A real `dispatcherScripts.*.type = "up"` error survived it on four hosts (EXP-114). |
| `nix build … --print-out-paths` as a *check* | It **starts a build**. It launched a full `stark` compile and hung 400 s (EXP-113). Use `nix eval --raw "<attr>.outPath"`. |
| `nix flake check` "to be thorough" | 23 configs in one process: 339.78 s, 6078.5 MiB, exit 137, 62 % IO-stall on an 11 GiB host. |
| `nix-shell -p python3` to parse JSON | `jq`/`yq` are already in the profile; the shell costs network + a nixpkgs eval. |
| Building on a non-builder host | EXP-107: warm the closure on the builder (`infra:warm:host:<h>`), make the host substitute. `checks:build:route` answers this read-only. |

## Keyless environments (CI sandboxes, fresh clone)

Safe without sops/age keys: `nix eval`, `nix-instantiate --parse`,
`alejandra --check`, `deadnix`, `statix check`, `nix path-info`.

**Not** keyless: `task checks:quick` (its sops-drift step), any `infra:*`
secret or deploy task. Sops-nix only declares file paths at eval time, so
evaluation never needs the keys — activation does.

## Done means

- The expression failed for the reason you were testing, not from a typo —
  run `nix-instantiate --parse` first when unsure.
- You can name the cost tier of what you ran (table above) and why the next
  tier down could not answer it.
- Nothing was built, fetched, or switched as a side effect.
