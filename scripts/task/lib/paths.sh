#!/usr/bin/env bash
# paths.sh — the one place in the repo that spells where a secrets file lives.
# Sourced, not executed, except for one case: a non-shell caller (the Python
# cloak sync) runs `paths.sh secrets` to get the same answer from the same file.
#
# The resolution order is the whole point, and it is why call sites stop asking:
#
#   $NIXCONFIG_SECRETS   an explicit override, for a test or a moved tree
#   modules/secrets/secrets.yaml   the canonical file, in the private submodule
#   modules/secrets.yaml           the committed mirror in the parent repo
#
# Canonical wins because it is what an edit writes. The mirror stays a fallback
# because it is committed to the public repo while the submodule is not, so a
# keyless host or a CI runner can still decrypt. A caller that names one of the
# two explicitly is making a claim about which copy it wants — only
# `sops-drift-check.sh` has any business doing that.
#
# Nothing here sets an option: sourcing must not change the caller's shell.
# The functions return 1 rather than exit, so under `set -e` a caller has to
# guard the call — `file=$(secret_file) || { ... }` — which is where the error
# message belongs anyway.

# Enforced by [[flake/policies.nix#secrets-path-is-resolved-in-one-place]]: this
# file is the only script allowed to spell the path.

# Repo root, without following the ledger of symlinks this fleet reaches it
# through (`~/Documents/nixconfig` -> `/Volumes/data/...`).
nixconfig_root() {
  if [ -n "${NIXCONFIG_ROOT:-}" ]; then
    printf '%s\n' "${NIXCONFIG_ROOT%/}"
    return 0
  fi
  local root
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd -P) || return 1
  [ -n "$root" ] || return 1
  printf '%s\n' "$root"
}

_first_file() {
  local candidate
  for candidate in "$@"; do
    [ -n "$candidate" ] || continue
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# The canonical sops file, mirror as fallback.
secret_file() {
  local root
  root=$(nixconfig_root) || return 1
  _first_file "${NIXCONFIG_SECRETS:-}" \
    "$root/modules/secrets/secrets.yaml" \
    "$root/modules/secrets.yaml"
}

# The apikeys plane has no committed mirror: every reader needs the submodule.
apikeys_file() {
  local root
  root=$(nixconfig_root) || return 1
  _first_file "${NIXCONFIG_APIKEYS:-}" "$root/modules/secrets/apikeys.yaml" \
    || { secrets_absent "modules/secrets/apikeys.yaml"; return 1; }
}

pii_file() {
  local root
  root=$(nixconfig_root) || return 1
  _first_file "${NIXCONFIG_PII:-}" "$root/modules/secrets/pii.yaml" \
    || { secrets_absent "modules/secrets/pii.yaml"; return 1; }
}

# One message for the one condition, so two scripts cannot describe the same
# missing submodule differently. $1 names what was being looked for.
secrets_absent() {
  local root
  root=$(nixconfig_root 2>/dev/null || printf '?')
  printf '%s: %s not found under %s — is the modules/secrets submodule checked out?\n' \
    "${0##*/}" "${1:-secrets.yaml}" "$root" >&2
}

# secret_get '<json path>' [file] — prints the value, empty on any failure.
# The optional file is for the rare caller that has already resolved one.
secret_get() {
  local json_path=${1:-} file=${2:-}
  [ -n "$json_path" ] || return 1
  if [ -z "$file" ]; then
    file=$(secret_file) || {
      secrets_absent
      return 1
    }
  fi
  sops -d --extract "$json_path" "$file" 2>/dev/null
}

# Executed form, for callers that are not shell:
#   paths.sh root | secrets | apikeys | pii
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    root) nixconfig_root ;;
    secrets) secret_file || { secrets_absent; exit 1; } ;;
    apikeys) apikeys_file || exit 1 ;;
    pii) pii_file || exit 1 ;;
    *)
      printf 'usage: paths.sh root|secrets|apikeys|pii\n' >&2
      exit 2
      ;;
  esac
fi
