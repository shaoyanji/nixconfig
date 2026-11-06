#!/usr/bin/env bash
# clanker as an extension of the fleet: Nix on the box, jobs that outlive an ssh
# channel, and results that come back as a tar because the box has no rsync.
# Every call goes through scripts/task/instabox.sh (API key + minted ssh token),
# so nothing here needs the provider CLI. Procedure: .agents/skills/instabox.
#
# The box gives 4 vCPU and 8 GiB for at most 120 minutes per run and suspends
# after 30 idle ones, so a job is written to be resumable from its log and is
# never assumed to finish.
#
# Exit: 0 ok · 1 refused/failed · 2 usage · `wait` returns the job's status.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)" || true
[ -n "$ROOT" ] || ROOT="$(cd "$here/../.." && pwd)"

BOX="${CLANKER_NAME:-clanker}"
JOBS=/data/jobs
SOUT="$ROOT/.clanker-out"

die() {
  echo "clanker: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage: clanker.sh <command> [args]

  up                     install Nix (single-user) if missing, write nix.conf, make job dirs
  status                 box, nix, disk and job state
  jobs                   every job on the box
  job -- <cmd>           start a detached job, print its id
  logs <id> [lines]      tail a job's log
  wait <id> [seconds]    poll until the job exits, return its status
  result <id> [path]     tar a job's out/ (or an absolute path) back here
  cancel <id>            kill a job's process group
  nix <attr> [--wait]    send the tree, `nix build .#<attr>` on the box, print the path
  go <pkg> [--wait]      send the tree, `go build` on the box, fetch the binary
  profile [--wait]       send the tree, build and activate homeConfigurations.clanker
EOF
  exit 2
}

# One command string per call: ssh joins its arguments with spaces, so a command
# that needs its own quoting travels as a single argument.
box() {
  bash "$here/instabox.sh" ssh "$BOX" "$1"
}

# The API exec path: no token, no known_hosts, text back. Cheap enough to poll.
api_exec() {
  bash "$here/instabox.sh" exec "$BOX" "$1" 2>&1
}

new_id() {
  printf '%s-%s' "$(date -u +%Y%m%dT%H%M%S)" "$(head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
}

require_id() {
  [ -n "${1:-}" ] || usage
  case "$1" in
    *[!A-Za-z0-9-]*) die "not a job id: $1" ;;
  esac
}

# The wrapper writes `exit` last, so its absence *is* "running" — no pid file to
# go stale when the box suspends under the job.
WRAP='#!/usr/bin/env bash
set -u
dir="$1"
cd "$dir" || exit 1
bash "$dir/cmd.sh" > "$dir/log" 2>&1
printf "%s\n" "$?" > "$dir/exit.tmp"
mv "$dir/exit.tmp" "$dir/exit"
'

start_job() {
  local id="$1" cmd="$2"
  printf '%s' "$cmd" | box "set -e; mkdir -p $JOBS/$id; cat > $JOBS/$id/cmd.sh; chmod +x $JOBS/$id/cmd.sh"
  printf '%s' "$WRAP" | box "cat > $JOBS/$id/wrap.sh; chmod +x $JOBS/$id/wrap.sh"
  # setsid, not just nohup: the gateway closes the session when this ssh ends,
  # and a child in the session's process group would be killed with it.
  box "setsid nohup $JOBS/$id/wrap.sh $JOBS/$id </dev/null >/dev/null 2>&1 & sleep 1; echo started $id"
}

push_tree() {
  local src="/data/src/$1"
  git -C "$ROOT" archive --format=tar HEAD | box "mkdir -p $src && tar -xf - -C $src && echo unpacked >&2"
}

cmd="${1:-}"
[ $# -gt 0 ] && shift
case "$cmd" in
  ssh)
    # One command, ssh-joined; the kernel is the box's, not this script's.
    box "$*"
    ;;
  up)
    box 'set -eu
export PATH="$HOME/.nix-profile/bin:$PATH"
if ! command -v nix >/dev/null 2>&1; then
  echo "installing nix (single-user, no daemon) ..."
  curl -fsSL https://nixos.org/nix/install -o /tmp/nix-install.sh
  sh /tmp/nix-install.sh --no-daemon >/tmp/nix-install.log 2>&1 || { tail -20 /tmp/nix-install.log; exit 1; }
fi
mkdir -p "$HOME/.config/nix" /data/jobs /data/src /data/out
cat > "$HOME/.config/nix/nix.conf" <<CONF
experimental-features = nix-command flakes
substituters = https://shaoyanji.cachix.org https://nix-cache-edge.jisifu.workers.dev https://cache.nixos.org
trusted-public-keys = shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0= delphi.edge-1:SAQXl68hP2k5mhlWOIXCyQXFD1rVelBB22oTKQkFzwk= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
max-jobs = 4
cores = 1
sandbox = false
auto-optimise-store = true
min-free = 2147483648
CONF
"$HOME/.nix-profile/bin/nix" --version
du -sh /nix 2>/dev/null || true'
    ;;
  status)
    api_exec 'echo "== box"; nproc | sed "s/^/cpus: /"
free -g | sed -n 2p | awk "{print \"mem: \" \$2 \"G total, \" \$7 \"G available\"}"
df -h / /data | tail -2
echo "== nix"
if [ -x "$HOME/.nix-profile/bin/nix" ]; then
  "$HOME/.nix-profile/bin/nix" --version
  du -sh /nix 2>/dev/null | sed "s/^/store: /"
else
  echo "not installed (task instabox:clanker:up)"
fi
echo "== jobs"
for d in /data/jobs/*/; do
  [ -d "$d" ] || continue
  id=$(basename "$d")
  if [ -f "$d/exit" ]; then st="exit $(cat "$d/exit")"; else st=running; fi
  printf "%s  %-10s %s\n" "$id" "$st" "$(tail -c 90 "$d/log" 2>/dev/null | tr "\n" " ")"
done'
    ;;
  jobs)
    api_exec 'for d in /data/jobs/*/; do
  [ -d "$d" ] || continue
  id=$(basename "$d")
  if [ -f "$d/exit" ]; then st="exit $(cat "$d/exit")"; else st=running; fi
  printf "%s  %-10s %s\n" "$id" "$st" "$(head -c 80 "$d/cmd.sh" 2>/dev/null | tr "\n" " ")"
done'
    ;;
  job)
    err=$?
    [ "${1:-}" = "--" ] && shift
    [ $# -gt 0 ] || usage
    id="$(new_id)"
    start_job "$id" "$*" >/dev/null
    printf '%s\n' "$id"
    ;;
  logs)
    require_id "${1:-}"
    box "tail -n ${2:-40} $JOBS/$1/log 2>/dev/null || echo 'no log yet'"
    ;;
  wait)
    require_id "${1:-}"
    limit="${2:-7200}"
    waited=0
    while :; do
      state="$(api_exec "cat $JOBS/$1/exit 2>/dev/null || echo running" | tr -d '\r' | tail -1)"
      # Empty is not an exit status: it is the instant between the file existing
      # and the wrapper's value arriving.
      if [ -n "$state" ] && [ "$state" != "running" ]; then
        printf 'job %s exited %s\n' "$1" "$state"
        exit "$state"
      fi
      sleep 5
      waited=$((waited + 5))
      [ "$waited" -lt "$limit" ] || die "job $1 still running after ${limit}s"
    done
    ;;
  result)
    require_id "${1:-}"
    src="${2:-$JOBS/$1/out}"
    mkdir -p "$SOUT/$1"
    box "test -e $src || { echo 'no such path on the box: $src' >&2; exit 1; }; tar -C $(dirname "$src") -czf - $(basename "$src")" >"$SOUT/$1.tgz" ||
      die "nothing to fetch from $src"
    tar -xzf "$SOUT/$1.tgz" -C "$SOUT/$1"
    rm -f "$SOUT/$1.tgz"
    printf 'fetched %s -> %s\n' "$src" "$SOUT/$1/$(basename "$src")"
    ;;
  cancel)
    require_id "${1:-}"
    box "pkill -TERM -f '$JOBS/$1/' || true; echo 143 > $JOBS/$1/exit; echo cancelled $1"
    ;;
  nix)
    attr="${1:-}"
    shift || true
    [ -n "$attr" ] || usage
    id="$(new_id)"
    push_tree "$id"
    start_job "$id" "set -eu
export PATH=\"\$HOME/.nix-profile/bin:\$PATH\"
cd /data/src/$id
nix build -L '.#$attr' --no-link --print-out-paths | tee $JOBS/$id/out.path
nix path-info -S \"\$(cat $JOBS/$id/out.path)\" | tail -1" >/dev/null
    printf '%s\n' "$id"
    if [ "${1:-}" = "--wait" ]; then
      bash "$here/clanker.sh" wait "$id" || true
      bash "$here/clanker.sh" logs "$id" 200
    fi
    ;;
  profile)
    # The lean toolbox, activated from this tree's pinned home-manager rather
    # than a floating `nix run home-manager`: a newer CLI against the library the
    # flake pins is how an activation half-applies.
    id="$(new_id)"
    push_tree "$id"
    start_job "$id" "set -eu
export PATH=\"\$HOME/.nix-profile/bin:\$PATH\"
cd /data/src/$id
nix build -L '.#homeConfigurations.clanker.activationPackage' --no-link --print-out-paths | tee $JOBS/$id/out.path
\"\$(cat $JOBS/$id/out.path)/activate\"
echo '== profile'
ls \"\$HOME/.nix-profile/bin\" | head -40
echo '== identity'
git config --global --get user.email || true
go version || true" >/dev/null
    printf '%s\n' "$id"
    if [ "${1:-}" = "--wait" ]; then
      bash "$here/clanker.sh" wait "$id" || true
      bash "$here/clanker.sh" logs "$id" 200
    fi
    ;;
  go)
    pkg="${1:-}"
    shift || true
    [ -n "$pkg" ] || usage
    id="$(new_id)"
    push_tree "$id"
    start_job "$id" "set -eu
cd /data/src/$id/$pkg
mkdir -p $JOBS/$id/out
go build -trimpath -o $JOBS/$id/out/$(basename "$pkg") .
ls -l $JOBS/$id/out" >/dev/null
    printf '%s\n' "$id"
    if [ "${1:-}" = "--wait" ]; then
      bash "$here/clanker.sh" wait "$id" || true
      bash "$here/clanker.sh" logs "$id" 100
      bash "$here/clanker.sh" result "$id"
    fi
    ;;
  *)
    usage
    ;;
esac
