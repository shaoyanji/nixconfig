#!/usr/bin/env bash
set -euo pipefail

# sops-drift-check.sh — verify that every sops-encrypted yaml file's embedded
# age recipients exactly match the recipients declared in .sops.yaml for its
# (first) matching creation rule.
#
# Catches the failure mode where a file (e.g. modules/ssh-ca-key.yaml) is not
# re-keyed after .sops.yaml gains/loses recipients, which breaks decryption on
# newly enrolled hosts at activation time.
#
# Exit codes: 0 = no drift, 1 = drift detected, 2 = setup error.

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if ! command -v yq >/dev/null 2>&1; then
  if command -v nix-shell >/dev/null 2>&1; then
    exec nix-shell -p yq-go --run "$0"
  fi
  echo "ERROR: yq (yq-go) not found and nix-shell unavailable" >&2
  exit 2
fi

SOPS_CONFIG=".sops.yaml"
[ -f "$SOPS_CONFIG" ] || { echo "ERROR: $SOPS_CONFIG not found" >&2; exit 2; }

rule_count=$(yq '.creation_rules | length' "$SOPS_CONFIG")
fail=0
checked=0

# Candidate encrypted files: yaml under modules/ (includes the secrets
# submodule when checked out; silently fewer files when it is not).
candidates=$(find modules -maxdepth 2 -type f -name '*.yaml' 2>/dev/null | sort)

for file in $candidates; do
  # Skip files that are not sops-encrypted (no top-level sops metadata).
  if [ "$(yq 'has("sops")' "$file" 2>/dev/null || echo false)" != "true" ]; then
    continue
  fi

  # Find the first creation rule whose path_regex matches (sops semantics:
  # first match wins; a rule without path_regex matches everything).
  expected=""
  matched_rule=""
  for i in $(seq 0 $((rule_count - 1))); do
    regex=$(yq -r ".creation_rules[$i].path_regex // \"\"" "$SOPS_CONFIG")
    if [ -z "$regex" ] || echo "$file" | grep -Eq "$regex"; then
      expected=$(yq -r "explode(.) | .creation_rules[$i].key_groups[].age[]" "$SOPS_CONFIG" | sort -u)
      matched_rule="$i"
      break
    fi
  done

  if [ -z "$matched_rule" ]; then
    echo "FAIL $file: no creation rule in $SOPS_CONFIG matches this path"
    fail=1
    continue
  fi

  actual=$(yq -r '.sops.age[].recipient' "$file" | sort -u)

  missing=$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))
  extra=$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))

  checked=$((checked + 1))
  if [ -z "$missing" ] && [ -z "$extra" ]; then
    echo "OK   $file (rule $matched_rule, $(printf '%s\n' "$actual" | wc -l) recipients)"
  else
    fail=1
    echo "FAIL $file (rule $matched_rule):"
    if [ -n "$missing" ]; then
      printf '     missing (in .sops.yaml, not in file — run: sops updatekeys %s):\n' "$file"
      printf '       %s\n' $missing
    fi
    if [ -n "$extra" ]; then
      printf '     stale (in file, not in .sops.yaml — run: sops updatekeys %s):\n' "$file"
      printf '       %s\n' $extra
    fi
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "ERROR: no sops-encrypted files found to check" >&2
  exit 2
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Recipient drift detected. Re-key with 'sops updatekeys <file>' (or task infra:sops:update-keys) from a machine holding an authorized age key."
  exit 1
fi

echo ""
echo "All $checked sops files match .sops.yaml recipients."
