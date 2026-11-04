#!/usr/bin/env bash
# Fail when a submodule pin is not the head of the branch it tracks upstream.
#
# A gitlink is a revision nobody is watching: the project's own repository moves
# on, nixconfig keeps pointing at an older commit, and nothing in the fleet
# notices. This is the gate that notices. `projects/README.md` carries the other
# half of the rule: a path only earns a gitlink when something here opens it.
#
# What it compares is the COMMITTED pin (`git ls-tree HEAD`, not the index, not
# the working tree) against the branch head the remote reports. `.gitmodules`
# `branch =` decides the ref; without one, the remote's default branch is asked
# for with `--symref`, which is one request and no clone.
#
# Classification is deliberately two-tier. `git ls-remote` answers "is the pin
# the current head" with no fetch and no network mutation, and that is enough to
# fail. "Behind three commits" needs the upstream objects locally, so the precise
# count appears only when the submodule already has them or when FETCH=1 fetches.
#
# Offline is not a pass: a probe that cannot reach the remote reports UNKNOWN and
# exits 2. The repo's rule is that a check reports what it could not check as a
# limitation, never as green.
#
# No ssh prompt, ever. A remote may be an ssh URL (modules/secrets is), and an
# unattended check that waits on an auth prompt hangs the run, so BatchMode plus
# ConnectTimeout make the probe fail fast instead of hanging.
#
# Vars: FETCH=1 fetch into each submodule before classifying (default: no fetch).
# Exit codes: 0 = every pin is current, 1 = at least one pin has drifted,
#             2 = at least one probe could not reach its remote.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

FETCH="${FETCH:-0}"

export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=10}"

declare -A path_of_name=()
declare -A url_of=()
declare -A branch_of=()
while read -r key value; do
  name="${key#submodule.}"
  field="${name##*.}"
  name="${name%.*}"
  case $field in
    path) path_of_name["$name"]="$value" ;;
    url) url_of["$name"]="$value" ;;
    branch) branch_of["$name"]="$value" ;;
  esac
done < <(git config -f .gitmodules --get-regexp '^submodule\.' 2>/dev/null || true)

declare -A url_by_path=()
declare -A branch_by_path=()
for name in "${!path_of_name[@]}"; do
  path="${path_of_name[$name]}"
  url_by_path["$path"]="${url_of[$name]:-}"
  branch_by_path["$path"]="${branch_of[$name]:-}"
done

drifted=0
unknown=0
current=0

report() { printf '%s\n' "$*"; }

mapfile -t pins < <(git ls-tree -r HEAD | awk '$1 == "160000" { print $3 " " $4 }')

if [ "${#pins[@]}" -eq 0 ]; then
  report "submodules: none pinned in HEAD"
  exit 0
fi

for entry in "${pins[@]}"; do
  pin="${entry%% *}"
  path="${entry#* }"
  url="${url_by_path[$path]:-}"
  branch="${branch_by_path[$path]:-}"

  if [ -z "$url" ]; then
    report "submodule [$path] UNKNOWN — a gitlink with no .gitmodules url, so there is nothing to ask"
    unknown=$((unknown + 1))
    continue
  fi

  has_checkout=0
  { [ -d "$path/.git" ] || [ -f "$path/.git" ]; } && has_checkout=1

  if [ "$FETCH" = "1" ] && [ "$has_checkout" = "1" ]; then
    git -C "$path" fetch --quiet origin 2>/dev/null || true
  fi

  if [ -n "$branch" ]; then
    head_out="$(git ls-remote --quiet "$url" "refs/heads/$branch" 2>&1)" || head_out=""
    upstream="$(printf '%s\n' "$head_out" | awk -v r="refs/heads/$branch" '$2 == r { print $1; exit }')"
    ref_label="$branch"
  else
    head_out="$(git ls-remote --quiet --symref "$url" HEAD 2>&1)" || head_out=""
    upstream="$(printf '%s\n' "$head_out" | awk '$2 == "HEAD" { print $1; exit }')"
    ref_label="$(printf '%s\n' "$head_out" | sed -n 's|^ref: refs/heads/\(.*\)\tHEAD$|\1|p')"
    ref_label="${ref_label:-HEAD}"
  fi

  if [ -z "$upstream" ]; then
    reason="$(printf '%s\n' "$head_out" | head -1)"
    report "submodule [$path] UNKNOWN — cannot read $ref_label from $url${reason:+ ($reason)}"
    unknown=$((unknown + 1))
    continue
  fi

  if [ "$pin" = "$upstream" ]; then
    report "submodule [$path] PINNED — ${pin:0:7} is the head of $ref_label"
    current=$((current + 1))
    continue
  fi

  # The pin is not the head. Say which way, when the objects to prove it are here.
  distance=""
  if [ "$has_checkout" = "1" ]; then
    if git -C "$path" cat-file -e "$upstream" 2>/dev/null; then
      if git -C "$path" merge-base --is-ancestor "$pin" "$upstream" 2>/dev/null; then
        distance=", behind $(git -C "$path" rev-list --count "$pin..$upstream")"
      elif git -C "$path" merge-base --is-ancestor "$upstream" "$pin" 2>/dev/null; then
        distance=", AHEAD of upstream by $(git -C "$path" rev-list --count "$upstream..$pin") (unpushed)"
      else
        distance=", diverged"
      fi
    else
      distance=" (direction unknown without the upstream objects; FETCH=1 proves it)"
    fi
  fi

  report "submodule [$path] DRIFTED — pin ${pin:0:7} is not the head of $ref_label (${upstream:0:7})$distance"
  drifted=$((drifted + 1))
done

report "submodules: $current current, $drifted drifted, $unknown unprobed of ${#pins[@]}"

if [ "$drifted" -gt 0 ]; then
  report "  → bump the pin in a commit of its own, or retire the gitlink (inventory.toml [repos.*]) if nothing here opens the path"
  exit 1
fi
if [ "$unknown" -gt 0 ]; then
  exit 2
fi
exit 0
