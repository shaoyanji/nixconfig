#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/../../taskfiles/site-manifest.json"

usage() {
  cat <<'USAGE'
Usage: site-target.sh <command> [target]
Commands:
  list                 List site targets from manifest
  show [target]        Show target metadata (default target when omitted)
  build [target]       Run build command for target (default target when omitted)
  preview [target]     Build then serve output path locally (default target when omitted)
  deploy [target]      Build then deploy output path (default target when omitted)
USAGE
}

error() {
  echo "site-target: $*" >&2
}

require_dependencies() {
  command -v jq >/dev/null
}

default_target() {
  jq -r '.defaultTarget // empty' "$MANIFEST"
}

resolve_target() {
  local maybe_target="${1:-}"
  if [ -n "$maybe_target" ]; then
    printf '%s\n' "$maybe_target"
    return
  fi
  local target
  target="$(default_target)"
  if [ -z "$target" ]; then
    error "Manifest has no defaultTarget"
    exit 1
  fi
  printf '%s\n' "$target"
}

require_target() {
  local target="$1"
  if ! jq -e --arg target "$target" '.targets[$target]' "$MANIFEST" >/dev/null; then
    error "Unknown target '$target'"
    exit 1
  fi
}

target_field() {
  local target="$1"
  local field="$2"
  jq -r --arg target "$target" --arg field "$field" '.targets[$target][$field] // empty' "$MANIFEST"
}

run_build() {
  local target="$1"
  local build_command
  build_command="$(target_field "$target" "buildCommand")"
  if [ -z "$build_command" ]; then
    error "Target '$target' is missing buildCommand"
    exit 1
  fi
  echo "Building target '$target' with: $build_command"
  bash -lc "$build_command"
}

run_preview() {
  local target="$1"
  run_build "$target"
  local output_path preview_port preview_bind
  output_path="$(target_field "$target" "outputPath")"
  preview_port="$(target_field "$target" "previewPort")"
  preview_bind="$(target_field "$target" "previewBind")"
  if [ -z "$output_path" ]; then
    error "Target '$target' is missing outputPath"
    exit 1
  fi
  if [ -z "$preview_port" ]; then
    preview_port="8000"
  fi
  if [ -z "$preview_bind" ]; then
    preview_bind="127.0.0.1"
  fi
  echo "Previewing '$target' from '$output_path' at http://$preview_bind:$preview_port"
  python3 -m http.server "$preview_port" --bind "$preview_bind" --directory "$output_path"
}

run_deploy() {
  local target="$1"
  run_build "$target"
  local output_path deploy_method deploy_target
  output_path="$(target_field "$target" "outputPath")"
  deploy_method="$(target_field "$target" "deployMethod")"
  deploy_target="$(target_field "$target" "deployTarget")"
  if [ -z "$output_path" ]; then
    error "Target '$target' is missing outputPath"
    exit 1
  fi
  if [ -z "$deploy_method" ]; then
    error "Target '$target' is missing deployMethod"
    exit 1
  fi
  if [ -z "$deploy_target" ]; then
    error "Target '$target' is missing deployTarget"
    exit 1
  fi

  case "$deploy_method" in
    rsync)
      echo "Deploying '$target' with rsync to '$deploy_target' from '$output_path/'"
      rsync -av --delete "$output_path"/ "$deploy_target"
      ;;
    *)
      error "Unsupported deployMethod '$deploy_method' for target '$target'"
      exit 1
      ;;
  esac
}

show_target() {
  local target="$1"
  local kind description build_command output_path deploy_method deploy_target preview_port preview_bind
  kind="$(target_field "$target" "kind")"
  description="$(target_field "$target" "description")"
  build_command="$(target_field "$target" "buildCommand")"
  output_path="$(target_field "$target" "outputPath")"
  deploy_method="$(target_field "$target" "deployMethod")"
  deploy_target="$(target_field "$target" "deployTarget")"
  preview_port="$(target_field "$target" "previewPort")"
  preview_bind="$(target_field "$target" "previewBind")"

  echo "Target: $target"
  echo "  Kind: ${kind:-"(none)"}"
  echo "  Description: ${description:-"(none)"}"
  echo "  Build command: ${build_command:-"(none)"}"
  echo "  Output path: ${output_path:-"(none)"}"
  echo "  Deploy method: ${deploy_method:-"(none)"}"
  echo "  Deploy target: ${deploy_target:-"(none)"}"
  echo "  Preview bind: ${preview_bind:-"127.0.0.1"}"
  echo "  Preview port: ${preview_port:-"8000"}"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

require_dependencies
if [ ! -f "$MANIFEST" ]; then
  error "Manifest not found at $MANIFEST"
  exit 1
fi
jq -e '.targets | type == "object"' "$MANIFEST" >/dev/null

cmd="$1"
shift

case "$cmd" in
  list)
    default="$(default_target)"
    jq -r '.targets | to_entries[] | [.key, (.value.kind // "(none)"), (.value.description // "(none)")] | @tsv' "$MANIFEST" \
      | sort \
      | while IFS=$'\t' read -r target kind description; do
        if [ "$target" = "$default" ]; then
          printf '* %-16s kind=%-12s %s\n' "$target" "$kind" "$description"
        else
          printf '  %-16s kind=%-12s %s\n' "$target" "$kind" "$description"
        fi
      done
    ;;
  show)
    target="$(resolve_target "${1:-}")"
    require_target "$target"
    show_target "$target"
    ;;
  build)
    target="$(resolve_target "${1:-}")"
    require_target "$target"
    run_build "$target"
    ;;
  preview)
    target="$(resolve_target "${1:-}")"
    require_target "$target"
    run_preview "$target"
    ;;
  deploy)
    target="$(resolve_target "${1:-}")"
    require_target "$target"
    run_deploy "$target"
    ;;
  *)
    error "Unknown command '$cmd'"
    usage
    exit 1
    ;;
esac
