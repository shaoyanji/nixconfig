#!/usr/bin/env bash
# Sweep flake.lock transitive inputs against their upstream heads.
#
# A root `nix flake update` only advances the ROOT inputs. Transitive
# inputs that follow a branch (e.g. impermanence/nixpkgs,
# dms/dank-qml-common, garnix-lib/nixpkgs) keep their stale pins until
# their parent flake happens to relock — which can take months. This
# script walks the lock graph from root (BFS, cycle-safe), resolves
# every github/gitlab pin against the live upstream ref, and reports
# (or fixes) the drift.
#
# Drifted nodes are classified empirically by probing a temp copy of
# the flake: paths nix CAN advance are DRIFT (actionable); paths whose
# rev is pinned by their parent flake's own lock are PINNED
# (informational — they move when the parent root input updates).
#
# Usage:
#   flake-transitive-sweep.sh check            # read-only sweep; exit 1 on drift
#   flake-transitive-sweep.sh update [path…]   # nix flake update each drifted path
#                                              # (optional path filter, e.g. dms/dank-qml-common)
#
# Env:
#   GITHUB_TOKEN  optional; used for GitHub API auth (avoids rate limits)
set -euo pipefail

MODE="${1:-check}"
shift || true

CURL_AUTH=()
NIX_AUTH=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  CURL_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  NIX_AUTH=(--option access-tokens "github.com=${GITHUB_TOKEN}")
fi

FLAKE_DIR="$(git rev-parse --show-toplevel)"
LOCK="${FLAKE_DIR}/flake.lock"

# ── BFS over the lock graph from root ────────────────────────────────
# Follows edges ("nixpkgs": ["nixpkgs"]) do NOT extend the input path —
# they re-target the parent's input. String edges append the key.
# The graph can contain cycles, so every node is visited once; the
# first (shortest) path wins.
queue=("root")
visited=" root "
declare -A path_of=()
path_of[root]=""
idx=0
while [ "$idx" -lt "${#queue[@]}" ]; do
  node="${queue[$idx]}"
  path="${path_of[$node]}"
  idx=$((idx + 1))
  inputs="$(jq -c --arg n "$node" '.nodes[$n].inputs // {}' "$LOCK")"
  while IFS=$'\t' read -r key vtype child; do
    [ -z "$key" ] && continue
    if [ "$vtype" = "string" ]; then
      if [ -z "$path" ]; then childpath="$key"; else childpath="${path}/${key}"; fi
    else
      childpath="$path" # follows: keep parent path, hop to value[0]
    fi
    case "$visited" in
    *" $child "*) continue ;;
    esac
    visited="$visited$child "
    path_of[$child]="$childpath"
    queue+=("$child")
  done < <(jq -r 'to_entries[] | [.key, (.value | type), (if (.value | type) == "string" then .value else .value[0] end)] | @tsv' <<<"$inputs")
done

# ── Filter to github/gitlab pinned nodes and compare with upstream ──
upstream_head() {
  local type="$1" owner="$2" repo="$3" ref="$4"
  local url
  case "$type" in
  github)
    url="https://api.github.com/repos/${owner}/${repo}/commits"
    [ -n "$ref" ] && url="${url}/${ref}"
    # -L: several inputs live at transferred/renamed repo names
    curl -sL "${CURL_AUTH[@]}" "$url" | jq -r 'if type == "array" then .[0].sha else .sha end' 2>/dev/null
    ;;
  gitlab)
    url="https://gitlab.com/api/v4/projects/${owner}%2F${repo}/repository/commits/${ref:-HEAD}"
    curl -sL "$url" | jq -r '.id' 2>/dev/null
    ;;
  esac
}

drifted=()  # path|node|upstream rows
failed=()
ok=0
for node in "${queue[@]}"; do
  [ "$node" = "root" ] && continue
  path="${path_of[$node]}"
  [ -z "$path" ] && continue # nodes reachable only via follows: nothing to update
  row="$(jq -rn --arg n "$node" --argjson l "$(cat "$LOCK")" '
    ($l.nodes[$n].original // null) as $o
    | select($o != null)
    | select($o.type == "github" or $o.type == "gitlab")
    | select($l.nodes[$n].locked.rev != null)
    | [$o.type, ($o.owner // "-"), ($o.repo // "-"), ($o.ref // "-"), $l.nodes[$n].locked.rev]
    | join("|")
  ' 2>/dev/null || true)"
  [ -z "$row" ] && continue
  IFS='|' read -r type owner repo ref rev <<<"$row"
  [ "$owner" = "-" ] && owner=""
  [ "$repo" = "-" ] && repo=""
  [ "$ref" = "-" ] && ref=""
  upstream="$(upstream_head "$type" "$owner" "$repo" "$ref")"
  if [ -z "$upstream" ]; then
    echo "FAIL  ${path} (${owner}/${repo}@${ref:-default}): upstream lookup failed"
    failed+=("$path")
  elif [ "$rev" = "$upstream" ]; then
    echo "OK    ${path}"
    ok=$((ok + 1))
  else
    echo "DRIFT ${path} (${owner}/${repo}@${ref:-default}) lock=${rev:0:7} upstream=${upstream:0:7}"
    drifted+=("${path}|${node}|${upstream}")
  fi
done

# ── Classify drifted nodes: movable vs pinned-by-parent ──────────────
# Probe a temp copy of the flake: whatever `nix flake update <paths>`
# cannot advance is pinned by its parent flake's own lock.
movable=()
pinned=()
if [ "${#drifted[@]}" -gt 0 ] && command -v nix >/dev/null 2>&1; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  mkdir -p "${tmpdir}/flake"
  (cd "$FLAKE_DIR" && tar --exclude=.git --exclude=result -cf - .) | tar -xf - -C "${tmpdir}/flake"
  if (cd "${tmpdir}/flake" && nix flake update "${NIX_AUTH[@]+"${NIX_AUTH[@]}"}" ${drifted[@]%%|*} >/dev/null 2>&1); then
    for row in "${drifted[@]}"; do
      IFS='|' read -r path node upstream <<<"$row"
      newrev="$(jq -r --arg n "$node" '.nodes[$n].locked.rev // empty' "${tmpdir}/flake/flake.lock")"
      if [ -n "$newrev" ] && [ "$newrev" != "$upstream" ] && [ "$newrev" = "$(jq -r --arg n "$node" '.nodes[$n].locked.rev' "$LOCK")" ]; then
        echo "PINNED ${path} (rev pinned by its parent flake's lock — moves only when the parent root input updates)"
        pinned+=("$path")
      else
        movable+=("$path")
      fi
    done
  else
    # Probe failed entirely (offline?); treat everything as movable so
    # update mode still tries, per-path, with its own error handling.
    for row in "${drifted[@]}"; do
      movable+=("${row%%|*}")
    done
  fi
else
  for row in "${drifted[@]}"; do
    movable+=("${row%%|*}")
  done
fi

echo
echo "Summary: ${ok} current, ${#movable[@]} drifted, ${#pinned[@]} parent-pinned, ${#failed[@]} lookup-failed (${#queue[@]}-1 lock nodes scanned)"

case "$MODE" in
check)
  if [ "${#movable[@]}" -gt 0 ] || [ "${#failed[@]}" -gt 0 ]; then
    echo "Run 'task dev:flake:update-transitive' to advance the drifted pins."
    exit 1
  fi
  echo "All updatable transitive inputs current."
  ;;
update)
  if [ "${#movable[@]}" -eq 0 ]; then
    echo "Nothing to update."
    exit 0
  fi
  # Optional path filter via CLI args
  if [ "$#" -gt 0 ]; then
    filtered=()
    for want in "$@"; do
      for p in "${movable[@]}"; do
        [ "$p" = "$want" ] && filtered+=("$p")
      done
    done
    movable=("${filtered[@]}")
  fi
  if [ "${#movable[@]}" -eq 0 ]; then
    echo "No drifted paths match the given filter."
    exit 1
  fi
  skipped=()
  for p in "${movable[@]}"; do
    echo ":: updating ${p}"
    if (cd "$FLAKE_DIR" && nix flake update "$p" "${NIX_AUTH[@]+"${NIX_AUTH[@]}"}"); then
      echo ":: updated ${p}"
    else
      echo ":: skipped ${p} (nix refused — likely parent-pinned)"
      skipped+=("$p")
    fi
  done
  if [ "${#skipped[@]}" -gt 0 ]; then
    echo "Skipped: ${skipped[*]}"
  fi
  echo "Done. Review 'git diff flake.lock', then commit."
  ;;
*)
  echo "Unknown mode: $MODE (use check|update)" >&2
  exit 2
  ;;
esac
