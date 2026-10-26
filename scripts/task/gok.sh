#!/usr/bin/env bash
# gok.sh — edit and push the declarative gokrazy instance. Repo is the source of
# truth; the password comes from sops; runtime TLS state stays in a local cache.
#
#   gok.sh show                 resolved config, password masked
#   gok.sh edit                 $EDITOR on the cached copy, then write back to the repo
#   gok.sh update [--insecure]  build + push to the running appliance
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
  sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

materialize() {
  mkdir -p "$inst"
  chmod 700 "$cache" "$inst"

  local password
  # CI has no age key, so the password may arrive in the environment instead of
  # sops. One implementation, two sources.
  if [ -n "${GOK_HTTP_PASSWORD:-}" ]; then
    password=$GOK_HTTP_PASSWORD
  else
    password=$(sops -d --extract "$secret" "$repo/modules/secrets.yaml")
  fi
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
  ") || {
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
  # stderr stays visible: this evaluates a whole host config, and when it fails
  # on a runner (an unreachable substituter, a missing input) the old `2>/dev/null`
  # left nothing but an empty key file and a 19-minute silence to debug from.
  nix eval --json "$repo#nixosConfigurations.frieren.config.ssh.authorizedKeys.keys" |
    jq -r '.[]' > "$inst/breakglass.authorized_keys"

  # Unattended tailscale auth only if a key exists in sops. Absent (the default),
  # `tailscale up` prints a login URL in the appliance's web UI and the session
  # persists in the ext4 /perm partition.
  local authkey
  authkey=$(sops -d --extract '["gokrazy"]["gok"]["tailscale_auth_key"]' "$repo/modules/secrets.yaml" 2>/dev/null || true)
  # WiFi credentials never enter the repo: the instance ships an empty
  # /etc/wifi.json and this fills it from sops only when both keys exist. No
  # keys → no wifi file, which is the wired default.
  local wifi_ssid wifi_psk
  wifi_ssid=$(sops -d --extract '["gokrazy"]["gok"]["wifi_ssid"]' "$repo/modules/secrets.yaml" 2>/dev/null || true)
  wifi_psk=$(sops -d --extract '["gokrazy"]["gok"]["wifi_psk"]' "$repo/modules/secrets.yaml" 2>/dev/null || true)
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
    jq '.Update.HTTPPassword = "(sops: gokrazy.gok.http_password)"' "$inst/config.json"
    ;;
  edit)
    materialize
    gok edit
    save
    echo "gok.sh: the instance is declared in hosts/gok/instance.nix — an edit made" >&2
    echo "         here lives only in $inst/config.json and is replaced on the next render." >&2
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
