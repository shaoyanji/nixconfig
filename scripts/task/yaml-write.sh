#!/usr/bin/env bash
# yaml-write.sh — mikefarah/yq v4 wrapper for safe YAML edits.
#
# Wraps `yq eval -i` with validation so callers don't need to remember yq's
# expression syntax for the common cases:
#
#   set      — set/create a scalar at a dotted path
#   append   — append an item to a list
#   insert   — insert/replace an item at a list index
#   remove   — delete a key or list element
#   eval     — raw yq expression (escape hatch)
#
# The write is atomic: `yq eval -i` rewrites the file in place, then the
# result is re-parsed to confirm it is still valid YAML.
#
# Values are passed through the YQ_VAL environment variable (strenv) so shell
# quoting can never inject into the expression.
#
# Usage:
#   yaml-write.sh set    <file> <path> <value>
#   yaml-write.sh append <file> <list-path> <value>
#   yaml-write.sh insert <file> <list-path> <index> <value>
#   yaml-write.sh remove <file> <path>
#   yaml-write.sh eval   <file> <yq-expression>
#
# Examples:
#   yaml-write.sh set config.yaml services.ha-stack.port 8451
#   yaml-write.sh append config.yaml services.ha-stack.extraPythonPackages "aiohue"
#   yaml-write.sh insert config.yaml services.ha-stack.extraPythonPackages 0 "aiohue"
#   yaml-write.sh remove config.yaml services.ha-stack.devices.zigbee2mqtt
#   yaml-write.sh eval   config.yaml '.services.postgresql.package = pkgs.postgresql_19'
set -euo pipefail

PROG="${0##*/}"

die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found on PATH (install mikefarah/yq v4)"
}

# --- argument parsing -------------------------------------------------------

[ $# -ge 2 ] || die "usage: $PROG {set|append|insert|remove|eval} <file> [args...]"

cmd="$1"; shift
file="$1"; shift

[ -f "$file" ] || die "no such file: $file"
require_cmd yq

# yq edits in place with -i; we capture any error and validate the result parses.
apply() { # yq expression
  yq eval -i -o yaml "$1" "$file" 2>/tmp/yq-err.txt \
    || { cat /tmp/yq-err.txt >&2; die "yq eval failed: $1"; }
  yq eval '.' "$file" >/dev/null 2>&1 \
    || die "resulting file is not valid YAML: $file"
}

# --- operations -------------------------------------------------------------

case "$cmd" in
  set|update)
    [ $# -eq 2 ] || die "usage: $PROG $cmd <file> <path> <value>"
    path="$1"; value="$2"
    export YQ_VAL="$value"
    apply ".${path} = strenv(YQ_VAL)"
    unset YQ_VAL
    ;;
  append)
    [ $# -eq 2 ] || die "usage: $PROG append <file> <list-path> <value>"
    path="$1"; value="$2"
    export YQ_VAL="$value"
    apply ".${path} += strenv(YQ_VAL)"
    unset YQ_VAL
    ;;
  insert)
    [ $# -eq 3 ] || die "usage: $PROG insert <file> <list-path> <index> <value>"
    path="$1"; index="$2"; value="$3"
    case "$index" in
      ''|*[!0-9]*) die "insert index must be a non-negative integer, got: $index" ;;
    esac
    export YQ_VAL="$value"
    apply ".${path}[${index}] = strenv(YQ_VAL)"
    unset YQ_VAL
    ;;
  remove)
    [ $# -eq 1 ] || die "usage: $PROG remove <file> <path>"
    path="$1"
    apply "del(.${path})"
    ;;
  eval)
    [ $# -eq 1 ] || die "usage: $PROG eval <file> <yq-expression>"
    expr="$1"
    apply "$expr"
    ;;
  *)
    die "unknown command: $cmd (set|append|insert|remove|eval)"
    ;;
esac

printf '%s: updated %s (%s)\n' "$PROG" "$file" "$cmd"
