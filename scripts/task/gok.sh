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
}

# `go` is gok's build dependency, not something this repo installs: gok shells
# out to it for every package in the instance.
gok() {
  nix shell nixpkgs#gokrazy nixpkgs#go -c gok -i gok --parent_dir "$cache" "$@"
}

# Cache -> repo, with every secret gok may have written stripped back out.
save() {
  umask 077
  jq 'del(.Update.HTTPPassword, .Update.CertPEM, .Update.KeyPEM)' "$inst/config.json" \
    > "$src/config.json"
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
    gok "$@"
    ;;
esac
