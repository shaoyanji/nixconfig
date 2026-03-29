#!/usr/bin/env bash
set -euo pipefail

mode="${1:-post-create}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
workspace_root="${BOOTSTRAP_WORKSPACE_ROOT:-${CODESPACE_VSCODE_FOLDER:-${repo_root}}}"
bootstrap_home="${BOOTSTRAP_HOME:-${HOME}}"
skip_nix="${BOOTSTRAP_SKIP_NIX:-0}"

managed_begin="# >>> nixconfig devcontainer >>>"
managed_end="# <<< nixconfig devcontainer <<<"

log() {
  printf '[nixconfig bootstrap] %s\n' "$*"
}

strip_managed_block() {
  local file="$1"

  if [ ! -f "${file}" ]; then
    return 0
  fi

  awk -v begin="${managed_begin}" -v end="${managed_end}" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "${file}"
}

ensure_managed_block() {
  local file="$1"
  local temp_file

  mkdir -p "$(dirname -- "${file}")"
  temp_file="$(mktemp)"

  strip_managed_block "${file}" > "${temp_file}"

  if [ -s "${temp_file}" ]; then
    printf '\n' >> "${temp_file}"
  fi

  cat >> "${temp_file}" <<EOF
${managed_begin}
if [ -s "${bootstrap_home}/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "${bootstrap_home}/.nix-profile/etc/profile.d/nix.sh"
fi
if command -v direnv >/dev/null 2>&1; then
  eval "\$(direnv hook bash)"
fi
${managed_end}
EOF

  mv "${temp_file}" "${file}"
}

ensure_nix_config() {
  local nix_conf_dir="${bootstrap_home}/.config/nix"
  local nix_conf_file="${nix_conf_dir}/nix.conf"

  mkdir -p "${nix_conf_dir}"
  cat > "${nix_conf_file}" <<'EOF'
experimental-features = nix-command flakes
accept-flake-config = true
EOF
}

allow_direnv() {
  if [ -f "${workspace_root}/.envrc" ] && command -v direnv >/dev/null 2>&1; then
    direnv allow "${workspace_root}"
  fi
}

warm_dev_shell() {
  if [ "${skip_nix}" = "1" ]; then
    log "Skipping nix develop warmup because BOOTSTRAP_SKIP_NIX=1"
    return 0
  fi

  if [ -s "${bootstrap_home}/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck disable=SC1090
    . "${bootstrap_home}/.nix-profile/etc/profile.d/nix.sh"
  fi

  if ! command -v nix >/dev/null 2>&1; then
    log "Skipping nix develop warmup because nix is not available yet"
    return 0
  fi

  nix develop "${workspace_root}" -c true
}

validate_only() {
  [ -f "${repo_root}/.devcontainer/devcontainer.json" ]
  [ -f "${repo_root}/.devcontainer/Dockerfile" ]
  [ -f "${repo_root}/.devcontainer/bootstrap.sh" ]
  [ -f "${workspace_root}/.envrc" ]
  log "Validation checks passed"
}

case "${mode}" in
  post-create|post-start)
    ensure_nix_config
    ensure_managed_block "${bootstrap_home}/.bashrc"
    ensure_managed_block "${bootstrap_home}/.profile"
    allow_direnv
    warm_dev_shell
    ;;
  validate)
    validate_only
    ;;
  *)
    echo "usage: $0 [post-create|post-start|validate]" >&2
    exit 1
    ;;
esac
