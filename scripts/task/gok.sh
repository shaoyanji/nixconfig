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

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
src=$repo/hosts/gok
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
  password=$(sops -d --extract "$secret" "$repo/modules/secrets.yaml")
  [ -n "$password" ] || {
    echo "gok.sh: no password at $secret in modules/secrets.yaml" >&2
    exit 1
  }

  # A cached copy may hold keys gok wrote at runtime (pinned TLS cert/key). The
  # repo wins for everything it declares; anything repo-absent survives the merge.
  if [ -f "$inst/config.json" ]; then
    jq -s '.[0] * .[1]' "$inst/config.json" "$src/config.json" > "$inst/config.json.tmp"
  else
    cp "$src/config.json" "$inst/config.json.tmp"
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
  authkey=$(sops -d --extract '["gokrazy"]["gok"]["tailscale_auth_key"]' "$repo/modules/secrets.yaml" 2>/dev/null || true)
  # The flag list comes from the repo (`up`, `--hostname=gok`); the key is
  # appended here and never written back, so rotating it is one sops edit.
  if [ -n "$authkey" ]; then
    jq --arg k "--auth-key=$authkey" \
      '.PackageConfig["tailscale.com/cmd/tailscale"].CommandLineFlags += [$k]' \
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
  export GOCACHE=$cache/go/build
  export GOMODCACHE=$cache/go/mod
  mkdir -p "$GOCACHE" "$GOMODCACHE"
  nix shell nixpkgs#gokrazy nixpkgs#go -c gok -i gok --parent_dir "$cache" "$@"
}

# Cache -> repo, with every secret stripped back out: the HTTP password, the TLS
# material gok pins, and the tailscale auth key.
save() {
  umask 077
  jq 'del(.Update.HTTPPassword, .Update.CertPEM, .Update.KeyPEM)
      | if .PackageConfig["tailscale.com/cmd/tailscale"]
        then .PackageConfig["tailscale.com/cmd/tailscale"].CommandLineFlags |=
             map(select(startswith("--auth-key=") | not))
        else . end' "$inst/config.json" > "$src/config.json"
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
    echo "gok.sh: repo updated at hosts/gok/config.json (password + TLS keys stripped)"
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
