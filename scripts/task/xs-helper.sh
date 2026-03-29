#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEFAULT_LOCAL_ROOT="${HOME}/.local/share/xs-helper"
_local_root_candidate="${XS_HELPER_LOCAL_ROOT:-$DEFAULT_LOCAL_ROOT}"
if mkdir -p "$_local_root_candidate" >/dev/null 2>&1; then
  LOCAL_ROOT="$_local_root_candidate"
else
  LOCAL_ROOT="${REPO_ROOT}/.cache/xs-helper"
  mkdir -p "$LOCAL_ROOT"
fi
unset _local_root_candidate
LOCAL_STORE="${LOCAL_ROOT}/store"
LOCAL_CAS="${LOCAL_ROOT}/cas"
LOCAL_SERVER_LOG="${LOCAL_ROOT}/xs-serve.log"

SERVICE_STORE_PATH="${XS_HELPER_SERVICE_STORE_PATH:-/var/lib/xs/store}"
SERVICE_ADDR="${XS_HELPER_SERVICE_ADDR:-$SERVICE_STORE_PATH}"

PRODUCER="${XS_HELPER_PRODUCER:-xs-helper}"
XS_BIN="${XS_BIN:-xs}"
if ! command -v "$XS_BIN" >/dev/null 2>&1 && [ -x "$REPO_ROOT/result/bin/xs" ]; then
  XS_BIN="$REPO_ROOT/result/bin/xs"
fi

MODE="local"
STORE_OVERRIDE=""
CAS_OVERRIDE=""
ADDR_OVERRIDE=""
COMMAND=""

usage() {
  cat <<'EOF'
Usage: xs-helper [GLOBAL OPTIONS] <command> [args]

Global options:
  --service               target the service-owned store (/var/lib/xs by default)
  --store <path>          override the xs store/address path
  --cas   <path>          override where artifacts are promoted
  --addr  <path>          override the unix address used to reach xs
  --help

Env overrides:
  XS_HELPER_LOCAL_ROOT       local helpers root (default "${HOME}/.local/share/xs-helper")
  XS_HELPER_SERVICE_STORE_PATH
  XS_HELPER_SERVICE_ADDR
  XS_HELPER_PRODUCER
  XS_BIN                     path to an xs binary (fallbacks to "xs" and repo result)

Commands:
  status                   show mode, paths, and whether xs is reachable
  logs [topic]             tail a limited slice of recent events, optionally filtered by topic
  topics                   list the most recent active topics
  show <topic>             render recent frames for a topic
  tail <topic>             follow a topic stream
  start <topic>            emit a run.started frame
  artifact <topic> <file> [label]
                           hash and promote a file, emit an artifact.ready frame
  packet <topic> <artifact-id> <type> <text>
                           create a packet.emit event from the given artifact
EOF
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

normalize_topic() {
  local input="$1"
  local normalized
  normalized="${input,,}"
  normalized="${normalized// /-}"
  normalized="$(printf '%s' "$normalized" | tr -c '[:alnum:]._:-' '-')"
  while [[ "$normalized" == *--* ]]; do
    normalized="${normalized//--/-}"
  done
  normalized="${normalized#-}"
  normalized="${normalized%-}"
  normalized="${normalized#.}"
  normalized="${normalized%.}"
  if [[ -z "$normalized" ]]; then
    normalized="unnamed-topic"
  fi
  printf '%s' "$normalized"
}

timestamp_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

generate_id() {
  if "$XS_BIN" scru128 >/dev/null 2>&1; then
    "$XS_BIN" scru128
  else
    date +"%s%N"
  fi
}

resolve_store() {
  local store
  if [[ "$MODE" == "service" ]]; then
    store="${STORE_OVERRIDE:-$SERVICE_STORE_PATH}"
  else
    store="${STORE_OVERRIDE:-$LOCAL_STORE}"
  fi
  printf '%s' "$store"
}

resolve_cas() {
  if [[ -n "$CAS_OVERRIDE" ]]; then
    printf '%s' "$CAS_OVERRIDE"
    return
  fi
  printf '%s' "$LOCAL_CAS"
}

resolve_addr() {
  if [[ -n "$ADDR_OVERRIDE" ]]; then
    printf '%s' "$ADDR_OVERRIDE"
    return
  fi
  local base
  if [[ "$MODE" == "service" ]]; then
    base="${SERVICE_ADDR%/}"
  else
    base="$(resolve_store)"
  fi
  if [[ "$base" == */sock ]]; then
    printf '%s' "$base"
  else
    printf '%s' "${base%/}/sock"
  fi
}

prepare_local_dirs() {
  if [[ "$MODE" == "service" ]]; then
    return
  fi
  mkdir -p "$(resolve_store)" "$(resolve_cas)"
}

ensure_xs() {
  if ! command -v "$XS_BIN" >/dev/null 2>&1; then
    fail "xs binary '$XS_BIN' not found; set XS_BIN or install xs."
  fi
}

wait_for_xs() {
  local addr="$1"
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if "$XS_BIN" version "$addr" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  return 1
}

ensure_local_server() {
  if [[ "$MODE" == "service" || -n "$ADDR_OVERRIDE" ]]; then
    return
  fi
  local store
  store="$(resolve_store)"
  local addr
  addr="$(resolve_addr)"
  mkdir -p "$store" "$(resolve_cas)"
  if "$XS_BIN" version "$addr" >/dev/null 2>&1; then
    return
  fi
  rm -f "$addr"
  setsid -f "$XS_BIN" serve "$store" >>"$LOCAL_SERVER_LOG" 2>&1
  wait_for_xs "$addr" || fail "failed to start xs for local store at $store"
}

append_event() {
  local topic="$1"
  local body="$2"
  local meta="$3"
  if [[ -n "$meta" ]]; then
    printf '%s\n' "$body" | "$XS_BIN" append "$(resolve_addr)" "$topic" --meta "$meta"
  else
    printf '%s\n' "$body" | "$XS_BIN" append "$(resolve_addr)" "$topic"
  fi
}

pretty_events() {
  local addr="$1"
  local pretty_script
  pretty_script="$(cat <<'PY'
import json
import os
import subprocess
import sys

ADDR = os.environ["XS_HELPER_PRETTY_ADDR"]
XS_BIN = os.environ["XS_HELPER_PRETTY_BIN"]

def fetch_hash_payload(hash_value):
    if not hash_value:
        return None
    try:
        result = subprocess.run(
            [XS_BIN, "cas", ADDR, hash_value],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError:
        return None
    text = result.stdout.strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {"value": text}

def extract_payload(obj):
    if isinstance(obj, str):
        try:
            return json.loads(obj)
        except json.JSONDecodeError:
            return {"value": obj}
    if isinstance(obj, dict):
        if "kind" in obj:
            return obj
        hash_payload = fetch_hash_payload(obj.get("hash"))
        if hash_payload is not None:
            return extract_payload(hash_payload)
        if "content" in obj:
            return extract_payload(obj["content"])
        if "payload" in obj:
            return extract_payload(obj["payload"])
        if "body" in obj:
            return extract_payload(obj["body"])
        if "data" in obj:
            return extract_payload(obj["data"])
        return obj
    return {}

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        frame = json.loads(line)
    except json.JSONDecodeError:
        print(line)
        continue
    if not isinstance(frame, dict):
        continue
    meta = frame.get("meta")
    if not isinstance(meta, dict):
        meta = {}
    frame_meta = frame.get("frame")
    if not isinstance(frame_meta, dict):
        frame_meta = {}
    topic = frame.get("topic") or meta.get("topic") or frame_meta.get("topic") or "unknown"
    payload = extract_payload(frame)
    if not isinstance(payload, dict):
        payload = {"value": str(payload)}
    kind = payload.get("kind") or meta.get("type") or frame.get("kind") or topic
    ts = payload.get("timestamp") or payload.get("ts") or frame.get("timestamp") or frame.get("ts") or frame.get("id", "")
    labels = []
    for key in ("artifact_id", "packet_id", "packet_type", "source_artifact_id", "run_id", "label"):
        if key in payload:
            labels.append(f"{key}={payload[key]}")
    if "content" in payload and isinstance(payload["content"], str):
        labels.append(f"content={payload['content']}")
    elif "value" in payload and isinstance(payload["value"], str):
        labels.append(f"value={payload['value']}")
    summary = f"{kind} {' '.join(labels)}".strip()
    print(f"{ts:<24} {topic:<30} {summary}")
PY
)"
  XS_HELPER_PRETTY_ADDR="$addr" XS_HELPER_PRETTY_BIN="$XS_BIN" python3 -u -c "$pretty_script"
}

command_status() {
  printf 'mode: %s\n' "$MODE"
  printf 'store: %s\n' "$(resolve_store)"
  printf 'cas: %s\n' "$(resolve_cas)"
  printf 'producer: %s\n' "$PRODUCER"
  local addr
  addr="$(resolve_addr)"
  printf 'addr: %s\n' "$addr"
  if [[ "$MODE" == "local" ]]; then
    printf 'server_log: %s\n' "$LOCAL_SERVER_LOG"
  fi
  if command -v "$XS_BIN" >/dev/null 2>&1; then
    if "$XS_BIN" version "$addr" >/dev/null 2>&1; then
      printf 'xs: reachable\n'
    else
      printf 'xs: unreachable (address=%s)\n' "$addr"
    fi
  else
    printf 'xs: missing (%s)\n' "$XS_BIN"
  fi
}

command_logs() {
  ensure_xs
  ensure_local_server
  local topic=""
  if [[ $# -gt 0 ]]; then
    topic="$(normalize_topic "$1")"
    shift
  fi
  local limit=40
  if [[ $# -gt 0 ]]; then
    limit="$1"
  fi
  local args=("$(resolve_addr)" "--last" "$limit")
  if [[ -n "$topic" ]]; then
    args+=("--topic" "$topic")
  fi
  "$XS_BIN" cat "${args[@]}" | pretty_events "$(resolve_addr)"
}

command_topics() {
  ensure_xs
  ensure_local_server
  local topics_script
  topics_script="$(cat <<'PY'
import json
import sys

seen = set()
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        frame = json.loads(line)
    except json.JSONDecodeError:
        continue
    if not isinstance(frame, dict):
        continue
    meta = frame.get("meta")
    if not isinstance(meta, dict):
        meta = {}
    frame_meta = frame.get("frame")
    if not isinstance(frame_meta, dict):
        frame_meta = {}
    topic = frame.get("topic") or meta.get("topic") or frame_meta.get("topic")
    if topic:
        seen.add(topic)
for topic in sorted(seen):
    print(topic)
PY
)"
  "$XS_BIN" cat "$(resolve_addr)" --last 200 | python3 -c "$topics_script"
}

command_show() {
  ensure_xs
  ensure_local_server
  [[ $# -ge 1 ]] || fail 'show requires a topic'
  local topic="$(normalize_topic "$1")"
  "$XS_BIN" cat "$(resolve_addr)" --topic "$topic" --last 50 | pretty_events "$(resolve_addr)"
}

command_tail() {
  ensure_xs
  ensure_local_server
  [[ $# -ge 1 ]] || fail 'tail requires a topic'
  local topic="$(normalize_topic "$1")"
  "$XS_BIN" cat "$(resolve_addr)" --topic "$topic" --follow | pretty_events "$(resolve_addr)"
}

command_start() {
  ensure_xs
  ensure_local_server
  [[ $# -ge 1 ]] || fail 'start requires a topic'
  local topic
  topic="$(normalize_topic "$1")"
  local run_id
  run_id="$(generate_id)"
  local event
  event=$(XS_EVENT_TOPIC="$topic" \
          XS_EVENT_RUN_ID="$run_id" \
          XS_EVENT_PRODUCER="$PRODUCER" \
          XS_EVENT_TIMESTAMP="$(timestamp_iso)" \
          python3 - <<'PY'
import json,os
env = os.environ
payload = {
    "kind": "run.started",
    "topic": env["XS_EVENT_TOPIC"],
    "run_id": env["XS_EVENT_RUN_ID"],
    "producer": env["XS_EVENT_PRODUCER"],
    "timestamp": env["XS_EVENT_TIMESTAMP"],
}
print(json.dumps(payload))
PY
)
  append_event "$topic" "$event" "{\"producer\":\"$PRODUCER\",\"type\":\"run.started\"}"
  printf 'run.started emitted for %s (run_id=%s)\n' "$topic" "$run_id"
}

command_artifact() {
  ensure_xs
  ensure_local_server
  [[ $# -ge 2 ]] || fail 'artifact requires <topic> <file> [label]'
  local topic
  topic="$(normalize_topic "$1")"
  shift
  local file_path
  file_path="$1"
  local label
  label="${2:-$(basename "$file_path")}"
  [[ -f "$file_path" ]] || fail "file not found: $file_path"
  local sha256
  sha256="$(sha256sum -- "$file_path" | awk '{print $1}')"
  local subdir
  subdir="${sha256:0:2}"
  local cas_root
  cas_root="$(resolve_cas)"
  local cas_dir
  cas_dir="$cas_root/$subdir"
  mkdir -p "$cas_dir"
  local cas_file
  cas_file="$cas_dir/$sha256"
  if [[ ! -f "$cas_file" ]]; then
    cp -- "$file_path" "$cas_file"
  fi
  local artifact_id
  artifact_id="$(generate_id)"
  local mime
  mime="application/octet-stream"
  if command -v file >/dev/null 2>&1; then
    mime="$(file --brief --mime-type -- "$file_path")"
  fi
  local event
  event=$(XS_EVENT_TOPIC="$topic" \
          XS_EVENT_ARTIFACT_ID="$artifact_id" \
          XS_EVENT_LABEL="$label" \
          XS_EVENT_MIME="$mime" \
          XS_EVENT_CAS="$cas_file" \
          XS_EVENT_SHA="$sha256" \
          XS_EVENT_PRODUCER="$PRODUCER" \
          XS_EVENT_TIMESTAMP="$(timestamp_iso)" \
          python3 - <<'PY'
import json,os
env = os.environ
payload = {
    "kind": "artifact.ready",
    "topic": env["XS_EVENT_TOPIC"],
    "artifact_id": env["XS_EVENT_ARTIFACT_ID"],
    "label": env["XS_EVENT_LABEL"],
    "mime": env["XS_EVENT_MIME"],
    "cas_path": env["XS_EVENT_CAS"],
    "sha256": env["XS_EVENT_SHA"],
    "producer": env["XS_EVENT_PRODUCER"],
    "timestamp": env["XS_EVENT_TIMESTAMP"],
}
print(json.dumps(payload))
PY
)
  append_event "$topic" "$event" "{\"producer\":\"$PRODUCER\",\"type\":\"artifact.ready\"}"
  printf 'artifact.ready emitted for %s (artifact_id=%s, cas=%s)\n' "$topic" "$artifact_id" "$cas_file"
}

command_packet() {
  ensure_xs
  ensure_local_server
  (( $# >= 4 )) || fail 'packet requires <topic> <artifact-id> <type> <text>'
  local topic
  topic="$(normalize_topic "$1")"
  local artifact_id
  artifact_id="$2"
  local packet_type
  packet_type="$3"
  shift 3
  local content
  content="$*"
  [[ -n "$content" ]] || fail 'packet text cannot be empty'
  local packet_id
  packet_id="$(generate_id)"
  local event
  event=$(XS_EVENT_TOPIC="$topic" \
          XS_EVENT_PACKET_ID="$packet_id" \
          XS_EVENT_PACKET_TYPE="$packet_type" \
          XS_EVENT_ARTIFACT_SOURCE="$artifact_id" \
          XS_EVENT_CONTENT="$content" \
          XS_EVENT_PRODUCER="$PRODUCER" \
          XS_EVENT_TIMESTAMP="$(timestamp_iso)" \
          python3 - <<'PY'
import json,os
env = os.environ
payload = {
    "kind": "packet.emit",
    "topic": env["XS_EVENT_TOPIC"],
    "packet_id": env["XS_EVENT_PACKET_ID"],
    "packet_type": env["XS_EVENT_PACKET_TYPE"],
    "source_artifact_id": env["XS_EVENT_ARTIFACT_SOURCE"],
    "content": env["XS_EVENT_CONTENT"],
    "producer": env["XS_EVENT_PRODUCER"],
    "timestamp": env["XS_EVENT_TIMESTAMP"],
}
print(json.dumps(payload))
PY
)
  append_event "$topic" "$event" "{\"producer\":\"$PRODUCER\",\"type\":\"packet.emit\"}"
  printf 'packet.emit emitted for %s (packet_id=%s)\n' "$topic" "$packet_id"
}

[[ $# -eq 0 ]] && usage && exit 0

while [[ $# -gt 0 ]]; do
  case $1 in
    --service)
      MODE="service"
      shift
      ;;
    --store)
      STORE_OVERRIDE="$2"
      shift 2
      ;;
    --cas)
      CAS_OVERRIDE="$2"
      shift 2
      ;;
    --addr)
      ADDR_OVERRIDE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      COMMAND="$1"
      shift
      break
      ;;
  esac
done

prepare_local_dirs

case "$COMMAND" in
  status)
    command_status
    ;;
  logs)
    command_logs "$@"
    ;;
  topics)
    command_topics
    ;;
  show)
    command_show "$@"
    ;;
  tail)
    command_tail "$@"
    ;;
  start)
    command_start "$@"
    ;;
  artifact)
    command_artifact "$@"
    ;;
  packet)
    command_packet "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
