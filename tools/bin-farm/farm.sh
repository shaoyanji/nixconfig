#!/usr/bin/env bash
# farm.sh — content-addressed aarch64 static binary farm.
#
#   farm.sh lock            resolve farm.toml -> farm.lock.json (fetch or build)
#   farm.sh verify DIR      compare DIR/bin against the lock, report drift
#   farm.sh deploy HOST     push store + symlink farm to HOST (additive only)
#
# Layout on the receiver:
#   store/<sha256>/<name>          content-addressed, immutable
#   bin/<name> -> ../store/<sha256>/<name>
#
# Identity is the content hash, so a plain `rsync --checksum` converges and
# nothing depends on mtime or filename. A tool absent from farm.toml is never
# touched; a real file at bin/<name> is never overwritten.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cache=${FARM_CACHE:-$here/.cache}
lock=$here/farm.lock.json
mkdir -p "$cache"

die() { printf '%s\n' "$*" >&2; exit 1; }

get() { # table key
  awk -v want="$1" -v key="$2" '
    /^\[/ { t=$0; gsub(/[][ ]/,"",t); next }
    t==want { line=$0; sub(/#.*/,"",line)
      split(line, kv, "=")
      k=kv[1]; gsub(/[ \t]/,"",k)
      if (k==key) { v=substr(line, index(line,"=")+1); gsub(/^[ \t]+|[ \t]+$/,"",v)
                    gsub(/^"|"$/,"",v); print v; exit } }' "$here/farm.toml"
}

tables() { sed -n 's/^\[\([a-zA-Z0-9._-]*\)\].*/\1/p' "$here/farm.toml"; }

sha() { sha256sum "$1" | cut -d' ' -f1; }

fetch_release() { # name -> prints path to binary in cache
  local name=$1 url sha256 member dest
  url=$(get "$name" url); sha256=$(get "$name" sha256); member=$(get "$name" member)
  [ -n "$url" ] || die "$name: release provider needs url"
  dest=$cache/$name-$(basename "${url%%\?*}")
  if [ -f "$dest" ] && [ "$(sha "$dest")" = "$sha256" ]; then
    : # cached and verified
  else
    curl -fsSL --retry 3 --connect-timeout 15 -o "$dest.part" "$url" || die "$name: download failed"
    if [ -z "$sha256" ]; then
      mv "$dest.part" "$dest"
      die "$name: no sha256 pinned. Verify upstream and add to farm.toml:
  sha256 = \"$(sha "$dest")\""
    fi
    [ "$(sha "$dest.part")" = "$sha256" ] || die "$name: sha256 MISMATCH — refusing to install
  expected $sha256
  actual   $(sha "$dest.part")"
    mv "$dest.part" "$dest"
  fi
  local x=$cache/x-$name; rm -rf "$x"; mkdir -p "$x"
  case $dest in
    *.tar.xz) tar -xJf "$dest" -C "$x" ;;
    *.tar.gz|*.tgz) tar -xzf "$dest" -C "$x" ;;
    *.zip) unzip -q "$dest" -d "$x" ;;
    *) cp "$dest" "$x/$name" ;;   # bare binary
  esac
  if [ -n "$member" ]; then
    [ -f "$x/$member" ] || die "$name: member '$member' not in archive"
    printf '%s\n' "$x/$member"
  else
    find "$x" -type f -perm -u+x -name "$name" | head -1
  fi
}

build_nixpkgs() { # name -> prints path to binary
  local name=$1 attr
  command -v nix >/dev/null || die "$name: nixpkgs provider needs nix on an aarch64 host"
  [ "$(uname -m)" = aarch64 ] || die "$name: cross-compiling static musl needs an aarch64 builder"
  attr=$(get "$name" attr)
  local out rel
  # some pkgs split outputs (sqlite -> -bin, -man); the bin output comes first
  out=$(nix build --no-link --print-out-paths "nixpkgs#pkgsStatic.$attr" | head -1)
  rel=$(get "$name" bin)
  printf '%s\n' "$out/${rel:-bin/$name}"
}

cmd_lock() {
  local name bin h tmp
  tmp=$(mktemp -d)
  : > "$tmp/lock.ndjson"
  for name in $(tables); do
    local provider version
    provider=$(get "$name" provider); version=$(get "$name" version)
    printf '  %-16s %-8s %s ... ' "$name" "$provider" "$version"
    case $provider in
      release) bin=$(fetch_release "$name") ;;
      nixpkgs) bin=$(build_nixpkgs "$name") ;;
      *) die "$name: unknown provider '$provider'" ;;
    esac
    [ -f "$bin" ] || die "$name: no binary produced"
    h=$(sha "$bin")
    local sz; sz=$(stat -c %s "$bin")
    mkdir -p "$here/store/$h" && install -m 0755 "$bin" "$here/store/$h/$name"
    printf '{"name":"%s","provider":"%s","version":"%s","sha256":"%s","size":%s}\n' \
      "$name" "$provider" "$version" "$h" "$sz" >> "$tmp/lock.ndjson"
    printf 'ok  %s  %s\n' "${h:0:12}" "$(numfmt --to=iec "$sz")"
  done
  python3 - "$tmp/lock.ndjson" "$lock" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
json.dump({r["name"]: r for r in rows}, open(sys.argv[2], "w"), indent=2, sort_keys=True)
print(f"wrote {sys.argv[2]} ({len(rows)} tools)")
PY
  rm -rf "$tmp"
}

cmd_verify() {
  local dir=${1:?usage: farm.sh verify DIR}
  python3 - "$dir" "$lock" <<'PY'
import hashlib, json, os, sys
d, lf = sys.argv[1], sys.argv[2]
lock = json.load(open(lf)) if os.path.exists(lf) else {}
bin = os.path.join(d, "bin")
names = sorted(os.listdir(bin)) if os.path.isdir(bin) else []
print(f"{'tool':<18}{'state':<12}{'lock':<10}{'disk sha256'}")
for n in names:
    p = os.path.join(bin, n)
    real = os.path.realpath(p)
    if not os.path.exists(real):
        print(f"{n:<18}{'BROKEN':<12}{lock.get(n,{}).get('version','-'):<10}-> {real}"); continue
    h = hashlib.sha256(open(real,'rb').read()).hexdigest()
    if n not in lock:   state = "UNMANAGED"
    elif h != lock[n]["sha256"]: state = "DRIFT"
    else:               state = "ok"
    print(f"{n:<18}{state:<12}{lock.get(n,{}).get('version','-'):<10}{h[:12]}")
PY
}

cmd_deploy() {
  # /volume1 itself is root-owned on DSM; the shared folder is where a normal
  # account can write, and it is next to the legacy flat bin-aarch64 dump.
  local host=${1:?usage: farm.sh deploy HOST [REMOTE]} remote=${2:-"/volume1/Shared Library/toolbox"}
  python3 - "$here" "$host" "$remote" <<'PY'
import json, os, shlex, subprocess, sys
here, host, remote = sys.argv[1], sys.argv[2], sys.argv[3]
# The remote path has a space in it ("/volume1/Shared Library"), and every
# command below runs through ssh's own shell, so it must be quoted there.
rq = shlex.quote(remote)
lock = json.load(open(os.path.join(here, "farm.lock.json")))
store = os.path.join(here, "store")
ssh = ["ssh", "-o", "BatchMode=yes", host]

out = subprocess.run(ssh + [f"ls -ld {rq}/bin/* 2>/dev/null; ls -l {rq}/bin 2>/dev/null"],
                     capture_output=True, text=True).stdout
real_files = set()
for line in out.splitlines():
    parts = line.split()
    if len(parts) >= 9 and "->" not in line and line.startswith("-"):
        real_files.add(parts[-1])           # regular file, not our symlink

for name, e in sorted(lock.items()):
    if name in real_files:
        print(f"REFUSE  {name}: {remote}/bin/{name} is a real file (not farm-managed). Left untouched.")
        continue
    src = os.path.join(store, e["sha256"], name)
    dest = f"{remote}/store/{e['sha256']}/{name}"
    dq, part = shlex.quote(dest), shlex.quote(dest + ".part")
    try:
        subprocess.run(ssh + [f"mkdir -p {rq}/store/{e['sha256']} {rq}/bin"], check=True, capture_output=True)
        # ssh + cat, not scp: this sshd has no sftp subsystem configured
        with open(src, "rb") as fh:
            r = subprocess.run(ssh + [f"cat > {part}"], stdin=fh, capture_output=True)
        if r.returncode:
            print(f"FAIL    {name}: upload failed: {r.stderr.decode().strip()[:80]}"); continue
        far = subprocess.run(ssh + [f"sha256sum {part}"], capture_output=True, text=True, check=True).stdout.split()[0]
        if far != e["sha256"]:
            subprocess.run(ssh + [f"rm -f {part}"], capture_output=True)
            print(f"FAIL    {name}: remote hash {far[:12]} != lock {e['sha256'][:12]}"); continue
        subprocess.run(ssh + [f"mv {part} {dq}; chmod 0755 {dq}; "
                              f"ln -sfn ../store/{e['sha256']}/{name} {rq}/bin/{name}"], check=True, capture_output=True)
        print(f"ok      {name} {e['version']}  {e['sha256'][:12]}  verified on {host}")
    except subprocess.CalledProcessError as exc:
        print(f"FAIL    {name}: {exc.stderr.decode().strip()[:100] if exc.stderr else exc}")
PY
}

case ${1:-} in
  lock) shift; cmd_lock "$@" ;;
  verify) shift; cmd_verify "$@" ;;
  deploy) shift; cmd_deploy "$@" ;;
  *) sed -n '2,13p' "$0" ;;
esac
