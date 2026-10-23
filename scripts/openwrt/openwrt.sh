#!/usr/bin/env bash
# openwrt — control the FRITZ!Box 7320 (OpenWrt 24.10, ath9k) from a devShell.
#
# Everything lives on this side: the box keeps no repo, no package manager and
# ~3.6 MB of free flash. `install` pushes netprofile (scripts/openwrt/netprofile.sh)
# and the SSH keys; the root password is read from sops and is only a fallback
# for a lost key or a reflash.
set -euo pipefail

ROUTER="${OPENWRT_HOST:-192.168.1.1}"
ROUTER_USER="${OPENWRT_USER:-root}"
JUMP="${OPENWRT_JUMP-devji@100.66.146.18}"
CTL="${OPENWRT_CTL:-${TMPDIR:-/tmp}/openwrt-ctl-$(id -u)}"
LPORT="${OPENWRT_LOCAL_SSH_PORT:-2222}"

find_repo() {
  local dir="${OPENWRT_REPO:-$PWD}"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/modules/secrets.yaml" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

REPO="$(find_repo || true)"
SOPS_FILE="${OPENWRT_SOPS_FILE:-${REPO:+${REPO}/modules/secrets.yaml}}"
NETPROFILE_SRC=""
if [[ -n "${REPO}" && -f "${REPO}/scripts/openwrt/netprofile.sh" ]]; then
  NETPROFILE_SRC="${REPO}/scripts/openwrt/netprofile.sh"
elif [[ -n "${OPENWRT_NETPROFILE:-}" ]]; then
  NETPROFILE_SRC="${OPENWRT_NETPROFILE}"
fi

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5
  -o ControlMaster=auto -o "ControlPath=${CTL}" -o ControlPersist=10m)


usage() {
  cat <<'EOF'
usage: openwrt <command>

  status                    radio profile, interfaces, channel
  profile <name>            baseline | monitor | ap | ap-monitor   (persisted)
  capture [tcpdump args]    pcap on stdout from mon0, e.g. -c 500 > cap.pcap
  shell                     interactive root shell
  install                   push netprofile + config + rc.local hook + SSH keys
  key                       install local public keys for root
  pkg [--root] <file.ipk>...  install side-loaded packages; default dest is
                            the USB stick (--root writes flash, 3.6 MB free)
  get [--root] <pkg>...     resolve a package + its dependencies from the
                            upstream feed, download, and install it the same way
  password                  report whether the sops fallback exists (never prints it)
  set-password              hash the sops password and write it to /etc/shadow
  ssh-pass                  log in with the sops password (key lost / reflashed)
  tunnel [up|down|show]     forward 2222->ssh, 8081->LuCI, 8443->https, 1080->socks
  portal                    LuCI URL (starts the tunnel if needed)

env: OPENWRT_HOST, OPENWRT_USER, OPENWRT_JUMP, OPENWRT_REPO, OPENWRT_SOPS_FILE,
     OPENWRT_LOCAL_SSH_PORT, OPENWRT_LOCAL_HTTP_PORT, OPENWRT_PKG_DEST
EOF
}

route() {
  # A master socket left over from before a router reboot answers the mux
  # protocol but has no live connection, so every ssh would fail without ever
  # dialling. Drop it before probing.
  if [[ -S "${CTL}" ]] && ! ssh -O check -o "ControlPath=${CTL}" \
    "${ROUTER_USER}@${ROUTER}" >/dev/null 2>&1; then
    rm -f "${CTL}"
  fi
  # 8080 belongs to pihole-FTL on frieren, so LuCI gets its own local port.
  if ssh "${SSH_OPTS[@]}" -o ConnectTimeout=2 -o ProxyCommand=none \
    "${ROUTER_USER}@${ROUTER}" true 2>/dev/null; then
    printf '\n'
  elif [[ -n "${JUMP}" ]] && ssh "${SSH_OPTS[@]}" -o ConnectTimeout=10 -J "${JUMP}" \
    "${ROUTER_USER}@${ROUTER}" true 2>/dev/null; then
    printf '%s\n' "-J ${JUMP}"
  else
    echo "openwrt: cannot reach ${ROUTER} directly or via ${JUMP:-<no jump>}" >&2
    return 1
  fi
}

dial() { # <jump opts...> <ssh args...>
  local jump="$1"
  shift
  # shellcheck disable=SC2086
  ssh "${SSH_OPTS[@]}" ${jump} "$@"
}

# run <remote command...> — one ssh, jumped when the router is off-link.
# The jump host is a laptop over Tailscale, so a probe or a dial can lose a
# race; exit 255 means "never connected", which is the one case worth retrying.
run() {
  local jump rc attempt
  if [[ $# -eq 0 ]]; then
    # interactive shell: the USB paths come from /etc/profile.d on the box
    jump="$(route)" || return 1
    dial "${jump}" "${ROUTER_USER}@${ROUTER}"
    return
  fi
  for attempt in 1 2; do
    jump="$(route)" || return 1
    if dial "${jump}" "${ROUTER_USER}@${ROUTER}" "$@"; then
      return 0
    else
      rc=$?
    fi
    [[ ${rc} -eq 255 ]] || return ${rc}
    rm -f "${CTL}"
    sleep 1
  done
  return ${rc}
}

# push <local file> <remote path> — copies over stdin (no base64 on OpenWrt).
push() {
  local jump rc attempt
  for attempt in 1 2; do
    jump="$(route)" || return 1
    if dial "${jump}" "${ROUTER_USER}@${ROUTER}" "cat > $2" <"$1"; then
      return 0
    else
      rc=$?
    fi
    [[ ${rc} -eq 255 ]] || return ${rc}
    rm -f "${CTL}"
    sleep 1
  done
  return ${rc}
}

secret() {
  [[ -n "${SOPS_FILE}" && -f "${SOPS_FILE}" ]] || return 1
  sops decrypt --extract '["openwrt"]["root_password"]' "${SOPS_FILE}" 2>/dev/null
}

# sets MNT for a destination and refuses to install into an unmounted stick
require_dest() {
  case "$1" in
  usb)
    MNT=/mnt/usb
    if ! run 'grep -q " /mnt/usb " /proc/mounts'; then
      echo "openwrt: /mnt/usb is not mounted — /etc/init.d/usbstore start" >&2
      return 1
    fi
    ;;
  root) MNT=/overlay ;;
  *)
    echo "openwrt: unknown destination: $1" >&2
    return 1
    ;;
  esac
}

# install_ipks <dest> <file...> — one opkg run so the batch resolves together
install_ipks() {
  local dest="$1" f rc
  shift
  run 'rm -rf /tmp/owpkg && mkdir -p /tmp/owpkg' || return 1
  for f in "$@"; do
    push "${f}" "/tmp/owpkg/$(basename "${f}")" || return 1
  done
  if run "opkg -d ${dest} install /tmp/owpkg/*.ipk"; then rc=0; else rc=$?; fi
  run 'rm -rf /tmp/owpkg'
  # Packages land in /mnt/usb/usr; the box's PATH/loader only see them via the
  # symlinks that usbstore installs, so refresh those for the new files.
  [[ ${dest} == usb ]] && run '/etc/init.d/usbstore link' >/dev/null 2>&1
  return ${rc}
}

install_keys() {
  local keys
  keys="$(cat "${HOME}"/.ssh/*.pub 2>/dev/null || true)"
  [[ -n "${keys}" ]] || {
    echo "openwrt: no ~/.ssh/*.pub to install" >&2
    return 1
  }
  printf '%s\n' "${keys}" | run 'cat > /tmp/openwrt-keys.new
    cat /etc/dropbear/authorized_keys /tmp/openwrt-keys.new 2>/dev/null | grep -v "^[[:space:]]*$" | sort -u > /tmp/openwrt-keys.all
    mv /tmp/openwrt-keys.all /etc/dropbear/authorized_keys
    chmod 600 /etc/dropbear/authorized_keys
    rm -f /tmp/openwrt-keys.new
    echo "keys: $(wc -l < /etc/dropbear/authorized_keys) authorized"'
}

install_netprofile() {
  [[ -n "${NETPROFILE_SRC}" && -f "${NETPROFILE_SRC}" ]] || {
    echo "openwrt: netprofile source not found (set OPENWRT_REPO)" >&2
    return 1
  }
  push "${NETPROFILE_SRC}" /tmp/netprofile.new
  run 'chmod 755 /tmp/netprofile.new && mv /tmp/netprofile.new /usr/sbin/netprofile'
  if ! run 'test -f /etc/netprofile.conf'; then
    local conf
    conf="$(mktemp)"
    printf 'CHANNEL=%s\nSSID=%s\nPSK=%s\n' \
      "${OPENWRT_CHANNEL:-6}" "${OPENWRT_SSID:-pentest-7320}" \
      "${OPENWRT_PSK:-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')}" >"${conf}"
    push "${conf}" /etc/netprofile.conf
    rm -f "${conf}"
    run 'chmod 600 /etc/netprofile.conf'
  fi
  run 'grep -q netprofile /etc/rc.local || sed -i "/^exit 0/i [ -x /usr/sbin/netprofile ] && /usr/sbin/netprofile --boot >/dev/null 2>&1" /etc/rc.local'
  run 'netprofile status'
}

install_usbstore() {
  [[ -n "${REPO}" && -f "${REPO}/scripts/openwrt/usbstore.init" ]] || {
    echo "openwrt: usbstore.init not found (set OPENWRT_REPO)" >&2
    return 1
  }
  push "${REPO}/scripts/openwrt/usbstore.init" /etc/init.d/usbstore
  run 'chmod 755 /etc/init.d/usbstore && /etc/init.d/usbstore enable && /etc/init.d/usbstore start'
}

cmd="${1:-}"
shift || true
case "${cmd}" in
status) run netprofile status ;;
profile)
  [[ $# -eq 1 ]] || {
    echo "profile needs one name: baseline|monitor|ap|ap-monitor" >&2
    exit 2
  }
  run "netprofile $1"
  ;;
capture) run netprofile capture "$@" ;;
shell) run "$@" ;;
install)
  install_netprofile
  install_usbstore
  install_keys
  ;;
key) install_keys ;;
pkg)
  # Packages belong on the stick: extroot cannot work on this firmware, so the
  # flash overlay has ~3.6 MB and opkg's root dest fills it fast.
  dest="${OPENWRT_PKG_DEST:-usb}"
  files=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --root) dest=root; shift ;;
    --usb) dest=usb; shift ;;
    -*)
      echo "pkg: unknown option $1" >&2
      exit 2
      ;;
    *)
      files+=("$1")
      shift
      ;;
    esac
  done
  [[ ${#files[@]} -gt 0 ]] || {
    echo "pkg needs at least one .ipk" >&2
    exit 2
  }
  for f in "${files[@]}"; do
    [[ -f "${f}" ]] || {
      echo "pkg: no such file: ${f}" >&2
      exit 2
    }
  done
  require_dest "${dest}" || exit 1
  install_ipks "${dest}" "${files[@]}" || exit $?
  run "df -h ${MNT} | tail -1"
  ;;
get)
  dest="${OPENWRT_PKG_DEST:-usb}"
  if [[ ${1:-} == --root ]]; then
    dest=root
    shift
  fi
  [[ $# -gt 0 ]] || {
    echo "get needs at least one package name" >&2
    exit 2
  }
  [[ -n "${REPO}" && -f "${REPO}/scripts/openwrt/fetch-ipks.py" ]] || {
    echo "get: run this inside the repo (sets OPENWRT_REPO)" >&2
    exit 1
  }
  require_dest "${dest}" || exit 1
  info="$(run 'cat /etc/openwrt_release')" || exit 1
  rel="$(sed -n "s/^DISTRIB_RELEASE='\(.*\)'/\1/p" <<<"${info}")"
  tgt="$(sed -n "s/^DISTRIB_TARGET='\(.*\)'/\1/p" <<<"${info}")"
  arch="$(sed -n "s/^DISTRIB_ARCH='\(.*\)'/\1/p" <<<"${info}")"
  [[ -n "${rel}" && -n "${tgt}" && -n "${arch}" ]] || {
    echo "get: cannot parse /etc/openwrt_release" >&2
    exit 1
  }
  tmp="$(mktemp -d)"
  run 'opkg list-installed 2>/dev/null' | cut -d' ' -f1 >"${tmp}/installed"
  if ! plan="$(python3 "${REPO}/scripts/openwrt/fetch-ipks.py" \
    --release "${rel}" --target "${tgt}" --arch "${arch}" \
    --installed "${tmp}/installed" --out "${tmp}/ipk" "$@")"; then
    rm -rf "${tmp}"
    exit 1
  fi
  mapfile -t ipks <<<"${plan}"
  if [[ ${#ipks[@]} -eq 0 || -z "${ipks[0]}" ]]; then
    rm -rf "${tmp}"
    exit 0
  fi
  if install_ipks "${dest}" "${ipks[@]}"; then rc=0; else rc=$?; fi
  run "df -h ${MNT} | tail -1"
  rm -rf "${tmp}"
  exit ${rc}
  ;;
password)
  if secret >/dev/null; then
    echo "sops: openwrt.root_password present in ${SOPS_FILE}"
  else
    echo "sops: missing — add it with: task infra:secrets:edit:secrets" >&2
    echo "      openwrt:" >&2
    echo "        root_password: <router root password>" >&2
    exit 1
  fi
  ;;
set-password)
  pw="$(secret)" || {
    echo "sops: no password to apply" >&2
    exit 1
  }
  hash="$(mkpasswd -m sha-512 "${pw}")"
  case "${hash}" in
  \$6\$*) ;;
  *)
    echo "openwrt: mkpasswd produced no sha-512 hash" >&2
    exit 1
    ;;
  esac
  unset -v pw
  run "sed -i 's|^root:[^:]*:|root:${hash}:|' /etc/shadow"
  echo "box: root password now matches the sops secret"
  ;;
ssh-pass)
  askpass="$(mktemp)"
  cat >"${askpass}" <<EOF
#!/bin/sh
exec sops decrypt --extract '["openwrt"]["root_password"]' "${SOPS_FILE}"
EOF
  chmod 700 "${askpass}"
  jump="$(route)"
  # shellcheck disable=SC2086
  SSH_ASKPASS="${askpass}" SSH_ASKPASS_REQUIRE=force \
    setsid -w ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    -o NumberOfPasswordPrompts=1 "${SSH_OPTS[@]}" ${jump} \
    "${ROUTER_USER}@${ROUTER}" "${@:-echo password auth ok}"
  rm -f "${askpass}"
  ;;
tunnel)
  case "${1:-up}" in
  up)
    if (exec 3<>/dev/tcp/127.0.0.1/"${LPORT}") 2>/dev/null; then
      echo "already forwarded: ssh 127.0.0.1:${LPORT}"
      exit 0
    fi
    jump="$(route)"
    # shellcheck disable=SC2086
    ssh "${SSH_OPTS[@]}" -fN ${jump} -o ExitOnForwardFailure=yes \
      -L "127.0.0.1:${LPORT}:${ROUTER}:22" \
      -L "127.0.0.1:${OPENWRT_LOCAL_HTTP_PORT:-8081}:${ROUTER}:80" \
      -L "127.0.0.1:8443:${ROUTER}:443" \
      -D 127.0.0.1:1080 \
      "${ROUTER_USER}@${ROUTER}"
    echo "luci   http://127.0.0.1:${OPENWRT_LOCAL_HTTP_PORT:-8081}"
    echo "socks  127.0.0.1:1080"
    echo "ssh    127.0.0.1:${LPORT}"
    ;;
  down) ssh -O exit -o "ControlPath=${CTL}" "${ROUTER_USER}@${ROUTER}" 2>/dev/null || true ;;
  show) ssh -O check -o "ControlPath=${CTL}" "${ROUTER_USER}@${ROUTER}" 2>&1 || true ;;
  *)
    usage
    exit 2
    ;;
  esac
  ;;
portal)
  [[ -S "${CTL}" ]] || "$0" tunnel up >/dev/null
  echo "luci   http://127.0.0.1:${OPENWRT_LOCAL_HTTP_PORT:-8081}"
  echo "socks  127.0.0.1:1080"
  ;;
"" | -h | --help | help) usage ;;
*)
  usage
  exit 2
  ;;
esac
