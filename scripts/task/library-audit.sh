#!/usr/bin/env bash
# Reports the shared software library (/Volumes/data/bin-*, appimages).
# Read-only: pruning is a human decision made from this output.
#
# The library exists so NON-Nix machines run these tools (pentest targets,
# research boxes), so each binary's linkage matters as much as its size: arch
# plus glibc floor decides whether a given target can execute it at all, and a
# tool with several libc builds is a compatibility set, not redundancy.
#
#   --index   emit TSV: sha256, arch, linkage, glibc floor, bytes, path
set -euo pipefail

ROOT="${LIBRARY_ROOT:-}"
if [ -z "$ROOT" ]; then
  for d in /Volumes/data /srv/data; do
    [ -d "$d" ] && ROOT="$d" && break
  done
fi
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "library audit: no library root (/Volumes/data, /srv/data)" >&2
  exit 1
fi

MODE=report
PROBE=""
case "${1:-}" in
  --index) MODE=index ;;
  --probe) MODE=probe; PROBE="${2:?--probe needs a file}" ;;
  "") ;;
  *) echo "library audit: unknown argument $1 (use --index or --probe FILE)" >&2; exit 2 ;;
esac
TOP="${TOP:-8}"

DIRS=()
for d in "$ROOT"/bin-x86 "$ROOT"/bin-aarch64 "$ROOT"/bin-script "$ROOT"/appimages; do
  [ -d "$d" ] && DIRS+=("$d")
done
if [ ${#DIRS[@]} -eq 0 ]; then
  echo "library audit: no bin-*/appimages directories under $ROOT" >&2
  exit 1
fi

human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1"; }

# ELF facts come from the header bytes, not from binutils: `readelf` is not on
# every host that runs this, and a silent empty column is worse than no column.
# e_machine at offset 18 is little-endian: 62 = x86-64, 183 = aarch64, 3 = i386.
arch_of() {
  local f=$1 magic lo hi
  # \x7fELF in the first four bytes; anything else is a script or an archive.
  magic=$(od -An -tu1 -j0 -N4 "$f" 2>/dev/null | tr -s ' ')
  [ "$magic" = " 127 69 76 70" ] || { echo unknown; return; }
  read -r lo hi <<<"$(od -An -tu1 -j18 -N2 "$f" 2>/dev/null)"
  case "$((lo + 256 * hi))" in
    62) echo x86_64 ;;
    183) echo aarch64 ;;
    3) echo i386 ;;
    *) echo unknown ;;
  esac
}

# `file` names a static-pie binary "static-pie linked", which a `*statically*`
# glob misses — that misclassified a 143 MiB musl binary as a shell script.
linkage_of() {
  local info
  info=$(file -b "$1" 2>/dev/null || true)
  case "$info" in
    *"dynamically linked"*) echo dynamic ;;
    *"statically linked"* | *"static-pie"*) echo static ;;
    *ELF*) if grep -qa -m1 -e 'ld-linux' -e 'ld-musl' "$1"; then echo dynamic; else echo static; fi ;;
    *) echo script ;;
  esac
}

# Highest GLIBC_ symbol the binary demands. `none` = static (runs anywhere),
# `na` = dynamic but no glibc symbols (musl-linked).
glibc_of() {
  local floor
  floor=$(grep -aoE 'GLIBC_[0-9]+(\.[0-9]+)+' "$1" 2>/dev/null | sed 's/GLIBC_//' | sort -Vu | tail -1 || true)
  printf '%s' "${floor:-na}"
}

# One row describing one file: sha, arch, linkage, glibc floor, bytes, path.
row() {
  local f=$1 arch linkage floor
  arch=$(arch_of "$f")
  linkage=$(linkage_of "$f")
  floor=none
  [ "$linkage" = dynamic ] && floor=$(glibc_of "$f")
  printf '%s\t%s\t%s\t%s\t%s\t%s' \
    "$(sha256sum "$f" | cut -d' ' -f1)" "$arch" "$linkage" "$floor" \
    "$(stat -c%s "$f")" "${f#"$ROOT"/}"
}

# `--probe` is the single-file form `library-fetch.sh` judges a download with,
# so "is this static?" has one implementation instead of two.
if [ "$MODE" = probe ]; then
  [ -f "$PROBE" ] || { echo "library audit: no such file $PROBE" >&2; exit 1; }
  row "$PROBE"
  printf '\n'
  exit 0
fi

rows=$(mktemp)
trap 'rm -f "$rows"' EXIT

# One pass: every later view reads this table instead of re-hashing the tree.
for d in "${DIRS[@]}"; do
  find "$d" -maxdepth 1 -type f -print0 2>/dev/null | sort -z |
    while IFS= read -r -d '' f; do
      row "$f" >>"$rows"
      printf '\n' >>"$rows"
    done
done

if [ "$MODE" = index ]; then
  printf 'sha256\tarch\tlinkage\tglibc_min\tbytes\tpath\n'
  cat "$rows"
  exit 0
fi

echo "=== software library: $ROOT ==="
for d in "${DIRS[@]}"; do
  name=$(basename "$d")
  files=$(awk -F'\t' -v n="$name/" 'index($6, n) == 1' "$rows" | wc -l)
  bytes=$(awk -F'\t' -v n="$name/" 'index($6, n) == 1 {s += $5} END {print s + 0}' "$rows")
  printf '%-11s %4s files  %9s\n' "$name" "$files" "$(human "$bytes")"
done

echo
echo "--- portability (what a non-Nix target can actually run) ---"
awk -F'\t' '
  { d = $6; sub(/\/.*/, "", d)
    tot[d]++
    if ($3 == "static") s[d]++
    else if ($3 == "script") c[d]++
    else { y[d]++; f[d] = (f[d] == "" || $4 > f[d]) ? $4 : f[d] } }
  END {
    printf "%-11s %5s %6s %6s %6s  %s\n", "dir", "files", "static", "dyn", "script", "highest glibc floor"
    for (d in tot) printf "%-11s %5d %6d %6d %6d  %s\n", d, tot[d], s[d], y[d], c[d], (f[d] == "" ? "-" : f[d])
  }' "$rows" | (read -r h; echo "$h"; sort)
echo "appimages: linkage describes the bundled runtime; the .squashfs payload decides"
echo "           whether the target can run it, so check the app's own requirements."

echo
echo "--- byte-identical duplicates (safe to prune to one) ---"
dupSets=$(awk -F'\t' '{ n[$1]++ } END { for (h in n) if (n[h] > 1) print h, n[h] }' "$rows")
if [ -z "$dupSets" ]; then
  echo "  none"
else
  while read -r sha count; do
    awk -F'\t' -v s="$sha" '$1 == s { print $5 "\t" $6 }' "$rows" |
      while IFS=$'\t' read -r size path; do
        printf '%3s copies  %9s  %s\n' "$count" "$(human "$size")" "$path"
      done
  done <<<"$dupSets"
fi
wasted=$(awk -F'\t' '{ n[$1]++; size[$1] = $5 } END { for (h in n) if (n[h] > 1) s += size[h] * (n[h] - 1); print s + 0 }' "$rows")
printf 'wasted by exact duplicates: %s\n' "$(human "$wasted")"

echo
echo "--- provenance (.library.tsv records what a fetch wrote; a file with no record is of unknown origin) ---"
manifest="$ROOT/.library.tsv"
if [ -f "$manifest" ]; then
  unrecorded=$(awk -F'\t' 'FNR == NR { if (NF > 1) known[$6] = 1; next } !($6 in known)' "$manifest" "$rows")
else
  echo "  no $manifest yet — every file below predates the fetch wrapper"
  unrecorded=$(cat "$rows")
fi
printf '  records %s · unrecorded %s of %s files\n' \
  "$(if [ -f "$manifest" ]; then wc -l <"$manifest"; else echo 0; fi)" \
  "$(printf '%s' "$unrecorded" | grep -c . || true)" \
  "$(wc -l <"$rows")"
printf '%s\n' "$unrecorded" | awk -F'\t' 'NF > 1 { print "  " $6 }' | head -n "$TOP"

echo
echo "--- eget re-fetch residue (.1/.2 suffixes = a second download of the same asset) ---"
awk -F'\t' '$6 ~ /\.[0-9]+$/ { printf "  %9s  %s\n", $5, $6 }' "$rows" | sort -t/ -k2 || true
awk -F'\t' '$6 ~ /\.[0-9]+$/ { c++ } END { printf "%d file(s)\n", c + 0 }' "$rows"

echo
echo "--- variant sets (KEEP: differ by libc/arch for different targets) ---"
awk -F'\t' '
  { name = $6; sub(/.*\//, "", name)
    dir = $6; sub(/\/.*/, "", dir)
    if (dir == "appimages" || dir == "bin-script") next
    base = name
    sub(/[._-](x86_64|amd64|aarch64|arm64|linux|musl|gnu|ubuntu[0-9_.]*|v?[0-9]+(\.[0-9]+)+).*$/, "", base)
    k = dir "\t" base
    if (!(k in seen)) { seen[k] = 1; order[++i] = k }
    cnt[k]++
    if ($3 == "static") st[k]++
    if ($4 != "none" && $4 != "na") fl[k] = (fl[k] == "" || $4 > fl[k]) ? $4 : fl[k] }
  END { for (j = 1; j <= i; j++) { k = order[j]; if (cnt[k] > 1) { split(k, p, "\t"); printf "%-11s %2d builds of %s*  (%d static%s)\n", p[1], cnt[k], p[2], st[k], (fl[k] == "" ? "" : ", glibc>=" fl[k]) } } }' "$rows"
echo "Run with --index for the sha256/arch/linkage table used to pick a build per target."

echo
echo "--- largest files ---"
for d in "${DIRS[@]}"; do
  echo "[$(basename "$d")]"
  awk -F'\t' -v n="$(basename "$d")/" 'index($6, n) == 1 { printf "%s\t%s\n", $5, $6 }' "$rows" |
    sort -rn | head -n "$TOP" |
    while IFS=$'\t' read -r size path; do printf '  %9s  %s\n' "$(human "$size")" "$(basename "$path")"; done
done

echo
echo "--- compression verdict (measured 2026-10-22) ---"
echo "appimages: zstd -3 ratio 0.99 — squashfs+zstd inside, so recompressing saves nothing"
echo "bin-*:     zstd -3 ratio 0.36, -9 0.32 — a real gain, but every run pays a decompress"
echo "           step; prune duplicates and re-fetch residue before reaching for a compressor"
