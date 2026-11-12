#!/usr/bin/env bash
# hermes-env-sync — keep ~/.hermes/.env equal to the rendered env, plus whatever
# only this host knows.
#
# Why (2026-11-05): `profiles.hermes` renders the credential file from sops
# (modules/profiles/hermes.nix), but a host that had ever run an auth flow had a
# real ~/.hermes/.env, and the activation only bridged the rendered file when
# `.env` was ABSENT — a guard written to avoid clobbering hermes-managed tokens.
# The effect was the opposite of the intent: the plain file shadowed every later
# rotation, and hermes reads exactly `$HERMES_HOME/.env` (hermes_cli/config.py
# get_env_path), so the CLI and the gateway's own dotenv load kept the old keys
# while sops and the unit's EnvironmentFile had the new ones.
#
# The split that resolves it without a merge inside sops: keys the rendered file
# DEFINES are authoritative and always copied; keys it does not define (this
# host's SIMPLEX_* policy, any token an auth flow added) live in .env.local,
# which this script never writes after seeding it once. .env is then derived,
# not hand-edited — so the only way to lose a local key is to delete .env.local.
#
# Modes: (none) converge · --check report drift and exit 1 (writes nothing)
# Exit: 0 clean/converged · 1 drift with --check · 2 unreadable inputs.
set -euo pipefail

HOME_DIR="${HOME:?HOME is not set}"
RENDERED="${RENDERED:-$HOME_DIR/.config/hermes/hermes.env}"
TARGET="${TARGET:-$HOME_DIR/.hermes/.env}"
LOCAL="${LOCAL:-$HOME_DIR/.hermes/.env.local}"
case "${1:-apply}" in
  --check | check) MODE=check ;;
  apply) MODE=apply ;;
  *) printf 'usage: hermes-env-sync [--check]\n' >&2; exit 2 ;;
esac

die() {
  printf 'hermes-env-sync: %s\n' "$*" >&2
  exit 2
}

[ -d "$(dirname "$TARGET")" ] || die "target directory $(dirname "$TARGET") does not exist"
if [ ! -r "$RENDERED" ]; then
  # A host with no rendered secrets (no sops, or a container) keeps whatever it
  # has; inventing an empty .env there would wipe credentials.
  printf 'hermes-env-sync: %s is not readable — leaving %s alone\n' "$RENDERED" "$TARGET"
  exit 0
fi
if [ -L "$TARGET" ]; then
  printf 'hermes-env-sync: %s is a symlink (the pre-2026-11-05 bridge); replace it with a generated file\n' "$TARGET"
  if [ "$MODE" = "check" ]; then exit 1; fi
  rm -f "$TARGET"
fi

# `|| true` is load-bearing: grep exits 1 when a file has no keys at all, and
# under `set -o pipefail` that became the function's status — so the very case
# this script exists for (a host with no ~/.hermes/.env yet) aborted the run at
# the first diff instead of building the file. Measured on delphi 2026-11-06.
keys_of() { { grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null || true; } | tr -d '=' | sort -u; }

# --- aliases: derive the name a provider reads --------------------------------
# The rendered blob stays the single source. A provider that spells the same
# credential differently gets the alias derived here, at env level — not a
# second copy in sops, and not a declaration inside the tool. Format
# TARGET=SOURCE; TARGET is emitted only when SOURCE is defined and TARGET is
# not, so a blob that later carries TARGET makes this line go quiet.
# FAL_KEY: hermes' image_gen plugin reads FAL_KEY alone
# (plugins/image_gen/fal/plugin.yaml `requires_env`, and
# tool_backend_helpers.fal_key_is_configured), while the blob carries
# FAL_API_KEY. Without the alias `hermes doctor` reports image_gen unavailable.
ALIASES='FAL_KEY=FAL_API_KEY'
derived_keys=""
alias_lines=""
while IFS='=' read -r target source; do
  [ -n "$target" ] || continue
  # A derived name belongs to this script, not to the host: it must never be
  # seeded into .env.local, or --check would report it as drift forever.
  derived_keys="${derived_keys}${target}
"
  grep -qE "^${target}=" "$RENDERED" 2>/dev/null && continue
  if [ -s "$LOCAL" ]; then
    grep -qE "^${target}=" "$LOCAL" 2>/dev/null && continue
  fi
  value="$(grep -m1 "^${source}=" "$RENDERED" 2>/dev/null | cut -d= -f2- || true)"
  [ -n "$value" ] || continue
  alias_lines="${alias_lines}${target}=${value}
"
done <<<"$ALIASES"

# --- seed .env.local once, from the keys the rendered file does not define ----
if [ ! -e "$LOCAL" ] && [ -f "$TARGET" ]; then
  keyfile="$(mktemp)"
  localfile="$(mktemp)"
  keys_of "$RENDERED" >"$keyfile"
  # A derived key is not the host's to keep: drop it before deciding whether
  # anything actually needs .env.local.
  keys_of "$TARGET" | comm -13 "$keyfile" - | while IFS= read -r k; do
    grep -qxF "$k" <<<"$derived_keys" || printf '%s\n' "$k"
  done >"$keyfile.extras"
  if [ -s "$keyfile.extras" ]; then
    if [ "$MODE" = "check" ]; then
      # --check never writes: report what the next activation would seed.
      printf 'hermes-env-sync: %s has %s key(s) the rendered file does not define and no %s to hold them: %s\n' \
        "$TARGET" "$(wc -l <"$keyfile.extras")" "$LOCAL" "$(tr '\n' ' ' <"$keyfile.extras")" >&2
      rm -f "$keyfile" "$keyfile.extras" "$localfile"
      exit 1
    fi
    # Match on the key, keep the whole line: values are never parsed here.
    awk -F= 'FILENAME == ARGV[1] { keep[$0] = 1; next } ($1 in keep) { print }' \
      "$keyfile.extras" "$TARGET" >"$localfile"
    install -m 0600 "$localfile" "$LOCAL"
    printf 'hermes-env-sync: seeded %s with %s key(s) the rendered file does not define: %s\n' \
      "$LOCAL" "$(wc -l <"$localfile")" "$(tr '\n' ' ' <"$keyfile.extras")"
  fi
  rm -f "$keyfile" "$keyfile.extras" "$localfile"
fi
[ -e "$LOCAL" ] && chmod 0600 "$LOCAL"

# --- build the desired file --------------------------------------------------
desired="$(mktemp)"
trap 'rm -f "$desired"' EXIT
cat "$RENDERED" >"$desired"
if [ -s "$LOCAL" ]; then
  printf '\n# --- kept by hermes-env-sync: keys the rendered file does not define (%s) ---\n' "$LOCAL" >>"$desired"
  cat "$LOCAL" >>"$desired"
fi

if [ -n "$alias_lines" ]; then
  printf '\n# --- derived by hermes-env-sync: one credential, the name the provider reads ---\n' >>"$desired"
  printf '%s' "$alias_lines" >>"$desired"
fi

if [ -f "$TARGET" ] && cmp -s "$desired" "$TARGET"; then
  [ "$MODE" = "check" ] || printf 'hermes-env-sync: %s already matches the rendered env\n' "$TARGET"
  exit 0
fi

# Drift is reported by key name only: a value never reaches stdout or a journal.
current="$(mktemp)"
trap 'rm -f "$desired" "$current"' EXIT
[ -f "$TARGET" ] && cat "$TARGET" >"$current"
# Both files, not one file and stdin: `comm -13 a -` reads its second input
# from the pipe, and a redirection mistake there silently swapped the two
# sides — reported as "added" and "dropped" being the same list (2026-11-06).
added="$(comm -13 <(keys_of "$current") <(keys_of "$desired") | tr '\n' ' ')"
removed="$(comm -23 <(keys_of "$current") <(keys_of "$desired") | tr '\n' ' ')"
# Same key, different value: the rotation case the old bridge could not see.
# Key names only — awk compares whole lines in memory and prints the first field.
# `FILENAME == ARGV[1]`, not `NR == FNR`: when the first file is EMPTY (no
# .env yet) FNR still equals NR on the first line of the second file, so the
# desired file's own first key was filed as a "current" value.
changed="$(awk -F= 'FILENAME == ARGV[1] { v[$1] = substr($0, length($1) + 2); next }
  { if (($1 in v) && v[$1] != substr($0, length($1) + 2)) print $1 }' "$current" "$desired" | tr '\n' ' ')"

if [ "$MODE" = "check" ]; then
  printf 'hermes-env-sync: DRIFT in %s (would add: %s; would drop: %s; would change: %s)\n' \
    "$TARGET" "${added:-none}" "${removed:-none}" "${changed:-none}"
  exit 1
fi

install -m 0600 "$desired" "$TARGET.new"
mv -f "$TARGET.new" "$TARGET"
printf 'hermes-env-sync: rewrote %s from %s (added: %s; dropped: %s; changed: %s)\n' \
  "$TARGET" "$RENDERED" "${added:-none}" "${removed:-none}" "${changed:-none}"
