#!/usr/bin/env bash
# gok.sh — edit and push the declarative gokrazy instance. Repo is the source of
# truth; the password comes from sops; runtime TLS state stays in a local cache.
#
#   gok.sh show                 resolved config, EVERY credential masked
#   gok.sh edit                 $EDITOR on the cached copy, then write back to the repo
#   gok.sh build [OUT]          build root/boot/mbr into OUT — no device, no network
#   gok.sh push [--stage|--testboot] [ARTIFACT]   stream it — no gok, no Go
#   gok.sh fetch [DEST]         download the newest artifact from the artifact host
#   gok.sh update [--insecure]  build + push in one process
#   gok.sh overwrite --full=/dev/sdX   reflash a card
#   gok.sh <anything else>      passed straight to gok
set -euo pipefail

# `pwd -P`: builtins.getFlake refuses a path that is a symlink, and the repo is
# reached through one on this fleet (~/Documents/nixconfig -> /Volumes/data/...).
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
decl=$repo/hosts/gok/instance.nix
cache=${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-gok
inst=$cache/gok
secret='["gokrazy"]["gok"]["http_password"]'

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# One lookup, two consumers: `materialize` bakes it into config.json and `push`
# sends it as basic auth. CI has no age key, so the environment wins when set.
update_password() {
  if [ -n "${GOK_HTTP_PASSWORD:-}" ]; then
    printf '%s' "$GOK_HTTP_PASSWORD"
  else
    sops -d --extract "$secret" "$repo/modules/secrets.yaml"
  fi
}

materialize() {
  mkdir -p "$inst"
  chmod 700 "$cache" "$inst"

  local password
  password=$(update_password || true)
  [ -n "$password" ] || {
    echo "gok.sh: no password at $secret in modules/secrets.yaml and GOK_HTTP_PASSWORD unset" >&2
    exit 1
  }

  # The spec is MODULE OUTPUT, not a file: modules/services/gokrazy.nix renders
  # hosts/gok/instance.nix into a config.json whose credential positions are "".
  # A cached copy may also hold values gok wrote at runtime (pinned TLS cert and
  # key), which the module does not declare, so the cache wins only for keys the
  # repo does not mention.
  local declared
  declared=$(nix eval --impure --json --expr "
    let
      flake = builtins.getFlake (toString $repo);
      lib = flake.inputs.nixpkgs.lib;
      ev = lib.evalModules { modules = [ $repo/modules/services/gokrazy.nix $decl ]; };
    in (builtins.fromJSON ev.config.services.gokrazy.rendered.gok.configJSON)
  " 2>/dev/null) || {
    echo "gok.sh: could not render $decl — run 'nix eval --impure' on it to see why" >&2
    exit 1
  }
  if [ -f "$inst/config.json" ]; then
    printf '%s' "$declared" | jq -s '.[0] * .[1]' "$inst/config.json" - > "$inst/config.json.tmp"
  else
    printf '%s' "$declared" | jq '.' > "$inst/config.json.tmp"
  fi

  jq --arg p "$password" '.Update = ((.Update // {}) + {HTTPPassword: $p})' \
    "$inst/config.json.tmp" > "$inst/config.json"
  rm -f "$inst/config.json.tmp"
  chmod 600 "$inst/config.json"

  # The fleet key list has exactly one home (modules/config/authorized-keys.nix),
  # so an appliance reflash cannot drift from the hosts that may log in to it.
  nix eval --json "$repo#nixosConfigurations.frieren.config.ssh.authorizedKeys.keys" 2>/dev/null |
    jq -r '.[]' > "$inst/breakglass.authorized_keys"

  # Unattended tailscale auth only if a key exists in sops. Absent (the default),
  # `tailscale up` prints a login URL in the appliance's web UI and the session
  # persists in the ext4 /perm partition.
  local authkey
  # Same two sources as the password, for the same reason: a runner has no age
  # key, and an image built without this joins the tailnet only if the node key
  # already persists in /perm. Absent is reported in the artifact's manifest, so
  # a deploy never has to guess.
  if [ -n "${GOK_TAILSCALE_AUTH_KEY:-}" ]; then
    authkey=$GOK_TAILSCALE_AUTH_KEY
  else
    authkey=$(sops -d --extract '["gokrazy"]["gok"]["tailscale_auth_key"]' "$repo/modules/secrets.yaml" 2>/dev/null || true)
  fi
  # WiFi credentials never enter the repo: the instance ships an empty
  # /etc/wifi.json and this fills it from the environment or sops. No keys → no
  # wifi package at all, which is the wired default.
  #
  # The environment wins for the same reason the update password's does: a CI
  # runner has no age key. Without this the package was DELETED in every
  # CI-built image, so an update silently took a wifi appliance off the air
  # (2026-10-26). An absent SSID is now reported in the manifest as
  # `wifi: absent`, which is what `task infra:gok:deploy` reads before pushing.
  local wifi_ssid wifi_psk
  if [ -n "${GOK_WIFI_SSID:-}" ]; then
    wifi_ssid=$GOK_WIFI_SSID
    wifi_psk=${GOK_WIFI_PSK:-}
  else
    wifi_ssid=$(sops -d --extract '["gokrazy"]["gok"]["wifi_ssid"]' "$repo/modules/secrets.yaml" 2>/dev/null || true)
    wifi_psk=$(sops -d --extract '["gokrazy"]["gok"]["wifi_psk"]' "$repo/modules/secrets.yaml" 2>/dev/null || true)
  fi
  if [ -n "$wifi_ssid" ]; then
    jq --arg s "$wifi_ssid" --arg p "$wifi_psk" \
      '.PackageConfig["github.com/gokrazy/wifi"].ExtraFileContents["/etc/wifi.json"] =
         (({ssid: $s} + (if $p == "" then {} else {psk: $p} end)) | tojson + "\n")' \
      "$inst/config.json" > "$inst/config.json.tmp"
    mv "$inst/config.json.tmp" "$inst/config.json"
    chmod 600 "$inst/config.json"
  else
    # No SSID in sops = a wired appliance. The rendered spec carries a wifi entry
    # with empty credentials (the module cannot know whether the secret exists at
    # eval time), and shipping THAT would have the appliance try to associate to
    # an empty network. Removing it is the difference between "no wifi" and
    # "broken wifi".
    jq 'del(.PackageConfig["github.com/gokrazy/wifi"])' \
      "$inst/config.json" > "$inst/config.json.tmp"
    mv "$inst/config.json.tmp" "$inst/config.json"
    chmod 600 "$inst/config.json"
    # Loud, because the consequence is silence: an image without this package
    # cannot associate, and the appliance only reveals that after it reboots.
    echo "gok.sh: WARNING — no wifi credentials (GOK_WIFI_SSID, or gokrazy/gok/wifi_ssid in sops);" >&2
    echo "         this image has no wifi package and can only run on a wired node." >&2
  fi

  # The flag list comes from the repo (`up`, `--hostname=gok`); the key is
  # appended here and never written back, so rotating it is one sops edit.
  #
  # Any `--auth-key=` already in the file is dropped FIRST. A cached instance that
  # predates a rotation otherwise keeps the old key next to the new one, and gok
  # bakes both into the image — the appliance would still carry a key that was
  # rotated precisely because it should stop working.
  if [ -n "$authkey" ]; then
    jq --arg k "--auth-key=$authkey" \
      '.PackageConfig["tailscale.com/cmd/tailscale"].CommandLineFlags |=
         (map(select(startswith("--auth-key=") | not)) + [$k])' \
      "$inst/config.json" > "$inst/config.json.tmp"
    mv "$inst/config.json.tmp" "$inst/config.json"
    chmod 600 "$inst/config.json"
  fi
}

# `go` is gok's build dependency, not something this repo installs: gok shells
# out to it for every package in the instance.
#
# Build caches live in the instance cache, not in $HOME: gok's `builddir` (per
# module) plus Go's compile cache and module cache are what stop every push
# from recompiling tailscale (~90 MB of Go) from source. Kept together so this
# host is the appliance's builder — a warm push reuses them, and `rm -rf $cache`
# resets the lot.
gok() {
  export GOCACHE=${GOCACHE:-$cache/go/build}
  export GOMODCACHE=${GOMODCACHE:-$cache/go/mod}
  mkdir -p "$GOCACHE" "$GOMODCACHE"
  # GOK_BIN lets CI use the gok it installed, so the build runs on the runner
  # instead of a NAS; locally the same wrapper gets it from a nix shell.
  if [ -n "${GOK_BIN:-}" ]; then
    "$GOK_BIN" -i gok --parent_dir "$cache" "$@"
  else
    nix shell nixpkgs#gokrazy nixpkgs#go -c gok -i gok --parent_dir "$cache" "$@"
  fi
}

# --- artifact-first deployment -----------------------------------------------
#
# `gok update` builds and pushes in one process, which is why none of it could be
# split across a runner and the device: the push is three streams —
# PUT /update/{root,boot,mbr} (github.com/gokrazy/updater, StreamTo) — and those
# are exactly the files `gok overwrite --root/--boot/--mbr` writes. `overwrite`
# stops before the device is contacted (`newInstallation` returns ahead of
# logicUpdate in gok's internal/packer), so a build on a runner and a push from a
# laptop are the same artifact. `push` below speaks that protocol with curl: no
# Go, no gok, no compiling at deploy time. Deploy path: workflows/gok.yml builds
# and drops the tarball on delphi, `task infra:gok:deploy` fetches and streams it.

# gok's URL banner carries the update password in it, and build.log travels with
# the artifact, so the file is redacted once the build is done.
redact() {
  sed -i -E 's#(//)[^@/ ]+@#\1REDACTED@#g' "$1"
}

build() {
  local out=${1:-}
  if [ -z "$out" ]; then
    out=$cache/artifacts/$(date -u +%Y%m%dT%H%M%SZ)-$(git -C "$repo" rev-parse --short=8 HEAD 2>/dev/null || echo nogit)
  fi
  out=${out%/}
  mkdir -p "$out"
  materialize
  echo "gok.sh: building the appliance into $out" >&2
  # `tee … >&2`: the log goes to the operator AND to the file, never to stdout —
  # stdout is the tarball path, which CI captures with $( ).
  # `</dev/null` because this runs unattended on a runner: gok asks for sudo
  # without `--sudo never`, and a question with no TTY is an infinite wait — the
  # 19-minute silence that made two CI runs look hung. The bound is the caller's
  # (`timeout … gok.sh build` in the workflow); `gok` here is a shell function, so
  # `timeout gok` would look for an executable and fail with 127.
  gok overwrite \
    --root="$out/root.squashfs" \
    --boot="$out/boot.fat" \
    --mbr="$out/mbr.img" \
    --sudo never </dev/null 2>&1 | tee "$out/build.log" >&2
  redact "$out/build.log"

  # The device reports this timestamp from `/` after it has booted the new root,
  # which is what lets `push` prove the appliance runs THIS artifact rather than
  # merely answering HTTP again.
  local buildts rev dirty
  buildts=$(sed -n 's/^.*Build timestamp: //p' "$out/build.log" | tail -1)
  [ -n "$buildts" ] || buildts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  rev=$(git -C "$repo" rev-parse HEAD 2>/dev/null || echo unknown)
  if git -C "$repo" diff --quiet 2>/dev/null; then dirty=false; else dirty=true; fi

  # Which credential slots actually got filled. A runner has no age key, so a
  # CI-built image carries the update password (a GitHub secret) and NOT the
  # tailscale auth key or the wifi entry — the same omission that would have been
  # invisible before, and the reason this is in the manifest `push` prints.
  local creds
  creds=$(jq -n \
    --arg password baked \
    --arg authkey "$([ -n "${GOK_TAILSCALE_AUTH_KEY:-}" ] && echo env || { [ -s "$inst/config.json" ] && jq -e '.PackageConfig["tailscale.com/cmd/tailscale"].CommandLineFlags[]? | select(startswith("--auth-key="))' "$inst/config.json" >/dev/null 2>&1 && echo baked || echo absent; })" \
    --arg wifi "$(jq -e '.PackageConfig["github.com/gokrazy/wifi"]' "$inst/config.json" >/dev/null 2>&1 && echo baked || echo absent)" \
    '{http_password: $password, tailscale_auth_key: $authkey, wifi: $wifi}')

  jq -n \
    --arg rev "$rev" --argjson dirty "$dirty" --arg buildts "$buildts" \
    --arg built "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg host "$(jq -r .Hostname "$inst/config.json")" \
    --argjson creds "$creds" \
    --argjson files "$(cd "$out" && sha256sum root.squashfs boot.fat mbr.img | jq -R -s 'split("\n") | map(select(length > 0) | split("  ")) | map({key: .[1], value: .[0]}) | from_entries')" \
    '{git: {rev: $rev, dirty: $dirty}, built: $built, buildTimestamp: $buildts, hostname: $host, credentials: $creds, files: $files}' \
    > "$out/manifest.json"
  (cd "$out" && sha256sum root.squashfs boot.fat mbr.img manifest.json > SHA256SUMS)

  tar --zstd -cf "$out.tar.zst" -C "$out" .
  # stdout is the tarball path and nothing else, because CI captures it.
  printf '%s\n' "$out.tar.zst"
  printf 'gok.sh: %s bytes, streams hash-pinned in SHA256SUMS, build %s\n' \
    "$(stat -c %s "$out.tar.zst")" "$buildts" >&2
}

# A directory or a tarball in, the directory holding the streams out.
unpack() {
  local art=$1 dir
  if [ -d "$art" ]; then
    printf '%s\n' "$art"
    return 0
  fi
  [ -f "$art" ] || {
    echo "gok.sh: no artifact at '$art' — build one (gok.sh build) or fetch the CI one (gok.sh fetch)" >&2
    return 1
  }
  dir=$(mktemp -d "${TMPDIR:-/tmp}/gok-artifact.XXXXXX")
  tar --zstd -xf "$art" -C "$dir"
  printf '%s\n' "$dir"
}
# Resolve the artifact (a directory or a tarball), verify it, hand it to the
# streamer. The wire protocol itself lives in scripts/task/gok-stream.sh, because
# the usual place to run it is the host that already holds the artifact
# (`task infra:gok:deploy` pipes that file to delphi), not this one.
push() {
  local arg art='' passthrough=()
  for arg in ${1:+"$@"}; do
    case $arg in
      --stage | --testboot) passthrough+=("$arg") ;;
      *) art=$arg ;;
    esac
  done
  if [ -z "$art" ]; then
    art=$(ls -1t "$cache"/artifacts/*.tar.zst 2>/dev/null | head -1 || true)
  fi
  [ -n "$art" ] || {
    echo "gok.sh: no artifact named and none in $cache/artifacts — build one (gok.sh build) or fetch the CI one (gok.sh fetch)" >&2
    exit 1
  }
  local dir
  dir=$(unpack "$art") || exit 1
  # A tarball unpacks into a temp dir (~140 MB); a directory is the caller's. The
  # path is interpolated rather than referenced: the trap fires after this
  # function returns, when `dir` is out of scope.
  # shellcheck disable=SC2064 # deliberate: $dir is out of scope when EXIT fires
  [ "$dir" = "$art" ] || trap "rm -rf $(printf '%q' "$dir")" EXIT
  # The password comes from sops here (this script's own two sources); the
  # streamer takes it from the environment and knows nothing about sops.
  local pw
  pw=$(update_password || true)
  [ -n "$pw" ] || {
    echo "gok.sh: no update password (sops, or GOK_HTTP_PASSWORD)" >&2
    exit 1
  }
  GOK_HTTP_PASSWORD=$pw bash "$(dirname "${BASH_SOURCE[0]}")/gok-stream.sh" ${passthrough[@]+"${passthrough[@]}"} "$dir"
}

fetch() {
  local dest=${1:-$cache/artifacts} url=${GOK_ARTIFACT_URL:-} host
  if [ -z "$url" ]; then
    host=$(nix eval --raw "$repo#inventory.hosts.delphi.network.tailscale_hostname" 2>/dev/null || true)
    url="http://${host:-delphi}.cloudforest-kardashev.ts.net/gok/latest.tar.zst"
  fi
  mkdir -p "$dest"
  local out
  out=$dest/fetched-$(date -u +%Y%m%dT%H%M%SZ).tar.zst
  echo "gok.sh: fetching $url" >&2
  curl -fsSL --progress-bar -m 900 -o "$out" "$url" || {
    rm -f "$out"
    echo "gok.sh: fetch failed. Is the artifact receiver on the artifact host up (taildrop, not ssh)?" >&2
    exit 1
  }
  printf '%s\n' "$out"
}

# There is no cache -> repo write any more, and that is the point: the instance
# is declared in $decl, so a change made with `gok edit` cannot survive the next
# render unless it is expressed there. Saying so is cheaper than a silent revert.
save() {
  umask 077
  chmod 600 "$inst/config.json"
}

case "${1:-}" in
  "" | -h | --help | help)
    usage
    ;;
  show)
    materialize
    # Everything that authenticates is masked, not just the update password.
    # This printed the wifi PSK and the tailnet auth key verbatim in the config
    # dump, which is where a terminal, a scrollback and a pasted log all keep a
    # copy. The shape is preserved — an operator still sees which slots are
    # filled and where — and each value names the sops key it came from.
    jq '
      .Update.HTTPPassword = "(sops: gokrazy.gok.http_password)"
      | .PackageConfig["tailscale.com/cmd/tailscale"].CommandLineFlags |= (
          if type == "array"
          then map(if type == "string" and startswith("--auth-key=")
                   then "--auth-key=(sops: gokrazy.gok.tailscale_auth_key)"
                   else . end)
          else . end)
      | .PackageConfig["github.com/gokrazy/wifi"].ExtraFileContents["/etc/wifi.json"] |= (
          if type == "string"
          then (fromjson | with_entries(.value = "(sops: gokrazy.gok.wifi_\(.key))") | tojson) + "\n"
          else . end)
      # Any tailnet key that reached the config by another path (a future
      # package, a hand edit that survived a render) is caught here rather than
      # relying on the list of known slots above.
      | walk(if type == "string"
             then gsub("tskey-[A-Za-z0-9_-]+"; "(sops: gokrazy.gok.tailscale_auth_key)")
             else . end)
    ' "$inst/config.json"
    ;;
  edit)
    materialize
    gok edit
    save
    echo "gok.sh: the instance is declared in hosts/gok/instance.nix — an edit made" >&2
    echo "         here lives only in $inst/config.json and is replaced on the next render." >&2
    ;;
  build)
    build "${2:-}"
    ;;
  push)
    shift
    push "$@"
    ;;
  fetch)
    fetch "${2:-}"
    ;;
  *)
    materialize
    # The instance Hostname is both the DHCP hostname and what `gok update`
    # resolves. Point one run at an address only when the name cannot be
    # resolved yet; the tailnet name stays `gok` because --hostname is in the
    # repo config, not derived from Hostname.
    if [ -n "${GOK_HOST:-}" ]; then
      echo "gok.sh: GOK_HOST=$GOK_HOST overrides Hostname for this run (device DHCP name follows it)" >&2
      jq --arg h "$GOK_HOST" '.Hostname = $h' "$inst/config.json" > "$inst/config.json.tmp"
      mv "$inst/config.json.tmp" "$inst/config.json"
    fi
    gok "$@"
    ;;
esac
