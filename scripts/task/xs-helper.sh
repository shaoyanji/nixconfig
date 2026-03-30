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
SERVICE_USER="${XS_HELPER_SERVICE_USER:-xs}"
SERVICE_UNIT_NAME="${XS_HELPER_SERVICE_UNIT_NAME:-xs}"
SERVICE_USE_SUDO="${XS_HELPER_SERVICE_USE_SUDO:-1}"
SERVICE_ARTIFACT_SEARCH_DEPTH="${XS_HELPER_ARTIFACT_SEARCH_DEPTH:-2000}"
SERVICE_SUDO_WARNED=0

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
  raw <topic> [limit]      dump raw JSON frames for a topic (limit defaults to 200)
  start <topic>            emit a run.started frame
  artifact <topic> <file> [label]
                           hash and promote a file, emit an artifact.ready frame
  packet <topic> <artifact-id> <type> <text>
                           create a packet.emit event from the given artifact
  define-contract <topic> <file>
                           normalize and emit a contract.define event (JSON input)
  emit-record [--status fail] <topic> <file>
                           normalize and emit record.append/fail events (JSON input)
  show-record <record-id>  display record metadata
  show-trace <topic>       filter trace.link events for a topic
  link-trace <child-record-id> <parent-record-id>
                           emit a trace.link event connecting two records
  get-artifact <artifact-id>
                           look up artifact metadata by id
  cat-artifact <artifact-id>
                           stream the artifact body by id
  doctor                   run quick health checks for local and service stores
  service-status           inspect the live xs systemd unit and store status
  service-show <topic>     render frames from the service store
  service-tail <topic>     follow a topic stream from the service store
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
  if run_xs scru128 >/dev/null 2>&1; then
    run_xs scru128
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

service_exec() {
  local -a cmd=("$@")
  if [[ "$MODE" == "service" && "${SERVICE_USE_SUDO:-1}" != "0" && "$(id -u)" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo -u "$SERVICE_USER" env PATH="$PATH" "${cmd[@]}"
      return
    fi
    if [[ "$SERVICE_SUDO_WARNED" -eq 0 ]]; then
      printf 'warning: sudo not found; service mode may lack permissions\n' >&2
      SERVICE_SUDO_WARNED=1
    fi
  fi
  "${cmd[@]}"
}

run_xs() {
  service_exec "$XS_BIN" "$@"
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
    if run_xs version "$addr" >/dev/null 2>&1; then
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
  if run_xs version "$addr" >/dev/null 2>&1; then
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
    printf '%s\n' "$body" | run_xs append "$(resolve_addr)" "$topic" --meta "$meta"
  else
    printf '%s\n' "$body" | run_xs append "$(resolve_addr)" "$topic"
  fi
}

schema_helper() {
  XS_SCHEMA_ADDR="$(resolve_addr)" XS_SCHEMA_BIN="$XS_BIN" python3 "$SCRIPT_DIR/xs-schema.py" "$@"
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
  XS_HELPER_PRETTY_ADDR="$addr" XS_HELPER_PRETTY_BIN="$XS_BIN" service_exec python3 -u -c "$pretty_script"
}

fetch_artifact_record() {
  local artifact_id="$1"
  local depth="${XS_HELPER_ARTIFACT_SEARCH_DEPTH:-2000}"
  local artifact_search_script
  artifact_search_script="$(cat <<'PY'
import json
import os
import subprocess
import sys

ADDR = os.environ["XS_HELPER_ARTIFACT_ADDR"]
XS_BIN = os.environ["XS_HELPER_ARTIFACT_BIN"]

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

target = sys.argv[1]

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
    payload = extract_payload(frame)
    if not isinstance(payload, dict):
        continue
    if payload.get("artifact_id") != target:
        continue
    meta = frame.get("meta") or {}
    topic = payload.get("topic") or frame.get("topic") or meta.get("topic")
    print(json.dumps({
        "topic": topic,
        "payload": payload,
        "meta": meta,
        "frame": frame,
    }))
    sys.exit(0)
sys.exit(2)
PY
)"
  run_xs cat "$(resolve_addr)" --last "$depth" | \
    XS_HELPER_ARTIFACT_ADDR="$(resolve_addr)" XS_HELPER_ARTIFACT_BIN="$XS_BIN" \
    service_exec python3 -c "$artifact_search_script" "$artifact_id"
}

print_artifact_summary() {
  local record="$1"
  if [[ -z "$record" ]]; then
    return
  fi
  local summary_script
  summary_script="$(cat <<'PY'
import json, sys

data = json.load(sys.stdin)
payload = data.get("payload") or {}
meta = data.get("meta") or {}
frame = data.get("frame") or {}

fields = [
    ("topic", data.get("topic") or payload.get("topic") or frame.get("topic")),
    ("artifact_id", payload.get("artifact_id") or frame.get("artifact_id")),
    ("label", payload.get("label")),
    ("mime", payload.get("mime")),
    ("sha256", payload.get("sha256")),
    ("cas_path", payload.get("cas_path") or frame.get("cas_path")),
    ("producer", payload.get("producer") or meta.get("producer")),
    ("timestamp", payload.get("timestamp") or frame.get("timestamp")),
]

for key, value in fields:
    if value not in (None, ""):
        print(f"{key}: {value}")

if meta:
    extras = []
    for key in ("type", "topic", "producer"):
        if key in meta:
            extras.append(f"{key}={meta[key]}")
    if extras:
        print("meta: " + " ".join(extras))
PY
  )"
  printf '%s\n' "$record" | python3 -c "$summary_script"
}

extract_artifact_cas_path() {
  local record="$1"
  local cas_script
  cas_script="$(cat <<'PY'
import json, sys

data = json.load(sys.stdin)
payload = data.get("payload") or {}
frame = data.get("frame") or {}

for source in (payload, frame):
    if isinstance(source, dict):
        path = source.get("cas_path")
        if path:
            print(path)
            sys.exit(0)
sys.exit(1)
PY
  )"
  printf '%s\n' "$record" | python3 -c "$cas_script"
}

cat_artifact_file() {
  local path="$1"
  if [[ -z "$path" ]]; then
    fail "artifact path is empty"
  fi
  if [[ ! -e "$path" ]]; then
    fail "artifact path missing: $path"
  fi
  service_exec cat "$path"
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
    if run_xs version "$addr" >/dev/null 2>&1; then
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
  run_xs cat "${args[@]}" | pretty_events "$(resolve_addr)"
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
  run_xs cat "$(resolve_addr)" --last 200 | python3 -c "$topics_script"
}

command_show() {
  ensure_xs
  ensure_local_server
  [[ $# -ge 1 ]] || fail 'show requires a topic'
  local topic="$(normalize_topic "$1")"
  run_xs cat "$(resolve_addr)" --topic "$topic" --last 50 | pretty_events "$(resolve_addr)"
}

command_tail() {
  ensure_xs
  ensure_local_server
  [[ $# -ge 1 ]] || fail 'tail requires a topic'
  local topic="$(normalize_topic "$1")"
  run_xs cat "$(resolve_addr)" --topic "$topic" --follow | pretty_events "$(resolve_addr)"
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

command_define_contract() {
  ensure_xs
  ensure_local_server
  (( $# >= 2 )) || fail 'define-contract requires <topic> <file>'
  local topic
  topic="$(normalize_topic "$1")"
  local def_file
  def_file="$2"
  [[ -f "$def_file" ]] || fail "definition file not found: $def_file"
  local timestamp
  timestamp="$(timestamp_iso)"
  local schema_event
  schema_event="$(schema_helper define-contract --topic "$topic" --input "$def_file" --producer "$PRODUCER" --timestamp "$timestamp")"
  append_event "$topic" "$schema_event" "{\"producer\":\"$PRODUCER\",\"type\":\"contract.define\"}"
  local contract_id
  contract_id="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["contract_id"])' <<< "$schema_event")"
  printf 'contract.define emitted for %s (contract_id=%s)\n' "$topic" "$contract_id"
}

command_emit_record() {
  ensure_xs
  ensure_local_server
  local status="append"
  if [[ $# -gt 0 && "$1" == "--status" ]]; then
    if [[ $# -lt 2 ]]; then
      fail 'emit-record --status requires a value'
    fi
    status="$2"
    if [[ "$status" != "fail" ]]; then
      fail 'emit-record --status only supports fail'
    fi
    shift 2
  fi
  (( $# >= 2 )) || fail 'emit-record requires <topic> <file>'
  local topic
  topic="$(normalize_topic "$1")"
  local record_file
  record_file="$2"
  [[ -f "$record_file" ]] || fail "record file not found: $record_file"
  local timestamp
  timestamp="$(timestamp_iso)"
  local schema_event
  schema_event="$(schema_helper emit-record --topic "$topic" --input "$record_file" --status "$status" --producer "$PRODUCER" --timestamp "$timestamp")"
  local kind
  if [[ "$status" == "fail" ]]; then
    kind="record.fail"
  else
    kind="record.append"
  fi
  append_event "$topic" "$schema_event" "{\"producer\":\"$PRODUCER\",\"type\":\"$kind\"}"
  local record_id
  record_id="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["record_id"])' <<< "$schema_event")"
  printf '%s emitted for %s (record_id=%s)\n' "$kind" "$topic" "$record_id"
}

command_show_record() {
  ensure_xs
  ensure_local_server
  (( $# >= 1 )) || fail 'show-record requires <record-id>'
  local record_id
  record_id="$1"
  run_xs cat "$(resolve_addr)" --last 400 | schema_helper show-record --record "$record_id"
}

command_show_trace() {
  ensure_xs
  ensure_local_server
  (( $# >= 1 )) || fail 'show-trace requires <topic>'
  local topic
  topic="$(normalize_topic "$1")"
  run_xs cat "$(resolve_addr)" --topic "$topic" --last 400 | schema_helper show-trace --topic "$topic"
}

command_link_trace() {
  ensure_xs
  ensure_local_server
  (( $# >= 2 )) || fail 'link-trace requires <child-record-id> <parent-record-id>'
  local child
  child="$1"
  local parent
  parent="$2"
  local topic
  if ! topic="$(run_xs cat "$(resolve_addr)" --last 400 | schema_helper record-topic --record "$child")"; then
    fail "could not determine topic for child record $child"
  fi
  topic="$(normalize_topic "$topic")"
  local timestamp
  timestamp="$(timestamp_iso)"
  local schema_event
  schema_event="$(schema_helper trace-link --topic "$topic" --child "$child" --parent "$parent" --producer "$PRODUCER" --timestamp "$timestamp")"
  append_event "$topic" "$schema_event" "{\"producer\":\"$PRODUCER\",\"type\":\"trace.link\"}"
  printf 'trace.link emitted for %s (child=%s parent=%s)\n' "$topic" "$child" "$parent"
}

command_doctor() {
  ensure_xs
  local saved_mode="$MODE"
  printf '=== local doctor ===\n'
  MODE="local"
  ensure_local_server
  command_status
  command_topics
  MODE="$saved_mode"
  printf '\n=== service doctor ===\n'
  command_service_status
}

command_service_status() {
  ensure_xs
  local prev_mode="$MODE"
  MODE="service"
  command_status
  local service_addr
  service_addr="$(resolve_addr)"
  if command -v systemctl >/dev/null 2>&1; then
    printf 'service unit: %s\n' "$SERVICE_UNIT_NAME"
    systemctl --no-pager show -p ActiveState -p SubState -p MainPID "$SERVICE_UNIT_NAME" || true
    systemctl --no-pager status "$SERVICE_UNIT_NAME" --lines=5 || true
  else
    printf 'systemctl: not available\n'
  fi
  local store_info
  store_info=$(service_exec stat -c 'store: %n owner=%U:%G mode=%a' "$SERVICE_STORE_PATH" 2>/dev/null || true)
  if [[ -n "$store_info" ]]; then
    printf '%s\n' "$store_info"
  else
    printf 'store: %s (unreadable)\n' "$SERVICE_STORE_PATH"
  fi
  local socket_info
  socket_info=$(service_exec stat -c 'socket: %n owner=%U:%G mode=%a' "$service_addr" 2>/dev/null || true)
  if [[ -n "$socket_info" ]]; then
    printf '%s\n' "$socket_info"
  else
    printf 'socket: %s (missing)\n' "$service_addr"
  fi
  MODE="$prev_mode"
}

command_service_show() {
  local prev_mode="$MODE"
  MODE="service"
  command_show "$@"
  MODE="$prev_mode"
}

command_service_tail() {
  local prev_mode="$MODE"
  MODE="service"
  command_tail "$@"
  MODE="$prev_mode"
}

command_raw() {
  ensure_xs
  ensure_local_server
  [[ $# -ge 1 ]] || fail 'raw requires a topic'
  local topic="${1}"
  topic="$(normalize_topic "$topic")"
  local limit=200
  if [[ $# -gt 1 && "$2" =~ ^[0-9]+$ ]]; then
    limit="$2"
  fi
  run_xs cat "$(resolve_addr)" --topic "$topic" --last "$limit"
}

command_get_artifact() {
  ensure_xs
  [[ $# -ge 1 ]] || fail 'get-artifact requires <artifact-id>'
  local artifact_id="$1"
  local record
  if ! record="$(fetch_artifact_record "$artifact_id")"; then
    fail "artifact not found: $artifact_id (search depth=${XS_HELPER_ARTIFACT_SEARCH_DEPTH:-2000})"
  fi
  print_artifact_summary "$record"
}

command_cat_artifact() {
  ensure_xs
  [[ $# -ge 1 ]] || fail 'cat-artifact requires <artifact-id>'
  local artifact_id="$1"
  local record
  if ! record="$(fetch_artifact_record "$artifact_id")"; then
    fail "artifact not found: $artifact_id (search depth=${XS_HELPER_ARTIFACT_SEARCH_DEPTH:-2000})"
  fi
  print_artifact_summary "$record"
  local path
  if ! path="$(extract_artifact_cas_path "$record")"; then
    fail "artifact path could not be resolved for $artifact_id"
  fi
  cat_artifact_file "$path"
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
  define-contract)
    command_define_contract "$@"
    ;;
  emit-record)
    command_emit_record "$@"
    ;;
  show-record)
    command_show_record "$@"
    ;;
  show-trace)
    command_show_trace "$@"
    ;;
  link-trace)
    command_link_trace "$@"
    ;;
  doctor)
    command_doctor
    ;;
  raw)
    command_raw "$@"
    ;;
  get-artifact)
    command_get_artifact "$@"
    ;;
  cat-artifact)
    command_cat_artifact "$@"
    ;;
  service-status)
    command_service_status
    ;;
  service-show)
    command_service_show "$@"
    ;;
  service-tail)
    command_service_tail "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
