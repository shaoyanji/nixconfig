#!/usr/bin/env bash
# ssh-key-modes.sh — assert SSH private keys cannot be read by anyone else and
# that user certificates are readable and actually parse.
#
# Why: ssh(1) refuses a private key that group/other can read, and a certificate
# that is unreadable — or is not a certificate at all — silently degrades a
# certificate login back to a plain-key login (`-v` is the only hint). This is
# the one part of the SSH-CA setup nothing else in the tree asserts: the
# `*-cert.pub` written by `ssh-keygen -s` is deliberately 644 (certificates are
# public), so a blanket "chmod 600 ~/.ssh/*" would be the wrong fix.
#
# Rules
#   private keys        no group/other permission bits (mode & 077 == 0), which
#                       is exactly what ssh enforces: 600 and 400 pass, 640/644
#                       fail. Detected by name (id_*, *.key, user_ca_key) and by
#                       the `-----BEGIN … PRIVATE KEY-----` header, so a key
#                       under an unexpected name is still caught.
#   certificates        `*-cert.pub`: owner-readable (mode & 400) and
#                       `ssh-keygen -L` parses it.
#
# Symlinks are followed: ~/.ssh/id_ed25519 -> ~/security/ssh/id_ed25519 and
# user_ca_key -> sops-nix secrets. A dangling one is reported, not skipped.
#
# Exit codes: 0 = every key/certificate passes; 1 = at least one violation (or a
#   dangling symlink); 2 = cannot evaluate (SSH_DIR missing, stat/ssh-keygen
#   unavailable, or nothing to check).
set -uo pipefail

SSH_DIR="${SSH_DIR:-$HOME/.ssh}"

for bin in stat ssh-keygen; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERROR: $bin is required" >&2
    exit 2
  }
done

[ -d "$SSH_DIR" ] || {
  echo "ERROR: SSH_DIR '$SSH_DIR' is not a directory" >&2
  exit 2
}

perm() { stat -Lc '%a' -- "$1" 2>/dev/null; }

is_private_name() {
  case "$(basename -- "$1")" in
    *.pub | known_hosts* | config* | authorized_keys*) return 1 ;;
    id_* | *.key | user_ca_key) return 0 ;;
  esac
  head -n1 -- "$1" 2>/dev/null | grep -q -- '-----BEGIN .*PRIVATE KEY-----'
}

fail=0
checked_keys=0
checked_certs=0

echo "=== ssh key modes: ${SSH_DIR} ==="

# -L follows symlinks; -type l then matches only the dangling ones, which are
# reported below instead of being silently skipped.
while IFS= read -r -d '' f; do
  [ -e "$f" ] || {
    echo "FAIL  $(basename -- "$f"): dangling symlink (mode check impossible)"
    fail=1
    continue
  }
  is_private_name "$f" || continue
  mode="$(perm "$f")" || {
    echo "FAIL  $(basename -- "$f"): cannot stat"
    fail=1
    continue
  }
  checked_keys=$((checked_keys + 1))
  if ((8#$mode & 8#077)); then
    echo "FAIL  $(basename -- "$f"): mode ${mode} is group/other-accessible (need 600-class)"
    fail=1
  else
    echo "OK    $(basename -- "$f"): ${mode}"
  fi
done < <(find -L "$SSH_DIR" -maxdepth 1 \( -type f -o -type l \) -print0 2>/dev/null)

while IFS= read -r -d '' f; do
  mode="$(perm "$f")" || {
    echo "FAIL  $(basename -- "$f"): cannot stat (dangling certificate symlink?)"
    fail=1
    continue
  }
  checked_certs=$((checked_certs + 1))
  if ((!(8#$mode & 8#400))); then
    echo "FAIL  $(basename -- "$f"): mode ${mode} — not owner-readable"
    fail=1
  elif ! ssh-keygen -L -f "$f" >/dev/null 2>&1; then
    echo "FAIL  $(basename -- "$f"): mode ${mode} but ssh-keygen -L cannot parse it"
    fail=1
  else
    echo "OK    $(basename -- "$f"): ${mode}, parses as a certificate"
  fi
done < <(find -L "$SSH_DIR" -maxdepth 1 -type f -name '*-cert.pub' -print0 2>/dev/null)

echo
if ((checked_keys + checked_certs == 0)); then
  echo "NOT EVALUABLE: no private keys or certificates in ${SSH_DIR}" >&2
  exit 2
fi
if ((fail)); then
  echo "ERROR: SSH key/certificate violations in ${SSH_DIR}" >&2
  exit 1
fi

echo "OK: ${checked_keys} private key(s) 600-class, ${checked_certs} certificate(s) readable and valid"
exit 0
