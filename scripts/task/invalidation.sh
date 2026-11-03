#!/usr/bin/env bash
# invalidation.sh — what a change costs to *build*, before anyone proposes it.
#
# The failure this exists for: an agent edits one module, every active host's
# toplevel is now a different derivation, and the next `nixos-rebuild switch`
# stops being a substitution. The edit looked small; the bill was a closure.
#
# The measurement is `nix build --dry-run --json`, which answers "how many
# derivations would be built" without building one of them and without reaching a
# builder (`--builders ""`). That count is the chore: 1-3 is a microfix, 400 is a
# new stdenv. It is an eval, so it is bounded per host and never the fleet.
#
# Scope comes from the diff, not from a wish: `hosts/<h>/` is that host, anything
# else in the module tree is chain-wide and is sampled. docs/nix-cache-edge.md §
# "A microfix that rebuilds the fleet".
#
# Usage: invalidation.sh [BASE] [--full] [--max-builds N] [--max-hosts N] [--hosts "a b"]
# Exit: 0 every touched host within budget · 1 a host over · 2 bad input
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo"
export NIX_CONFIG="${NIX_CONFIG:-experimental-features = nix-command flakes pipe-operators}"

base="origin/main"
full=0
max_builds="${MAX_BUILDS:-5}"
max_hosts="${MAX_HOSTS:-3}"
explicit=""

while [ "$#" -gt 0 ]; do
  case "$1" in
  --full) full=1 ;;
  --max-builds)
    max_builds="$2"
    shift
    ;;
  --max-hosts)
    max_hosts="$2"
    shift
    ;;
  --hosts)
    explicit="$2"
    shift
    ;;
  -*) echo "invalidation: unknown flag $1" >&2 ; exit 2 ;;
  *) base="$1" ;;
  esac
  shift
done

git rev-parse --verify --quiet "$base" >/dev/null || {
  echo "invalidation: $base is not a rev (fetch first)" >&2
  exit 2
}

changed="$(git diff --name-only "$base" -- . | grep -v '^modules/secrets/' || true)"
[ -n "$changed" ] || {
  echo "invalidation: no changes against $base — nothing to invalidate"
  exit 0
}

# Files that cannot reach a closure: a doc edit does not rebuild a system, and
# saying so is the cheapest possible answer.
code="$(printf '%s\n' "$changed" |
  grep -vE '\.(md|json|toml|yaml|yml|txt|py|sh|jq|sql|css|html|js|ts)$|^docs/|^\.agents/|^\.github/|^taskfiles/' || true)"

echo "invalidation: $(printf '%s\n' "$changed" | wc -l) file(s) changed against $base"
if [ -z "$code" ]; then
  echo "invalidation: none of them can reach a system closure — no host is invalidated"
  exit 0
fi
printf '  %s\n' $code | head -10
[ "$(printf '%s\n' "$code" | wc -l)" -gt 10 ] && echo "  …"

# Active NixOS hosts are the only build targets that matter: a preserved host is
# dormant, and an external one is not built from this flake at all.
mapfile -t active < <(nix eval --json '.#inventory.hosts' |
  jq -r 'to_entries[] | select(.value.kind == "nixos" and .value.status == "active") | .key')

targets=()
if [ -n "$explicit" ]; then
  # shellcheck disable=SC2206 # whitespace-separated on purpose
  targets=($explicit)
else
  for host in "${active[@]}"; do
    if printf '%s\n' "$code" | grep -q "^hosts/$host/"; then
      targets+=("$host")
    fi
  done
  if [ "${#targets[@]}" -eq 0 ]; then
    # Chain-wide: a shared module is in every host's closure, so the measurement
    # is a sample of the hosts that import it. `--full` measures all of them,
    # which is a fleet sweep in disguise — deliberate, never a default.
    if [ "$full" = "1" ]; then
      targets=("${active[@]}")
    else
      targets=("${active[@]:0:$max_hosts}")
      echo "invalidation: chain-wide change — sampling ${#targets[@]}/$((${#active[@]})) host(s); --full measures all"
      echo "              (they share the module chain: a shared-module edit is not a microfix)"
    fi
  fi
fi

fail=0
printf '\n%-12s %-14s %s\n' host arch verdict
for host in "${targets[@]}"; do
  arch="$(nix eval --raw ".#inventory.hosts.$host.arch" 2>/dev/null || echo unknown)"
  # --builders "" is the difference between asking a question and spending money:
  # a dry run that reaches nixbuild.net bills for whatever it decides to build.
  if ! plan="$(nix build --dry-run --json --builders "" \
    ".?submodules=1#nixosConfigurations.$host.config.system.build.toplevel" 2>/dev/null)"; then
    printf '%-12s %-14s %s\n' "$host" "$arch" "EVAL FAILED (not this check's verdict)"
    fail=1
    continue
  fi
  count="$(jq -r 'length' <<<"$plan")"
  if [ "$count" -le "$max_builds" ]; then
    printf '%-12s %-14s %d to build — within budget\n' "$host" "$arch" "$count"
  else
    printf '%-12s %-14s %d to build — OVER %d\n' "$host" "$arch" "$count" "$max_builds"
    # The names are the argument: they say which layer the change reached.
    jq -r '.[].drvPath' <<<"$plan" | sed 's|/nix/store/[a-z0-9]*-||; s|\.drv$||' | sort | head -8 | sed 's/^/               /'
    fail=1
  fi
done

if [ "$fail" = 0 ]; then
  echo
  echo "invalidation: every touched host rebuilds within $max_builds derivation(s)"
else
  echo
  echo "invalidation: a change this size rebuilds more than a microfix should." >&2
  echo "  Split it so the expensive part is its own commit, or warm it deliberately:" >&2
  echo "  task dev:ci:trigger:<host> · task infra:warm:host:<host>" >&2
fi
exit "$fail"
