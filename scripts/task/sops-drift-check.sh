#!/usr/bin/env bash
set -euo pipefail

# sops-drift-check.sh — verify that sops-encrypted yaml files' embedded
# age recipients match the recipients declared in .sops.yaml for their
# matching creation rules.
#
# Catches the failure mode where a file (e.g. modules/ssh-ca-key.yaml) is not
# re-keyed after .sops.yaml gains/loses recipients, which breaks decryption on
# newly enrolled hosts at activation time.
#
# Flags:
#   --repo-only  Only check sops files tracked directly in this git repo
#                (ignores external submodule files like modules/secrets/*.yaml).
#   --all        Check all candidate yaml files under modules/ including submodules.
#   --warn-only  Exit 0 even if drift is detected (emits warnings/annotations).
#
# In GitHub Actions (GITHUB_ACTIONS=true), defaults to --repo-only and emits
# workflow warnings (::warning) and step summaries.
#
# Exit codes: 0 = no drift (or --warn-only), 1 = drift detected, 2 = setup error.

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if ! command -v yq >/dev/null 2>&1; then
  if command -v nix-shell >/dev/null 2>&1; then
    exec nix-shell -p yq-go --run "$0 \"\$@\""
  fi
  echo "ERROR: yq (yq-go) not found and nix-shell unavailable" >&2
  exit 2
fi

REPO_ONLY=false
WARN_ONLY=false

# Default to repo-only in GitHub Actions to avoid failing on out-of-tree submodule drift
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  REPO_ONLY=true
fi

for arg in "$@"; do
  case "$arg" in
    --repo-only) REPO_ONLY=true ;;
    --all) REPO_ONLY=false ;;
    --warn-only) WARN_ONLY=true ;;
    -h|--help)
      echo "Usage: $0 [--repo-only] [--all] [--warn-only]"
      exit 0
      ;;
  esac
done

SOPS_CONFIG=".sops.yaml"
[ -f "$SOPS_CONFIG" ] || { echo "ERROR: $SOPS_CONFIG not found" >&2; exit 2; }

# Find candidate encrypted yaml files
if [ "$REPO_ONLY" = true ]; then
  # Only files tracked in this git repository under modules/
  candidates=$(git ls-files 'modules/*.yaml' 2>/dev/null | sort)
else
  # All yaml files under modules/ (including submodules when checked out)
  candidates=$(find modules -maxdepth 2 -type f -name '*.yaml' 2>/dev/null | sort)
fi

fail=0
checked=0
drift_details=""

for file in $candidates; do
  # Skip files that are not sops-encrypted (no top-level sops metadata).
  if [ "$(yq 'has("sops")' "$file" 2>/dev/null || echo false)" != "true" ]; then
    continue
  fi

  # Determine matching sops config: if file is in a subdirectory with its own .sops.yaml, use that
  file_dir=$(dirname "$file")
  config_for_file="$SOPS_CONFIG"
  if [ -f "$file_dir/.sops.yaml" ]; then
    config_for_file="$file_dir/.sops.yaml"
  fi

  rule_count=$(yq '.creation_rules | length' "$config_for_file")
  expected=""
  matched_rule=""
  for i in $(seq 0 $((rule_count - 1))); do
    regex=$(yq -r ".creation_rules[$i].path_regex // \"\"" "$config_for_file")
    if [ -z "$regex" ] || echo "$file" | grep -Eq "$regex"; then
      expected=$(yq -r "explode(.) | .creation_rules[$i].key_groups[].age[]" "$config_for_file" | sort -u)
      matched_rule="$i"
      break
    fi
  done

  if [ -z "$matched_rule" ]; then
    echo "FAIL $file: no creation rule in $config_for_file matches this path"
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
    echo "FAIL $file (rule $matched_rule in $config_for_file):"
    missing_str=""
    extra_str=""
    if [ -n "$missing" ]; then
      printf '     missing (in %s, not in file — run: sops updatekeys %s):\n' "$config_for_file" "$file"
      printf '       %s\n' $missing
      missing_str=$(echo "$missing" | tr '\n' ' ')
    fi
    if [ -n "$extra" ]; then
      printf '     stale (in file, not in %s — run: sops updatekeys %s):\n' "$config_for_file" "$file"
      printf '       %s\n' $extra
      extra_str=$(echo "$extra" | tr '\n' ' ')
    fi

    # Emit GitHub Actions workflow warning
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
      warn_msg="SOPS drift detected for $file."
      [ -n "$missing_str" ] && warn_msg="$warn_msg Missing: $missing_str."
      [ -n "$extra_str" ] && warn_msg="$warn_msg Stale: $extra_str."
      echo "::warning file=$file::$warn_msg"
    fi

    drift_details="${drift_details}
| \`$file\` | ❌ Drift | ${missing_str:-none} | ${extra_str:-none} |"
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "ERROR: no sops-encrypted files found to check" >&2
  exit 2
fi

# Append to GITHUB_STEP_SUMMARY if available
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## SOPS Recipient Drift Check"
    if [ "$fail" -eq 0 ]; then
      echo "✅ All $checked sops file(s) match expected recipients."
    else
      echo "⚠️ **Recipient drift detected across $checked file(s).**"
      echo ""
      echo "| File | Status | Missing Keys | Stale Keys |"
      echo "|------|--------|--------------|------------|"
      echo "$drift_details"
      echo ""
      echo "> **Remediation**: Run \`task infra:sops:update-keys\` from a machine holding an authorized age key."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Recipient drift detected. Re-key with 'sops updatekeys <file>' (or task infra:sops:update-keys) from a machine holding an authorized age key."
  if [ "$WARN_ONLY" = true ]; then
    echo "Exiting 0 due to --warn-only flag."
    exit 0
  fi
  exit 1
fi

echo ""
echo "All $checked sops files match .sops.yaml recipients."
