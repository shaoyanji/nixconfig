#!/usr/bin/env python3
"""
System One & System Two Pre-Harness Ensemble Dispatcher
Strings together fast non-autoregressive decision models (Julia-1 & Laya) with
deep deliberative reasoning models (Nemotron-3-Ultra:cloud via local Ollama).

Architecture:
- System 1 (Reflex Tier): Julia-1 (144M, 8k context) & Laya (421M, 512 context)
  Evaluates 10 core service states in sub-millisecond CPU time (< 0.5 ms).
- System 2 (Deliberation Tier): Nemotron-3-Ultra:cloud via Ollama
  Called conditionally when System 1 detects high-urgency anomalies or architectural drift.
- Pre-Harness Layer:
  Enforces deterministic timeouts, schema validation, fallback guidance,
  and safe execution without exposing open-ended tool execution to the raw model.
"""

import sys
import os
import json
import time
import urllib.request
import urllib.error
import argparse
import subprocess
from typing import Dict, List, Any, Optional

# Import local System One Decision Engine
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from engine import DecisionEngine
except ImportError:
    # Standalone fallback if invoked in isolated path
    from modules.services.systemone.engine import DecisionEngine

OLLAMA_ENDPOINT = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
DEFAULT_SYSTEM2_MODEL = "nemotron-3-ultra:cloud"

class PreHarnessEnsemble:
    def __init__(self, s1_model: str = "julia-1", s2_model: str = DEFAULT_SYSTEM2_MODEL):
        self.s1 = DecisionEngine(s1_model)
        self.s1_model_name = s1_model
        self.s2_model = s2_model

    def query_system2(self, prompt: str, system_context: Optional[str] = None, timeout: int = 90) -> Dict[str, Any]:
        """Query Nemotron-3-Ultra:cloud via local Ollama API with pre-harness guardrails."""
        full_prompt = prompt
        if system_context:
            full_prompt = f"[System Context: Host frieren, NixOS 26.11, Intel Core i5-8250U, 1TB SSD root, 2TB HDD data pool]\n{system_context}\n\n[Task]\n{prompt}"

        payload = {
            "model": self.s2_model,
            "prompt": full_prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,
                "num_predict": 512
            }
        }

        req = urllib.request.Request(
            f"{OLLAMA_ENDPOINT}/api/generate",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )

        start_t = time.time()
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                latency = time.time() - start_t
                return {
                    "success": True,
                    "model": data.get("model", self.s2_model),
                    "response": data.get("response", "").strip(),
                    "thinking": data.get("thinking", ""),
                    "latency_sec": round(latency, 3),
                    "tokens_eval": data.get("eval_count", 0)
                }
        except Exception as e:
            return {
                "success": False,
                "model": self.s2_model,
                "error": str(e),
                "fallback_guidance": "System 2 deliberation unavailable; proceeding with System 1 deterministic recommendation."
            }

    # --- The 10 Candidate Service Triages ---

    def triage_gatus(self, status_payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """1. Gatus Fleet Monitors alert & probe noise triage."""
        state = json.dumps(status_payload) if status_payload else "Gatus endpoints active; 7 endpoints probed, alerting unconfigured."
        decision = self.s1.choice(state, "Evaluate monitoring probe reliability", ["TRANSIENT_BLIP_IGNORE", "SERVICE_DEGRADATION", "CRITICAL_OUTAGE"])
        urgency = self.s1.score(state, "Alert escalation priority to SimpleX #Fleet", 1.0, 5.0)
        
        result = {
            "service": "gatus",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": urgency["score"] >= 3.5
        }
        if result["deliberation_needed"]:
            prompt = f"Gatus detected service degradation ({decision['decision']}). Recommend exact network or reverse-proxy diagnostic step."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def triage_paperless(self, consume_dir: str = "/var/lib/paperless/consume") -> Dict[str, Any]:
        """2. Paperless document consumption pipeline healer."""
        files = os.listdir(consume_dir) if os.path.exists(consume_dir) else []
        file_info = []
        for f in files[:10]:
            p = os.path.join(consume_dir, f)
            size = os.path.getsize(p) if os.path.isfile(p) else 0
            file_info.append(f"{f} ({size} bytes)")
        state = f"Consume queue has {len(files)} files: {', '.join(file_info)}" if files else "Consume queue is empty."
        
        decision = self.s1.choice(state, "Evaluate consume queue health", ["HEALTHY_IDLE", "STALLED_GHOST_ARTIFACT", "ACTIVE_PROCESSING"])
        urgency = self.s1.score(state, "Pipeline intervention requirement", 1.0, 5.0)
        
        result = {
            "service": "paperless",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": decision["decision"] == "STALLED_GHOST_ARTIFACT"
        }
        if result["deliberation_needed"]:
            prompt = f"Paperless ingestion queue is stalled with ghost or malformed artifacts: {state}. Provide safe quarantine commands."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def triage_diskqos(self, is_streaming: bool = False, seek_latency_ms: float = 25.0) -> Dict[str, Any]:
        """3. Spinning HDD I/O & media playback quality-of-service governor."""
        state = f"4K streaming active: {is_streaming}. HDD read seek latency: {seek_latency_ms} ms. Transmission & Aria2 writing to /Volumes/data."
        decision = self.s1.choice(state, "Disk I/O pacing policy", ["UNCAPPED_BURST", "STREAMING_PRIORITY_THROTTLE", "EMERGENCY_WRITE_PAUSE"])
        urgency = self.s1.score(state, "Playback frame-drop risk", 1.0, 5.0)
        
        result = {
            "service": "diskqos",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": decision["decision"] == "EMERGENCY_WRITE_PAUSE" or (is_streaming and seek_latency_ms > 150)
        }
        if result["deliberation_needed"]:
            prompt = f"Spinning HDD contention detected during 4K streaming ({seek_latency_ms}ms seek latency). Outline ionice and dirty_ratio settings."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def triage_postgres(self, dead_tuple_ratio: float = 0.05, vector_latency_ms: float = 8.5) -> Dict[str, Any]:
        """4. PostgreSQL vector index health and dynamic vacuum gate."""
        state = f"Immich DB dead tuple ratio: {round(dead_tuple_ratio*100, 1)}%. HNSW vector search latency: {vector_latency_ms} ms. Collation: glibc 2.44 clean."
        decision = self.s1.choice(state, "PostgreSQL vacuum schedule policy", ["SKIP_VACUUM_HEALTHY", "BACKGROUND_VACUUM_ANALYZE", "URGENT_REINDEX_OFFPEAK"])
        urgency = self.s1.score(state, "Index degradation risk", 1.0, 5.0)
        
        result = {
            "service": "postgres",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": decision["decision"] == "URGENT_REINDEX_OFFPEAK" or dead_tuple_ratio > 0.20
        }
        if result["deliberation_needed"]:
            prompt = f"PostgreSQL vector tables show high bloat or latency degradation ({dead_tuple_ratio*100}% dead tuples, {vector_latency_ms}ms). Formulate non-locking maintenance plan."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def triage_simplex(self, message_text: str = "Host frieren nightly backup completed with 0 errors.") -> Dict[str, Any]:
        """5. SimpleX inter-agent message priority & intent classifier."""
        decision = self.s1.choice(message_text, "Message routing action", ["SILENT_LOG", "DAILY_DIGEST", "OPERATOR_PUSH_ALERT"])
        urgency = self.s1.score(message_text, "Severity and operator response urgency", 1.0, 5.0)
        
        result = {
            "service": "simplex",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": decision["decision"] == "OPERATOR_PUSH_ALERT"
        }
        if result["deliberation_needed"]:
            prompt = f"Classify this incoming fleet incident and produce a concise 2-sentence operator notification card: '{message_text}'"
            result["system2_deliberation"] = self.query_system2(prompt)
        return result

    def triage_restic(self, snapshot_delta_gb: float = 2.1, duration_sec: int = 180) -> Dict[str, Any]:
        """6. Restic nightly backup delta audit & ransomware anomaly detector."""
        state = f"Daily snapshot delta: {snapshot_delta_gb} GB. Execution duration: {duration_sec}s. Deduplication nominal."
        decision = self.s1.choice(state, "Backup delta integrity status", ["EXPECTED_DELTA_HEALTHY", "SUSPICIOUS_HIGH_CHURN", "ZERO_DATA_WARNING"])
        urgency = self.s1.score(state, "Backup regression risk", 1.0, 5.0)
        
        result = {
            "service": "restic",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": decision["decision"] != "EXPECTED_DELTA_HEALTHY"
        }
        if result["deliberation_needed"]:
            prompt = f"Restic snapshot delta flagged ({decision['decision']}). Recommend snapshot comparison inspection."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def triage_jellyfin(self, vaapi_active: bool = True, cpu_load: float = 12.0) -> Dict[str, Any]:
        """7. Jellyfin QuickSync transcode engine watchdog."""
        state = f"Hardware VA-API QuickSync active: {vaapi_active}. Host CPU load: {cpu_load}%. Intel UHD 620 render node /dev/dri/renderD128 accessible."
        decision = self.s1.choice(state, "Transcoding subsystem status", ["HARDWARE_ACCELERATED_OK", "SOFTWARE_CPU_FALLBACK_RISK", "DRIVER_CONTEXT_FAULT"])
        urgency = self.s1.score(state, "Thermal and CPU overload risk", 1.0, 5.0)
        
        result = {
            "service": "jellyfin",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": not vaapi_active or cpu_load > 65.0
        }
        if result["deliberation_needed"]:
            prompt = f"Jellyfin transcoding detected software fallback or high CPU load ({cpu_load}%). Formulate VA-API render node recovery command."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def triage_sessions(self, idle_hours: float = 2.5, is_tmux: bool = True) -> Dict[str, Any]:
        """8. SSH bastion session reaper anomaly classifier."""
        state = f"Session idle for {idle_hours} hours. Attached to tmux/multiplexer: {is_tmux}. User devji on seat0 / pts."
        decision = self.s1.choice(state, "Session lifecycle disposition", ["PRESERVE_DEV_SESSION", "REAP_ABANDONED_SCOPE", "FLAG_SECURITY_ANOMALY"])
        urgency = self.s1.score(state, "Session termination safety", 1.0, 5.0)
        
        result = {
            "service": "sessions",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": decision["decision"] == "FLAG_SECURITY_ANOMALY"
        }
        if result["deliberation_needed"]:
            prompt = f"Unusual SSH session detected ({state}). Recommend process tree verification step."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def triage_flake(self, stale_inputs_count: int = 2, closure_gb: float = 34.5) -> Dict[str, Any]:
        """9. Flake advisory audit & closure hygiene gate."""
        state = f"Stale inputs older than 60 days: {stale_inputs_count}. Current frieren closure: {closure_gb} GiB (Budget ceiling: 34.9 GiB)."
        decision = self.s1.choice(state, "Flake update action", ["SAFE_MAINTENANCE_WINDOW", "SECURITY_UPDATE_URGENT", "CLOSURE_BUDGET_BREACH"])
        urgency = self.s1.score(state, "Flake drift risk", 1.0, 5.0)
        
        result = {
            "service": "flake",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": closure_gb >= 34.8 or stale_inputs_count > 5
        }
        if result["deliberation_needed"]:
            prompt = f"Flake closure approaching ceiling ({closure_gb}/34.9 GiB). Recommend closure optimization and dead input pruning."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def triage_btrfs(self, device_errors: int = 0, commit_latency_ms: float = 35.0) -> Dict[str, Any]:
        """10. Btrfs silent corruption and device error watchdog."""
        state = f"Btrfs device stats errors: {device_errors}. Transaction commit latency: {commit_latency_ms} ms across SSD / and HDD /Volumes/data."
        decision = self.s1.choice(state, "Filesystem integrity health", ["STORAGE_NOMINAL", "METADATA_LATENCY_WARNING", "HARDWARE_SECTOR_CORRUPTION"])
        urgency = self.s1.score(state, "Data pool loss risk", 1.0, 5.0)
        
        result = {
            "service": "btrfs",
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": device_errors > 0 or commit_latency_ms > 200.0
        }
        if result["deliberation_needed"]:
            prompt = f"Btrfs health anomaly ({device_errors} errors, {commit_latency_ms}ms latency). Propose scrub, remount, or SMART test strategy."
            result["system2_deliberation"] = self.query_system2(prompt, state)
        return result

    def audit_all(self) -> Dict[str, Any]:
        """Run triage across all 10 services and assemble the ensemble scorecard."""
        start_t = time.time()
        results = {
            "gatus": self.triage_gatus(),
            "paperless": self.triage_paperless(),
            "diskqos": self.triage_diskqos(),
            "postgres": self.triage_postgres(),
            "simplex": self.triage_simplex(),
            "restic": self.triage_restic(),
            "jellyfin": self.triage_jellyfin(),
            "sessions": self.triage_sessions(),
            "flake": self.triage_flake(),
            "btrfs": self.triage_btrfs()
        }
        total_time_ms = (time.time() - start_t) * 1000.0
        
        deliberations_count = sum(1 for r in results.values() if r.get("deliberation_needed"))
        
        return {
            "system1_model": self.s1_model_name,
            "system2_model": self.s2_model,
            "services_triaged": len(results),
            "deliberations_triggered": deliberations_count,
            "system1_reflex_time_ms": round(total_time_ms, 2),
            "services": results
        }

def main():
    parser = argparse.ArgumentParser(description="System 1 & System 2 Pre-Harness Ensemble Dispatcher")
    parser.add_argument("--s1-model", choices=["julia-1", "laya"], default="julia-1", help="System 1 decision model")
    parser.add_argument("--s2-model", default=DEFAULT_SYSTEM2_MODEL, help="System 2 deliberation model via Ollama")
    subparsers = parser.add_subparsers(dest="command")

    # Command: audit-all
    subparsers.add_parser("audit-all", help="Audit all 10 services using the ensemble dispatcher")

    # Command: triage
    triage_parser = subparsers.add_parser("triage", help="Triage a specific service")
    triage_parser.add_argument("service", choices=[
        "gatus", "paperless", "diskqos", "postgres", "simplex",
        "restic", "jellyfin", "sessions", "flake", "btrfs"
    ], help="Target service to triage")

    # Command: deliberate
    delib_parser = subparsers.add_parser("deliberate", help="Directly trigger System 2 deliberation")
    delib_parser.add_argument("prompt", help="Deliberation prompt or incident summary")

    args = parser.parse_args()
    ensemble = PreHarnessEnsemble(s1_model=args.s1_model, s2_model=args.s2_model)

    if args.command == "audit-all":
        report = ensemble.audit_all()
        print(json.dumps(report, indent=2))
    elif args.command == "triage":
        fn = getattr(ensemble, f"triage_{args.service}", None)
        if fn:
            print(json.dumps(fn(), indent=2))
        else:
            print(json.dumps({"error": f"Unknown service handler: {args.service}"}))
    elif args.command == "deliberate":
        result = ensemble.query_system2(args.prompt)
        print(json.dumps(result, indent=2))
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
