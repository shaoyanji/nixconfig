#!/usr/bin/env bash
# shellcheck shell=bash
# One CLI for the self-hosted decision engine: POST /v1/systemone, or probe it.
# The engine is `services.systemoneDecision.serve` (delphi serves it on 8444);
# `systemone-decision` prints the local equivalent. This wrapper exists so a
# skill does not carry curl invocations.
set -euo pipefail

ENDPOINT="${SYSTEMONE_URL:-http://127.0.0.1:8091}"
STATE=""
QUESTIONS=""
MODEL=""
MODE="decide"

usage() {
  cat <<'USAGE'
systemone — ask the self-hosted decision engine

  -e, --endpoint URL   http(s) root (default $SYSTEMONE_URL or loopback:8091)
  -s, --state S        state as text, @file, or - for stdin
  -q, --questions J    questions JSON {id:{type,instructions,criteria}}, @file, or -
  -m, --model NAME     model to answer with (engine default when omitted)
      --health         GET /health; exit 1 when unreachable
  -h, --help           this text

Envelope: {"state": …, "questions": {…}} -> {"answers": {…}, "usage": {…}}
USAGE
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "systemone: missing $1" >&2; exit 2; }; }

expand() {
  case "$1" in
    @*) [ -r "${1#@}" ] || { echo "systemone: cannot read ${1#@}" >&2; exit 2; }; cat "${1#@}" ;;
    -)  cat ;;
    *)  printf '%s' "$1" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    -e|--endpoint) ENDPOINT="$2"; shift 2 ;;
    -s|--state) STATE="$2"; shift 2 ;;
    -q|--questions) QUESTIONS="$2"; shift 2 ;;
    -m|--model) MODEL="$2"; shift 2 ;;
    --health) MODE="health"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "systemone: unknown argument $1" >&2; usage >&2; exit 2 ;;
  esac
done

need curl
ENDPOINT="${ENDPOINT%/}"

if [ "$MODE" = "health" ]; then
  curl -fsS --max-time 10 "$ENDPOINT/health"
  echo
  exit 0
fi

need jq
[ -n "$QUESTIONS" ] || { echo "systemone: --questions is required" >&2; exit 2; }
[ -n "$STATE" ] || { echo "systemone: --state is required" >&2; exit 2; }

questions="$(expand "$QUESTIONS")"
echo "$questions" | jq -e 'type == "object"' >/dev/null \
  || { echo "systemone: --questions must be a JSON object" >&2; exit 2; }

body="$(jq -n --arg state "$(expand "$STATE")" --argjson questions "$questions" \
  --arg model "$MODEL" '{state: $state, questions: $questions} + (if $model == "" then {} else {model: $model} end)')"

answer="$(curl -fsS --max-time 120 -H 'content-type: application/json' \
  -d "$body" "$ENDPOINT/v1/systemone")" \
  || { echo "systemone: no answer from $ENDPOINT/v1/systemone" >&2; exit 1; }

printf '%s\n' "$answer" | jq .
