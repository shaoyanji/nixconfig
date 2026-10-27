#!/usr/bin/env bash
# host-restore — put a fleet host's runtime state back, idempotently.
#
# Why this exists: on 2026-10-26 a `nixos-rebuild switch` on delphi left the
# running system with no /dev/null, no /bin/sh and a home directory home-manager
# could not activate. sshd accepted connections and died before its banner, every
# unit that needs stdin failed at exec, and none of it was visible in the
# configuration — the config was correct, the runtime was not. Re-evaluating or
# re-deploying cannot fix that; only re-running the steps that build runtime
# state can, and they must be safe to run again.
#
# Every step below checks before it acts and re-checks after, so a second run is
# a no-op and a partial repair is not mistaken for a complete one.
#
#   host-restore.sh            repair, then verify
#   host-restore.sh --check     verify only, change nothing (exit 1 if not clean)
#
# Exit codes: 0 clean · 1 something is still wrong · 2 cannot repair (no sudo)
set -uo pipefail

mode=repair
case "${1:-}" in
  "" | --repair) mode=repair ;;
  --check) mode=check ;;
  -h | --help)
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "host-restore: unknown argument '$1'" >&2
    exit 64
    ;;
esac

me=$(id -un)
group=$(id -gn)
home=$(getent passwd "$me" | cut -d: -f6)
repo=$home/Documents/nixconfig
fails=0
fixes=0
needs_hm_restart=0

printf 'host-restore: host=%s user=%s mode=%s\n\n' "$(hostname -s)" "$me" "$mode"

ok() { printf '  ok      %s\n' "$*"; }
fixed() {
  fixes=$((fixes + 1))
  printf '  FIXED   %s\n' "$*"
}
bad() {
  fails=$((fails + 1))
  printf '  FAIL    %s\n' "$*"
}
warn() { printf '  warn    %s\n' "$*"; }
can_fix() { [ "$mode" = repair ]; }

# --- 1. privilege ------------------------------------------------------------
# Without this every repair below is a report, so it is a hard gate.
if sudo -n true 2>/dev/null; then
  ok "passwordless sudo"
  have_sudo=1
else
  have_sudo=0
  if [ "$mode" = repair ]; then
    bad "no passwordless sudo — cannot repair, only report"
  else
    warn "no passwordless sudo — checks that need root will be skipped"
  fi
fi

# --- 2. device nodes ---------------------------------------------------------
# /dev/null is devtmpfs state, not configuration. Its absence kills sshd's child
# before the banner and every unit that redirects its stdin.
if [ -c /dev/null ]; then
  ok "/dev/null present"
elif [ "$have_sudo" = 1 ] && can_fix &&
  sudo -n mknod /dev/null c 1 3 && sudo -n chmod 666 /dev/null; then
  fixed "/dev/null recreated (c 1 3, 0666)"
else
  bad "/dev/null missing"
fi

# --- 3. activation output ----------------------------------------------------
# /bin/sh is written by the activation script; if it is gone the generation was
# never fully applied, and re-running activation is the repair that a reboot
# performs anyway.
if [ -e /bin/sh ]; then
  ok "/bin/sh resolves"
elif [ "$have_sudo" = 1 ] && can_fix &&
  sudo -n /run/current-system/activate >/dev/null 2>&1 && [ -e /bin/sh ]; then
  fixed "/bin/sh restored by /run/current-system/activate"
else
  bad "/bin/sh missing — run: sudo /run/current-system/activate"
fi

# --- 4. ownership ------------------------------------------------------------
# Root-owned files in the user's home are how home-manager fails: it runs as the
# user and cannot mkdir into .config it does not own. `find -not -user` walks
# only the paths home-manager and git actually write.
own() {
  local path=$1
  [ -e "$path" ] || return 0
  if ! sudo -n find "$path" -xdev -not -user "$me" -print -quit 2>/dev/null | grep -q .; then
    ok "$path owned by $me"
    return 0
  fi
  if [ "$have_sudo" = 1 ] && can_fix &&
    sudo -n chown -R "$me:$group" "$path"; then
    needs_hm_restart=1
    fixed "$path ownership repaired"
  else
    bad "$path holds entries not owned by $me"
  fi
}
if [ "$have_sudo" = 1 ]; then
  own "$home/.config"
  own "$home/.local"
  own "$home/.ssh"
  own "$repo"
else
  warn "ownership not checked (needs root)"
fi

# --- 5. home-manager ---------------------------------------------------------
# Its activation is what creates ~/.ssh/config, ~/.config/*, ~/.agents and the
# user profile; a root-owned .config makes it fail with mkdir: Permission denied
# and the home looks empty without any unit being "failed" in a visible way.
hm_unit="home-manager-$me.service"
if [ "$needs_hm_restart" = 1 ] && can_fix; then
  sudo -n systemctl restart "$hm_unit" >/dev/null 2>&1 || true
fi
if systemctl is-active --quiet "$hm_unit"; then
  ok "$hm_unit active"
elif can_fix && sudo -n systemctl restart "$hm_unit" >/dev/null 2>&1 &&
  systemctl is-active --quiet "$hm_unit"; then
  fixed "$hm_unit restarted"
else
  bad "$hm_unit not active — see: journalctl -u $hm_unit -n 40"
fi

# A dangling home-manager symlink is the signature of a half-applied activation.
dangling=$(find "$home" -maxdepth 3 -xtype l 2>/dev/null |
  grep -vE "/(\.nix-profile|\.nix-defexpr/[^/]+)$" | head -5)
if [ -z "$dangling" ]; then
  ok "no dangling managed symlinks"
elif can_fix; then
  sudo -n systemctl restart "$hm_unit" >/dev/null 2>&1 || true
  if [ -z "$(find "$home" -maxdepth 3 -xtype l 2>/dev/null |
    grep -vE "/(\.nix-profile|\.nix-defexpr/[^/]+)$" | head -5)" ]; then
    fixed "dangling managed symlinks repaired by $hm_unit"
  else
    bad "dangling symlinks remain: $(echo "$dangling" | tr '\n' ' ')"
  fi
else
  bad "dangling symlinks: $(echo "$dangling" | tr '\n' ' ')"
fi

# --- 6. authorized keys ------------------------------------------------------
# These are written at *user creation*, not on every activation, so a host whose
# user record was re-applied after a broken boot can end up with an empty .ssh
# while the declaration still lists 24 keys.
keys_decl=""
if [ -d "$repo" ]; then
  keys_decl=$(nix eval --json "$repo?submodules=1#nixosConfigurations.$(hostname -s).config.users.users.$me.openssh.authorizedKeys.keys" 2>/dev/null |
    jq -r '.[]' 2>/dev/null || true)
fi
if [ -z "$keys_decl" ]; then
  warn "authorized_keys not checkable (no declared keys for $(hostname -s)/$me on disk)"
else
  want=$(printf '%s\n' "$keys_decl")
  got=$(cat "$home/.ssh/authorized_keys" 2>/dev/null || true)
  if [ "$want" = "$got" ]; then
    ok "authorized_keys matches the declaration"
  elif can_fix && printf '%s\n' "$want" | sudo -n install -d -m 700 -o "$me" -g "$group" "$home/.ssh" &&
    printf '%s\n' "$want" | sudo -n install -m 600 -o "$me" -g "$group" /dev/stdin "$home/.ssh/authorized_keys"; then
    fixed "authorized_keys rewritten from the flake ($(printf '%s\n' "$want" | wc -l | tr -d ' ') keys)"
  else
    bad "authorized_keys differs from the declaration"
  fi
fi

# --- 7. vault ----------------------------------------------------------------
# A reseeded host comes up with an empty ~/vaults unless something clones it;
# "the vault is missing" then reads like data loss rather than a missing clone.
if [ -d "$home/vaults/personal/.git" ]; then
  ok "vault cloned ($(git -C "$home/vaults/personal" rev-parse --short HEAD 2>/dev/null))"
elif can_fix && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  mkdir -p "$home/vaults"
  if gh repo clone shaoyanji/Obsidian-Git-Sync "$home/vaults/personal" -- --quiet; then
    fixed "vault cloned into ~/vaults/personal"
  else
    bad "vault clone failed"
  fi
else
  bad "vault missing at ~/vaults/personal and gh is not authenticated"
fi

# --- 8. shell history sync ---------------------------------------------------
# atuin's session is runtime state too: after a home rebuild the key file is
# there, the database is empty and `atuin status` says "not logged in".
if command -v atuin >/dev/null 2>&1; then
  if atuin status >/dev/null 2>&1; then
    ok "atuin logged in to its sync server"
  elif can_fix && [ -f "$repo/.agents/skills/atuin/scripts/atuin-bootstrap.sh" ]; then
    if NIXCONFIG=$repo bash "$repo/.agents/skills/atuin/scripts/atuin-bootstrap.sh" >/tmp/host-restore-atuin.log 2>&1 &&
      atuin status >/dev/null 2>&1; then
      fixed "atuin logged in and synced ($(sqlite3 "$home/.local/share/atuin/history.db" 'select count(*) from history' 2>/dev/null) items)"
    else
      bad "atuin login failed — see /tmp/host-restore-atuin.log"
    fi
  else
    bad "atuin not logged in"
  fi
else
  warn "atuin not installed"
fi

# --- 9. tailnet mounts -------------------------------------------------------
# `After=tailscaled.service` is ordering, not readiness: the serve command exits
# 1 once while the backend is NoState and the unit never retries, so the mounts
# are down while every process behind them is up.
if systemctl list-unit-files 'tailscale-serve-*.service' --no-legend 2>/dev/null | grep -q .; then
  inactive=0
  for unit in $(systemctl list-units --all 'tailscale-serve-*.service' --no-legend --plain 2>/dev/null | awk '{print $1}'); do
    systemctl is-active --quiet "$unit" && continue
    inactive=$((inactive + 1))
    if can_fix && sudo -n systemctl restart "$unit" >/dev/null 2>&1 &&
      systemctl is-active --quiet "$unit"; then
      fixed "$unit restarted"
    else
      bad "$unit not active"
    fi
  done
  [ "$inactive" = 0 ] && ok "all tailscale-serve mounts active"
else
  ok "no tailnet mounts declared"
fi

# --- 10. failed units --------------------------------------------------------
sys_failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk 'NF {print $1}')
user_failed=$(systemctl --user --failed --no-legend --plain 2>/dev/null | awk 'NF {print $1}')
if [ -z "$sys_failed" ] && [ -z "$user_failed" ]; then
  ok "no failed units (system and user)"
else
  [ -n "$sys_failed" ] && bad "failed system units: $(echo "$sys_failed" | tr '\n' ' ')"
  [ -n "$user_failed" ] && bad "failed user units: $(echo "$user_failed" | tr '\n' ' ')"
fi

# --- 11. pending activation --------------------------------------------------
# Not a failure: the running generation can legitimately be one behind the boot
# entry. Reported because "repaired but not yet active" is easy to mistake for
# "not repaired".
running=$(readlink -f /run/current-system 2>/dev/null || true)
# `sudo` starts with secure_path, which does not include the system profile on
# this fleet — an absolute path is the difference between a real answer and
# "boot entry not readable". And the text output wraps an entry over several
# lines, so the default entry's `init=` is not on its `(default)` line; the JSON
# surface names the entry directly.
bootctl=/run/current-system/sw/bin/bootctl
[ -x "$bootctl" ] || bootctl=$(command -v bootctl || true)
pending=""
if [ -n "$bootctl" ]; then
  pending=$(sudo -n "$bootctl" list --json=short 2>/dev/null |
    jq -r '[.[] | select(.isDefault == true) | .options] | .[0] // ""' 2>/dev/null |
    grep -oE 'init=[^ ]+' | sed 's|^init=||; s|/init$||' || true)
fi
if [ -z "$pending" ]; then
  warn "boot entry not readable — skipping generation check"
elif [ "$running" = "$pending" ]; then
  ok "running generation is the boot entry"
else
  warn "boot entry is one ahead — reboot to activate $pending"
fi

# --- summary -----------------------------------------------------------------
printf '\nhost-restore: %d fixed, %d remaining\n' "$fixes" "$fails"
if [ "$fails" -gt 0 ]; then
  [ "$have_sudo" = 1 ] || exit 2
  exit 1
fi
exit 0
