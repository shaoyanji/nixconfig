#!/usr/bin/env bash
# One-shot Elixir resolution: explicit, PATH, rooted cache, substitution.
kg_resolve_elixir() {
  if [ -n "${KG_ELIXIR:-}" ]; then
    [ -x "$KG_ELIXIR" ] || return 1
    printf '%s' "$KG_ELIXIR"
    return 0
  fi
  if command -v elixir >/dev/null 2>&1; then
    command -v elixir
    return 0
  fi
  local link="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig/kg-zeck/elixir"
  if [ ! -x "$link/bin/elixir" ]; then
    mkdir -p "${link%/*}"
    nix build --inputs-from "$REPO" --out-link "$link" --offline --builders "" nixpkgs#elixir >/dev/null 2>&1 ||
      nix build --inputs-from "$REPO" --out-link "$link" --builders "" nixpkgs#elixir >/dev/null 2>&1 || return 1
  fi
  [ -x "$link/bin/elixir" ] || return 1
  printf '%s' "$link/bin/elixir"
}
