#!/usr/bin/env bash
# qmd-eisen-embed-sync.sh — Deterministic multi-floor QMD embedding synchronization
#
# Purpose:
#   Offload batch vector embeddings from Frieren (15W quad-core NAS) to Eisen
#   (12-core Xeon workstation with local NVMe) via Wake-on-LAN without LLM assistance.
#
# Pipeline:
#   1. Preflight check: verify Eisen reachability over SSH; avoid WoL if already online.
#   2. Local index refresh: run fast BM25 'qmd update' on Frieren (local NVMe/btrfs).
#   3. Push database to Eisen: rsync index.sqlite & index.yml to Eisen's local NVMe.
#   4. Remote compute: run 'qmd embed' on Eisen (NVMe-local, multi-threaded llama.cpp).
#   5. Pull results: rsync updated index.sqlite & embedding models back to Frieren.
#   6. Verification: inspect vector counts on Frieren via 'qmd status'.
#   7. Clean poweroff: shut down Eisen if it was woken by WoL for this run.
#
# Usage:
#   qmd-eisen-embed-sync.sh [options]
#
# Options:
#   --check             Run preflight checks only (connectivity, tools, inventory, paths)
#   --status            Show current local index status and Eisen power state
#   --dry-run           Simulate pipeline steps without modifying data or sending WoL
#   --poweroff          Power off Eisen after sync completes (regardless of initial state)
#   --no-poweroff       Keep Eisen awake after sync (even if woken by WoL)
#   --force-poweroff    Power off Eisen even if gaming/active session detected
#   --timeout-mins N    Embed session cap in minutes (default: 30)
#   -c, --collection C  Embed only a specific collection (e.g. apps, german, recipes)
#   -h, --help          Show this help message

set -euo pipefail

TIMEOUT_MINS=30
CHECK_ONLY=0
STATUS_ONLY=0
DRY_RUN=0
FORCE_POWEROFF=0
EXPLICIT_POWEROFF=0
NO_POWEROFF=0
TARGET_COLLECTION=""

REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "/Volumes/data/projects/nixconfig")"
EISEN_SSH_HOST="eisen"
WOKE_EISEN=0
WAS_ONLINE=0

log() {
  echo "==> [$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

warn() {
  echo "WARN [$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

err() {
  echo "ERR  [$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

show_help() {
  cat <<'HELP'
qmd-eisen-embed-sync - Deterministic QMD Vector Embedding Remote Offload

Usage:
  qmd-eisen-embed-sync [options]

Options:
  --check               Run preflight checks only and exit
  --status              Show local index and Eisen connectivity status
  --dry-run             Simulate pipeline without modifying data or power
  --poweroff            Power off Eisen after sync completes
  --no-poweroff         Keep Eisen awake even if woken by WoL
  --force-poweroff      Force poweroff even if Eisen was already online before sync
  --timeout-mins <N>    Maximum embedding runtime in minutes (default: 30)
  -c, --collection <N>  Embed only a single collection (default: all)
  -h, --help            Show this help message

Examples:
  qmd-eisen-embed-sync --check           # verify reachability & requirements
  qmd-eisen-embed-sync --status          # view current vector counts & power state
  qmd-eisen-embed-sync                   # run full sync (shuts down Eisen if woken)
  qmd-eisen-embed-sync -c apps           # embed only the 'apps' collection
  qmd-eisen-embed-sync --no-poweroff     # run sync but leave Eisen powered on
HELP
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --status)
      STATUS_ONLY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --poweroff)
      EXPLICIT_POWEROFF=1
      shift
      ;;
    --no-poweroff|--keep-awake)
      NO_POWEROFF=1
      shift
      ;;
    --force-poweroff)
      FORCE_POWEROFF=1
      EXPLICIT_POWEROFF=1
      shift
      ;;
    --timeout-mins)
      if [[ -n "${2:-}" ]]; then
        TIMEOUT_MINS="$2"
        shift 2
      else
        err "--timeout-mins requires an argument"
        exit 1
      fi
      ;;
    -c|--collection)
      if [[ -n "${2:-}" ]]; then
        TARGET_COLLECTION="$2"
        shift 2
      else
        err "--collection requires an argument"
        exit 1
      fi
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Check if Eisen is currently reachable over SSH
is_eisen_online() {
  ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "$EISEN_SSH_HOST" "true" 2>/dev/null
}

# Query Eisen inventory facts (MAC & LAN IP)
get_eisen_inventory() {
  local mac ip
  mac="$(nix eval --raw "$REPO#inventory.hosts.eisen.network.mac" 2>/dev/null || echo "00:e0:22:1c:bb:ed")"
  ip="$(nix eval --raw "$REPO#inventory.hosts.eisen.network.lan_ip" 2>/dev/null || echo "192.168.3.91")"
  echo "$mac $ip"
}

# Send WoL magic packet
send_wol_magic_packet() {
  local mac ip
  read -r mac ip <<< "$(get_eisen_inventory)"

  if [[ -z "$mac" || -z "$ip" ]]; then
    err "Cannot determine Eisen MAC/IP from inventory."
    return 1
  fi

  log "Dispatching WoL magic packet to Eisen ($mac via $ip)..."
  python3 - "$mac" "$ip" <<'PY'
import socket, sys

mac, ip = sys.argv[1], sys.argv[2]
magic = b"\xff" * 6 + bytes.fromhex(mac.replace(":", "").replace("-", "")) * 16
bcast = ip.rsplit(".", 1)[0] + ".255"
sent = 0
for iface in ("enp1s0", "wlp2s0", "enp0s20f0u2u1i5", "eth0"):
    for port in (9, 7):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            try:
                s.setsockopt(socket.SOL_SOCKET, 25, iface.encode())
            except OSError:
                pass
            for dest in (bcast, "255.255.255.255"):
                try:
                    s.sendto(magic, (dest, port))
                    sent += 1
                except OSError:
                    pass
if not sent:
    sys.exit("WoL: no interface accepted magic packet")
print(f"WoL: broadcast packet dispatched ({sent} sends)")
PY
}

# Wait for Eisen SSH to become ready
wait_for_eisen() {
  local timeout=120
  local start_time
  start_time="$(date +%s)"
  log "Waiting for Eisen to boot and answer SSH (timeout: ${timeout}s)..."

  while true; do
    if is_eisen_online; then
      log "Eisen is online and SSH reachable!"
      return 0
    fi
    local elapsed=$(( $(date +%s) - start_time ))
    if [[ "$elapsed" -ge "$timeout" ]]; then
      err "Timed out waiting for Eisen after ${timeout}s."
      return 1
    fi
    sleep 3
  done
}

# Ensure Eisen is online: avoid WoL if already reachable via SSH
ensure_eisen_online() {
  if is_eisen_online; then
    WAS_ONLINE=1
    log "Eisen is already online and reachable via SSH. Avoiding Wake-on-LAN."
    return 0
  fi

  WAS_ONLINE=0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Eisen is offline. Would send WoL packet and wait for SSH."
    return 0
  fi

  log "Eisen is offline. Initiating Wake-on-LAN boot sequence..."
  send_wol_magic_packet
  WOKE_EISEN=1
  wait_for_eisen
}

# Clean shutdown of Eisen
shutdown_eisen() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Would execute remote poweroff on Eisen."
    return 0
  fi

  log "Initiating clean poweroff of Eisen..."
  # Issue systemctl poweroff; fallback to sudo systemctl poweroff
  ssh -o BatchMode=yes "$EISEN_SSH_HOST" "systemctl poweroff 2>/dev/null || sudo -n systemctl poweroff 2>/dev/null || sudo -n shutdown -h now 2>/dev/null || true"
  log "Poweroff signal successfully dispatched to Eisen."
}

# Preflight check mode
run_check() {
  local ok=1
  echo "=== QMD Remote Embedding Offload: Preflight Check ==="
  echo

  # 1. Required commands
  for cmd in ssh rsync sqlite3 python3 nix; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "  [OK] Local tool present: $cmd"
    else
      echo "  [FAIL] Missing local tool: $cmd"
      ok=0
    fi
  done

  # 2. Local QMD binary
  if command -v qmd >/dev/null 2>&1; then
    local qmd_ver
    qmd_ver="$(qmd --version 2>&1 || true)"
    echo "  [OK] Local qmd binary: $qmd_ver"
  else
    echo "  [WARN] Local qmd binary not in PATH (searches still work via database)"
  fi

  # 3. Inventory resolution
  local mac ip
  read -r mac ip <<< "$(get_eisen_inventory)"
  if [[ -n "$mac" && -n "$ip" ]]; then
    echo "  [OK] Eisen inventory facts: MAC=$mac, IP=$ip"
  else
    echo "  [FAIL] Unable to read Eisen MAC/IP from inventory.toml"
    ok=0
  fi

  # 4. Local paths
  if [[ -f "$HOME/.config/qmd/index.yml" ]]; then
    local coll_count
    coll_count="$(grep -cE '^[[:space:]]+[a-zA-Z0-9_-]+:' "$HOME/.config/qmd/index.yml" || echo "0")"
    echo "  [OK] Local config present: ~/.config/qmd/index.yml ($coll_count collections)"
  else
    echo "  [FAIL] Missing ~/.config/qmd/index.yml"
    ok=0
  fi

  if [[ -f "$HOME/.cache/qmd/index.sqlite" ]]; then
    local sz
    sz="$(du -h "$HOME/.cache/qmd/index.sqlite" | cut -f1)"
    echo "  [OK] Local index database: ~/.cache/qmd/index.sqlite ($sz)"
  else
    echo "  [WARN] No local ~/.cache/qmd/index.sqlite (will be initialized on first run)"
  fi

  # 5. Local model weights
  if [[ -f "$HOME/.cache/qmd/models/hf_ggml-org_embeddinggemma-300M-Q8_0.gguf" ]]; then
    echo "  [OK] Local embedding model present: embeddinggemma-300M (semantic queries enabled)"
  else
    echo "  [WARN] Local embedding model missing in ~/.cache/qmd/models/ (synced during embed run)"
  fi

  # 6. Eisen reachability
  echo
  if is_eisen_online; then
    echo "  [OK] Eisen state: ONLINE (reachable over SSH)"
    local remote_qmd
    remote_qmd="$(ssh -o BatchMode=yes "$EISEN_SSH_HOST" "qmd --version 2>&1 || true")"
    echo "  [OK] Remote Eisen qmd: $remote_qmd"
  else
    echo "  [INFO] Eisen state: OFFLINE (Wake-on-LAN available via MAC $mac)"
  fi

  echo
  if [[ "$ok" -eq 1 ]]; then
    echo "==> Preflight check PASSED."
    return 0
  else
    echo "==> Preflight check FAILED."
    return 1
  fi
}

# Status mode
run_status() {
  echo "=== QMD Status (Frieren) ==="
  if command -v qmd >/dev/null 2>&1; then
    qmd status
  else
    echo "qmd binary not in PATH; checking SQLite database directly:"
    if [[ -f "$HOME/.cache/qmd/index.sqlite" ]]; then
      sqlite3 "file:$HOME/.cache/qmd/index.sqlite?mode=ro" \
        "SELECT 'Documents: ' || count(*) FROM documents;
         SELECT 'Vectors:   ' || count(*) FROM content_vectors;"
    fi
  fi

  echo
  echo "=== Eisen Status ==="
  if is_eisen_online; then
    echo "Power State: ONLINE"
    ssh -o BatchMode=yes "$EISEN_SSH_HOST" "uptime; free -h | grep Mem; df -h /mnt/storage 2>/dev/null || df -h ~"
  else
    echo "Power State: OFFLINE (sleeping / standby)"
  fi
}

# Main sync workflow
run_sync() {
  log "Starting QMD Eisen offload sync pipeline..."

  ensure_eisen_online

  # 1. Local index refresh on Frieren (BM25 only, fast, local disks)
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Would run 'qmd update' locally on Frieren."
  else
    log "Refreshing lexical index on Frieren (BM25 only, local NVMe/btrfs)..."
    if command -v qmd >/dev/null 2>&1; then
      qmd update || warn "qmd update returned non-zero, continuing with current index"
    else
      warn "qmd binary not on Frieren PATH, skipping local update"
    fi
  fi

  # 2. Push database & config to Eisen local NVMe
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Would push index.yml and index.sqlite to Eisen NVMe."
  else
    log "Ensuring remote directories on Eisen..."
    ssh -o BatchMode=yes "$EISEN_SSH_HOST" "mkdir -p ~/.config/qmd ~/.cache/qmd/models"

    log "Pushing index.yml and index.sqlite to Eisen NVMe cache..."
    if [[ -f "$HOME/.config/qmd/index.yml" ]]; then
      rsync -av "$HOME/.config/qmd/index.yml" "$EISEN_SSH_HOST:~/.config/qmd/index.yml"
    fi

    if [[ -f "$HOME/.cache/qmd/index.sqlite" ]]; then
      # Checkpoint WAL locally first to prevent syncing dirty WAL state
      if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$HOME/.cache/qmd/index.sqlite" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
      fi
      # Uncompressed rsync to avoid CPU throttling on Frieren's mobile processor
      rsync -a --info=progress2 "$HOME/.cache/qmd/index.sqlite" "$EISEN_SSH_HOST:~/.cache/qmd/index.sqlite"
    fi
  fi

  # 3. Remote compute on Eisen NVMe
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Would execute remote 'qmd embed' on Eisen (timeout: ${TIMEOUT_MINS}m)."
  else
    local embed_cmd="qmd embed --timeout $TIMEOUT_MINS"
    if [[ -n "$TARGET_COLLECTION" ]]; then
      embed_cmd="qmd embed -c $TARGET_COLLECTION --timeout $TIMEOUT_MINS"
    fi

    log "Running batch embedding on Eisen ($embed_cmd)..."
    ssh -o BatchMode=yes "$EISEN_SSH_HOST" "$embed_cmd"
    # Checkpoint remote WAL before copying back
    ssh -o BatchMode=yes "$EISEN_SSH_HOST" 'sqlite3 ~/.cache/qmd/index.sqlite "PRAGMA wal_checkpoint(TRUNCATE);"' 2>/dev/null || true
  fi

  # 4. Pull results back to Frieren
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Would pull updated index.sqlite and models back to Frieren."
  else
    log "Pulling updated index.sqlite back to Frieren..."
    rsync -a --info=progress2 "$EISEN_SSH_HOST:~/.cache/qmd/index.sqlite" "$HOME/.cache/qmd/index.sqlite"

    log "Ensuring model weights are synced to Frieren (for fast local query/vsearch)..."
    mkdir -p "$HOME/.cache/qmd/models"
    rsync -a --ignore-existing "$EISEN_SSH_HOST:~/.cache/qmd/models/" "$HOME/.cache/qmd/models/"
  fi

  # 5. Verification
  if [[ "$DRY_RUN" -eq 0 ]]; then
    log "Verifying synchronized index status on Frieren..."
    if command -v qmd >/dev/null 2>&1; then
      qmd status
    fi
  fi

  # 6. Power management / Shutdown policy
  handle_poweroff
}

# Check if a game is actively running on Eisen (gaming guard stops llama-swap)
is_eisen_gaming() {
  local status
  status="$(ssh -o BatchMode=yes "$EISEN_SSH_HOST" "systemctl is-active llama-swap.service 2>/dev/null || echo 'unknown'")"
  [[ "$status" == "inactive" ]]
}

# Decide and execute shutdown
handle_poweroff() {
  if [[ "$NO_POWEROFF" -eq 1 ]]; then
    log "Shutdown inhibited by --no-poweroff. Leaving Eisen powered on."
    return 0
  fi

  if [[ "$EXPLICIT_POWEROFF" -eq 0 && "$WOKE_EISEN" -eq 0 ]]; then
    if [[ "$WAS_ONLINE" -eq 1 ]]; then
      log "Eisen was already online before this sync run. Leaving host powered on."
    fi
    return 0
  fi

  # Poweroff candidate: check gaming guard unless forced
  if [[ "$FORCE_POWEROFF" -eq 0 ]] && is_eisen_gaming; then
    warn "Eisen appears to be running a game (llama-swap.service is inactive). Skipping poweroff to avoid disruption."
    return 0
  fi

  if [[ "$EXPLICIT_POWEROFF" -eq 1 ]]; then
    log "Explicit --poweroff requested."
    shutdown_eisen
    return 0
  fi

  if [[ "$WOKE_EISEN" -eq 1 ]]; then
    log "Eisen was woken up via WoL for this sync run. Initiating clean post-sync poweroff..."
    shutdown_eisen
    return 0
  fi
}

main() {
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    run_check
    return $?
  fi

  if [[ "$STATUS_ONLY" -eq 1 ]]; then
    run_status
    return $?
  fi

  run_sync
  log "QMD Eisen embedding synchronization finished successfully!"
}

main "$@"
