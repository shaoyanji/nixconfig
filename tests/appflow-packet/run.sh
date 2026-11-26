#!/usr/bin/env bash
# Fixture for the packet store's durability (2026-11-26).
#
# A packet used to be `ln -sfn <store path> submissions/<id>`, so one
# `nix-collect-garbage` emptied submissions that nobody had rebuilt — the
# proofline packet was a dangling link and both PDFs were gone. The stable name is
# a copy now, mode 600 because a packet carries a street address and a phone
# number, and `--repair` migrates rows built the old way.
#
# Cases, each one a way the rule can silently fail:
#   1. a live link is materialized, and stays a real directory afterwards;
#   2. files landed in a row by hand (a PR draft) survive the rebuild;
#   3. a dangling link is refused and named, not passed over;
#   4. a row that is already a directory is left untouched.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
script="$repo/scripts/task/appflow-packet.sh"

[ -f "$script" ] || { echo "fixture: no appflow-packet.sh" >&2; exit 2; }
command -v cmp >/dev/null || { echo "fixture: no cmp" >&2; exit 2; }

fail=0
note() { if [ "$1" = ok ]; then echo "ok   $2"; else echo "FAIL $2"; shift 2; fail=1; fi; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

packets="$tmp/submissions"
artifact="$tmp/artifact"
mkdir -p "$packets" "$artifact"
printf 'letter bytes' >"$artifact/anschreiben.pdf"
printf 'cv bytes' >"$artifact/lebenslauf.pdf"
printf '{"projects":{"kept":[]}}' >"$artifact/selection.json"

# A row built by the old builder: a conjunctive link into the store artifact.
ln -s "$artifact" "$packets/linked-row"

# A row that is already a directory, with a file the builder never wrote.
mkdir -p "$packets/dir-row"
printf 'pr draft\n' >"$packets/dir-row/pr-270.md"
chmod 644 "$packets/dir-row/pr-270.md"; chmod 755 "$packets/dir-row"

out="$(APPFLOW_PACKETS="$packets" bash "$script" --repair 2>&1)"
rc=$?

if [ $rc -eq 0 ]; then note ok "repair of live links exits 0"; else note fail "repair of live links exits 0"; fi

if [ -L "$packets/linked-row" ]; then
  note fail "a live link is materialized into a real directory"
elif [ -d "$packets/linked-row" ]; then
  note ok "a live link is materialized into a real directory"
else
  note fail "a live link is materialized into a real directory"
fi

if cmp -s "$artifact/anschreiben.pdf" "$packets/linked-row/anschreiben.pdf"; then
  note ok "the letter survives the copy"
else
  note fail "the letter survives the copy"
fi

mode="$(stat -c %a "$packets/linked-row/anschreiben.pdf" 2>/dev/null)"
if [ "$mode" = 600 ]; then note ok "the copy is mode 600"; else note fail "the copy is mode 600 (got $mode)"; fi

if [ "$(cat "$packets/dir-row/pr-270.md" 2>/dev/null)" = "pr draft" ]; then
  note ok "a hand-written file in a directory row is untouched"
else
  note fail "a hand-written file in a directory row is untouched"
fi

mode="$(stat -c %a "$packets/dir-row/pr-270.md" 2>/dev/null)"
if [ "$mode" = 600 ]; then note ok "a directory row is tightened to 600"; else note fail "a directory row is tightened to 600 (got $mode)"; fi

mode="$(stat -c %a "$packets/dir-row" 2>/dev/null)"
if [ "$mode" = 700 ]; then note ok "a directory row is tightened to 700"; else note fail "a directory row is tightened to 700 (got $mode)"; fi

# The failure that motivated the rule: the artifact is gone, the link still looks
# like an application.
rm -rf "$artifact"
ln -s "$artifact" "$packets/dead-row"
out="$(APPFLOW_PACKETS="$packets" bash "$script" --repair 2>&1)"
rc=$?
if [ $rc -ne 0 ]; then note ok "a dangling link fails the repair"; else note fail "a dangling link fails the repair"; fi
if printf '%s' "$out" | grep -q 'dead-row'; then
  note ok "the dangling row is named"
else
  note fail "the dangling row is named"
fi

# Repair must not invent files for a surviving row.
if [ -f "$packets/linked-row/anschreiben.pdf" ]; then
  note ok "a materialized row keeps its files when a sibling dies"
else
  note fail "a materialized row keeps its files when a sibling dies"
fi

if [ $fail -eq 0 ]; then echo "appflow-packet fixture: every case behaves"; fi
exit $fail
