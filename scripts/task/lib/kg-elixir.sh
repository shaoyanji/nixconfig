#!/usr/bin/env bash
# kg-elixir.sh — the one place the graph scripts find an Elixir interpreter.
#
# Sourced by kg-native-check.sh and kg-sidecar.sh (which previously carried
# byte-identical copies). Resolution order, cheapest first:
#
#   1. KG_ELIXIR, for an explicit interpreter
#   2. elixir on PATH (a devshell, or a host that has it)
#   3. a GC-rooted out-link in ~/.cache/nixconfig-kg/, reused WITHOUT invoking
#      nix — this is what makes the gate cheap on a host with no devshell
#   4. `nix build --out-link`, which substitutes from cache.nixos.org
#
# Every nix call carries `--builders ""`: a miss must never become a compile on
# someone's bill (a 25 h/month remote-builder budget is cheaper than a surprise,
# and this interpreter is in the binary cache anyway).

KG_ELIXIR_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-kg"

kg_resolve_elixir() {
  if [ -n "${KG_ELIXIR:-}" ]; then
    printf '%s' "$KG_ELIXIR"
    return 0
  fi
  if command -v elixir >/dev/null 2>&1; then
    command -v elixir
    return 0
  fi
  # The out-link is a store path's stable name: if the binary is executable,
  # the result is still in the store and nix has nothing to add.
  local link="$KG_ELIXIR_CACHE/elixir"
  if [ -x "$link/bin/elixir" ]; then
    printf '%s' "$link/bin/elixir"
    return 0
  fi
  mkdir -p "$KG_ELIXIR_CACHE"
  # --offline first: when the path is already in the store this links it with
  # no network at all. Only a genuine miss goes online to substitute.
  if ! nix build --out-link "$link" --offline --builders "" nixpkgs#beamPackages.elixir >/dev/null 2>&1; then
    echo "kg-elixir: substituting nixpkgs#beamPackages.elixir (one-off, cached in $KG_ELIXIR_CACHE)" >&2
    nix build --out-link "$link" --builders "" nixpkgs#beamPackages.elixir >/dev/null 2>&1 || true
  fi
  if [ -x "$link/bin/elixir" ]; then
    printf '%s' "$link/bin/elixir"
    return 0
  fi
  return 1
}
