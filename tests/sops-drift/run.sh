#!/usr/bin/env bash
# Regression fixture for `task checks:sops:drift`
# (scripts/task/sops-drift-check.sh).
#
# The drift class: a sops file's embedded `.sops.age[]` recipients no longer
# matching `.sops.yaml` — the un-rekeyed file that decrypts on fewer hosts than
# the config promises. The mistake is seeded: a scratch worktree's
# modules/secrets.yaml loses its first age recipient block, which `yq` removes
# cleanly so the file still parses — only the recipient set drifts. The check
# must name the file; HEAD must stay clean. No secret is decrypted: the gate
# reads the metadata list, never the ciphertext.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
command -v git >/dev/null && command -v yq >/dev/null ||
  { echo "fixture: need git and yq" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" HEAD >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree" >&2; exit 2; }

fail=0

# 1. A dropped recipient must fail, the file named.
yq -i 'del(.sops.age[0])' "$tmp/wt/modules/secrets.yaml" ||
  { echo "fixture: cannot edit sops metadata" >&2; exit 2; }
out=$(cd "$tmp/wt" && bash scripts/task/sops-drift-check.sh --repo-only 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'secrets.yaml'; then
  echo "ok   dropped recipient refused, file named"
else
  echo "FAIL seeded tree: rc=$rc — expected a drift refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if bash "$repo/scripts/task/sops-drift-check.sh" --repo-only >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: check refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "sops-drift:test: all cases pass"
exit $fail
