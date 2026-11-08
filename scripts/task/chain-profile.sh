#!/usr/bin/env bash
# chain-profile.sh — what one feature costs a gate, measured on a stub host.
#
# Rung 3 of `eval-cost-ladder` (AGENTS.nix): a host gate is ~78 % its chain, so
# the unit of eval cost is the feature, not the host file. This evaluates the
# same stub host once per feature subset and reports wall clock plus peak RSS,
# which is the number the ladder's exit criteria are written against.
#
# The measurement forces `config.assertions` — the same thing `checks:host`
# forces (flake/host-check.nix) — so the two numbers are comparable. Nothing is
# built, no builder is contacted, and the stub is deliberately not a real host:
# assertions it fails are counted, not thrown, because a missing boot loader
# says nothing about what the chain costs.
#
#   FEATURES="base nixos dms" bash scripts/task/chain-profile.sh
#   bash scripts/task/chain-profile.sh base nixos        # subset per argument
set -euo pipefail

root=$(git rev-parse --show-toplevel)
features=("$@")
if [ ${#features[@]} -eq 0 ]; then
  read -r -a features <<<"${FEATURES:-base nixos dms}"
fi
list=$(printf '"%s" ' "${features[@]}")
# EXTRA_NIX appends one override module, e.g. to price the half a chain spends on
# something a host could do without:
#   EXTRA_NIX='{ lib, ... }: { fleet.hmUserModules = lib.mkForce []; }'
if [ -n "${EXTRA_NIX:-}" ]; then extra="($EXTRA_NIX)"; else extra=null; fi

expr="$(
  cat <<EOF
let
  flake = builtins.getFlake "path:${root}";
  lib = flake.inputs.nixpkgs.lib;
  ms = import ${root}/flake/module-sets.nix {
    inputs = flake.inputs;
    self = flake;
    lib = lib;
    inventory = flake.inventory;
    moduleFiles = flake.modules;
  };
  stub = {
    networking.hostName = "chain-stub";
    system.stateVersion = "25.05";
    nixpkgs.hostPlatform = "x86_64-linux";
    fileSystems."/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };
    boot.loader.grub.devices = ["/dev/vda"];
    users.users.devji = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      hashedPassword = "!";
    };
  };
  cfg = (lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inputs = flake.inputs;
      self = flake;
    };
    modules =
      ms.mkHost {
        features = [${list}];
        modules = [stub];
      }
      ++ (if ${extra} == null then [] else [${extra}]);
  }).config;
in
builtins.length (lib.filter (a: !a.assertion) cfg.assertions)
EOF
)"

printf '%-40s %10s %10s %8s\n' "features" "seconds" "peak MiB" "failed"
out=$(mktemp -d)
start=$(date +%s%N)
nix eval --impure --expr "$expr" >"$out/value" 2>"$out/err" &
pid=$!
peak=0
# VmHWM is the kernel's own high-water mark and only survives while the process
# does, so sample it: the background `wait` keeps the pid readable until exit.
while kill -0 "$pid" 2>/dev/null; do
  rss=$(awk '/VmHWM/ {print $2}' "/proc/$pid/status" 2>/dev/null || true)
  if [ -n "${rss:-}" ] && [ "$rss" -gt "$peak" ]; then peak=$rss; fi
  sleep 0.05
done
wait "$pid" || {
  echo "eval failed for [${features[*]}]:" >&2
  tail -20 "$out/err" >&2
  exit 1
}
secs=$((($(date +%s%N) - start) / 1000000))
printf '%-40s %10s %10s %8s\n' "${features[*]}" \
  "$((secs / 1000)).$((secs % 1000 / 100))s" "$((peak / 1024))" "$(cat "$out/value")"
rm -rf "$out"
