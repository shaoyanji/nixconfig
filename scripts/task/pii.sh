#!/usr/bin/env bash
# scripts/task/pii.sh — the private half of the personal data, decrypted at runtime.
#
#   pii.sh sync              decrypt modules/secrets/pii.yaml to $APPFLOW_PII
#   pii.sh get KEY           one value, for a script composing an outbound document
#
# The published sites are static: whatever `nix build .#sites.*` reads is in the
# artifact, and the artifact is public. So a fact that must not be published
# cannot be a build input — `pii.yaml` is sops-encrypted in the secrets submodule
# and reaches a consumer only here, after `sops -d`, never through eval.
# `lib/` reading this directory is a gate failure, not a convention:
# [[flake/policies.nix#private-data-is-not-a-build-input]].
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
. "${BASH_SOURCE[0]%/*}/lib/paths.sh"
file=$(pii_file) || exit 2
out=${APPFLOW_PII:-${XDG_CONFIG_HOME:-$HOME/.config}/appflow/pii.json}

die() {
  printf 'pii: %s\n' "$*" >&2
  exit 2
}

# The submodule is absent on a bare tree and pii.yaml is absent until a private
# fact is recorded; both are the same answer, and neither is an empty document.
need() {
  [ -s "$file" ] || die "no $file — the secrets submodule is not checked out, or nothing private is recorded yet"
  command -v sops >/dev/null || die "sops is not on PATH"
  command -v yq >/dev/null || die "yq is not on PATH"
}

forbidden() {
  case "$out" in
    /*) abs=$out ;;
    *) abs=$PWD/$out ;;
  esac
  case "$abs" in
    "$root"/*) die "$abs is inside the repository; a plaintext copy there is the thing this exists to prevent" ;;
  esac
}

sync() {
  forbidden
  need
  tmp=$(mktemp "${TMPDIR:-/tmp}/pii.XXXXXX")
  trap 'rm -f "$tmp" "$tmp".json' EXIT
  sops -d "$file" >"$tmp"
  yq -p yaml -o json '.' "$tmp" >"$tmp.json"
  mkdir -p "$(dirname "$out")"
  install -m 600 "$tmp.json" "$out"
  printf 'pii: pii.yaml -> %s (%s keys)\n' "$out" "$(yq -p json -o json '. | keys | length' "$out")"
}

get() {
  [ $# -eq 1 ] || die "usage: pii.sh get KEY"
  [ -s "$out" ] || sync >/dev/null
  value=$(yq -p json -o json -r ".$1 // \"\"" "$out")
  [ -n "$value" ] || die "no $1 in $out"
  printf '%s\n' "$value"
}

case "${1:-}" in
  sync) shift && sync ;;
  get) shift && get "$@" ;;
  *) die "usage: pii.sh sync | get KEY" ;;
esac
