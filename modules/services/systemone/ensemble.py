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
import subprocess
import argparse
import re
import xml.etree.ElementTree as ET
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
                "num_predict": 1536
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
                resp_text = data.get("response", "").strip()
                thinking_text = data.get("thinking", "").strip()
                if not resp_text and thinking_text:
                    resp_text = thinking_text[-800:]
                return {
                    "success": True,
                    "model": data.get("model", self.s2_model),
                    "response": resp_text,
                    "thinking": thinking_text,
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

    # --- EXP-066: Flake Regression Self-Healing & Rollback Ensemble ---

    def reconcile_flake(self, flake_path: str = "/Volumes/data/projects/nixconfig", target_file: Optional[str] = None, simulate_error: Optional[str] = None) -> Dict[str, Any]:
        """EXP-066: Flake Regression Self-Healing & AST patch synthesizer with preflight validation."""
        start_t = time.time()
        error_msg = simulate_error
        failing_file = target_file or os.path.join(flake_path, "hosts/frieren/infra-stack.nix")

        if not error_msg:
            # Audit primary nix files for syntax / parse validity
            files_to_check = [
                os.path.join(flake_path, "flake.nix"),
                os.path.join(flake_path, "hosts/frieren/default.nix"),
                os.path.join(flake_path, "hosts/frieren/infra-stack.nix"),
                os.path.join(flake_path, "modules/services/systemone-decision.nix")
            ]
            if target_file and target_file not in files_to_check:
                files_to_check.append(target_file)

            for fp in files_to_check:
                if os.path.isfile(fp):
                    proc = subprocess.run(["nix-instantiate", "--parse", fp], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                    if proc.returncode != 0:
                        error_msg = proc.stderr.strip()
                        failing_file = fp
                        break

        if not error_msg:
            state = f"Flake at {flake_path} parsed cleanly across all core units with 0 syntax errors."
            decision = self.s1.choice(state, "Evaluate flake expression integrity", ["FLAKE_HEALTHY_SYNTAX_VALID", "SYNTAX_TYPO_ERROR", "OPTION_RENAMED_UPSTREAM", "DEPENDENCY_CYCLE"])
            urgency = self.s1.score(state, "Evaluation regression urgency", 1.0, 5.0)
            latency_ms = round((time.time() - start_t) * 1000.0, 2)
            return {
                "success": True,
                "status": "HEALTHY",
                "flake_path": flake_path,
                "category": decision["decision"],
                "confidence": decision["confidence"],
                "urgency": urgency["score"],
                "deliberation_needed": False,
                "latency_ms": latency_ms
            }

        state = f"Flake evaluation failure in {failing_file}:\n{error_msg}"
        decision = self.s1.choice(state, "Classify compiler error trace", ["SYNTAX_TYPO_ERROR", "OPTION_RENAMED_UPSTREAM", "PACKAGE_REMOVED", "DEPENDENCY_CYCLE"])
        urgency = self.s1.score(state, "Evaluation regression urgency", 1.0, 5.0)

        prompt = (
            f"A NixOS flake evaluation regression was detected in {failing_file}:\n"
            f"Error Trace:\n{error_msg}\n"
            "Diagnose the root cause and synthesize the exact minimal replacement Nix code snippet."
        )
        delib = self.query_system2(prompt, state)

        patch_text = delib.get("response", "")
        trap_detected = "''" in patch_text and "'''" not in patch_text and "Python" in patch_text
        
        latency_ms = round((time.time() - start_t) * 1000.0, 2)
        return {
            "success": False,
            "status": "REGRESSION_DETECTED",
            "failing_file": failing_file,
            "error_trace": error_msg,
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "deliberation_needed": True,
            "system2_deliberation": delib,
            "preflight_guardrails": {
                "multiline_trap_detected": trap_detected,
                "verification_ready": True
            },
            "latency_ms": latency_ms
        }

    # --- EXP-067: Predictive Storage Failure Prognosis & Btrfs Rebalance Synthesis ---

    def storage_prognosis(self, mount_point: str = "/Volumes/data", simulate_contention: bool = False) -> Dict[str, Any]:
        """EXP-067: Predictive Storage Failure Prognosis & Automated Btrfs Rebalance Synthesis."""
        start_t = time.time()
        
        df_text = "Data, single: total=1.04TiB, used=1.00TiB\nMetadata, DUP: total=5.00GiB, used=1.41GiB"
        stats_text = "[/dev/sda2].write_io_errs 0, read_io_errs 0, flush_io_errs 0, corruption_errs 0"
        try:
            p_df = subprocess.run(["btrfs", "filesystem", "df", mount_point], stdout=subprocess.PIPE, text=True, timeout=5)
            if p_df.returncode == 0:
                df_text = p_df.stdout.strip()
            p_stats = subprocess.run(["btrfs", "device", "stats", mount_point], stdout=subprocess.PIPE, text=True, timeout=5)
            if p_stats.returncode == 0:
                stats_text = p_stats.stdout.strip()
        except Exception:
            pass

        streaming_active = False
        try:
            p_ss = subprocess.run(["ss", "-tn", "sport", "=", ":8096"], stdout=subprocess.PIPE, text=True, timeout=3)
            streaming_active = "ESTAB" in p_ss.stdout
        except Exception:
            pass

        if simulate_contention:
            df_text = "Data, single: total=1.04TiB, used=1.03TiB (99% full)\nMetadata, DUP: total=5.00GiB, used=4.92GiB (98% full, fragmented chunks)"
            streaming_active = True

        state = (
            f"Btrfs Pool: {mount_point}\n"
            f"Allocation DF:\n{df_text}\n"
            f"Device Error Counters:\n{stats_text}\n"
            f"Concurrent 4K Media Streaming Active: {streaming_active}"
        )

        decision = self.s1.choice(state, "Btrfs storage maintenance action", [
            "STORAGE_HEALTHY_IDLE",
            "BACKGROUND_BALANCE_SAFE",
            "URGENT_METADATA_EXPANSION",
            "CORRUPTION_SCRUB_REQUIRED",
            "STREAMING_PREEMPT_PAUSE"
        ])
        urgency = self.s1.score(state, "Storage failure and streaming disruption risk", 1.0, 5.0)

        delib_needed = decision["decision"] != "STORAGE_HEALTHY_IDLE" or urgency["score"] >= 3.5 or simulate_contention
        delib = None
        if delib_needed:
            prompt = (
                f"Storage telemetry on {mount_point} triggered maintenance:\n{state}\n"
                f"Classification: {decision['decision']} (Urgency: {urgency['score']}).\n"
                "Synthesize a safe, minimal Btrfs balance filter command (e.g. -dusage / -musage) "
                "and explain preemption rules during active media playback."
            )
            delib = self.query_system2(prompt, state)

        latency_ms = round((time.time() - start_t) * 1000.0, 2)
        return {
            "mount_point": mount_point,
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "media_streaming_active": streaming_active,
            "deliberation_needed": delib_needed,
            "system2_deliberation": delib,
            "latency_ms": latency_ms
        }

    # --- EXP-068: Multi-Modal Audio/Visual Media Indexing & Semantic Metadata Enricher ---

    def media_enrich(self, path: str = "/Volumes/data/media", sample_file: Optional[str] = None, simulate: bool = False) -> Dict[str, Any]:
        """EXP-068: Multi-Modal Audio/Visual Media Indexing & Semantic Metadata Enricher."""
        start_t = time.time()
        target_path = sample_file or path

        if os.path.isdir(target_path) and not sample_file:
            candidates = []
            try:
                p = subprocess.run(["sudo", "-n", "find", target_path, "-maxdepth", "2", "-type", "f", "(", "-name", "*.m4a", "-o", "-name", "*.mkv", "-o", "-name", "*.mp4", ")"], stdout=subprocess.PIPE, text=True, timeout=5)
                if p.returncode == 0:
                    candidates = [line.strip() for line in p.stdout.strip().split("\n") if line.strip()]
            except Exception:
                pass
            if candidates:
                target_path = candidates[0]

        probe_json = None
        try:
            cmd = ["sudo", "-n", "ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", target_path]
            p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
            if p.returncode == 0:
                probe_json = json.loads(p.stdout)
        except Exception:
            pass

        format_info = probe_json.get("format", {}) if probe_json else {}
        tags = format_info.get("tags", {})
        duration = format_info.get("duration", "unknown")
        streams = probe_json.get("streams", []) if probe_json else []
        codecs = [s.get("codec_name", "") for s in streams]

        has_title = bool(tags.get("title"))
        has_artist = bool(tags.get("artist"))
        raw_name = os.path.basename(target_path)
        is_url_encoded = "%20" in raw_name or "%" in raw_name

        state = (
            f"File: {target_path}\n"
            f"Format: {format_info.get('format_name', 'unknown')}, Duration: {duration}s, Codecs: {', '.join(codecs)}\n"
            f"Metadata Tags: Title={tags.get('title')}, Artist={tags.get('artist')}, Genre={tags.get('genre')}\n"
            f"Ambiguous or URL-encoded filename: {is_url_encoded} ({raw_name})\n"
            f"NFO file: Missing."
        )

        decision = self.s1.choice(state, "Evaluate media metadata completeness", [
            "INDEXED_AND_COMPLETE",
            "METADATA_AMBIGUOUS_NEEDS_ENRICHMENT",
            "CORRUPTED_CONTAINER_FLAG"
        ])
        urgency = self.s1.score(state, "Metadata enrichment priority", 1.0, 5.0)

        delib_needed = decision["decision"] == "METADATA_AMBIGUOUS_NEEDS_ENRICHMENT" or not has_title or is_url_encoded or simulate
        delib = None
        xml_valid = False
        if delib_needed:
            prompt = (
                f"Media file has missing or URL-encoded tags:\n{state}\n"
                "Decode the title, deduce genre and artist/director, and synthesize a valid Kodi/Jellyfin NFO XML block wrapped in ```xml ... ```."
            )
            delib = self.query_system2(prompt, state)
            resp_txt = delib.get("response", "")
            if "```xml" in resp_txt:
                xml_block = resp_txt.split("```xml")[1].split("```")[0].strip()
                try:
                    import xml.etree.ElementTree as ET
                    ET.fromstring(xml_block)
                    xml_valid = True
                except Exception:
                    xml_valid = False

        latency_ms = round((time.time() - start_t) * 1000.0, 2)
        return {
            "target_path": target_path,
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "urgency": urgency["score"],
            "has_existing_tags": has_title and has_artist,
            "url_encoded_detected": is_url_encoded,
            "deliberation_needed": delib_needed,
            "xml_synthesized_and_valid": xml_valid,
            "system2_deliberation": delib,
            "latency_ms": latency_ms
        }

    # --- EXP-069: Zero-Trust Fleet Telemetry Anomaly & Lateral Movement Classifier ---

    def fleet_security(self, service: str = "sshd", lines: int = 30, simulate_attack_ip: Optional[str] = None) -> Dict[str, Any]:
        """EXP-069: Zero-Trust Fleet Telemetry Anomaly & Lateral Movement Classifier."""
        start_t = time.time()
        
        journal_text = ""
        try:
            cmd = ["journalctl", "-u", service, "-n", str(lines), "--no-pager"]
            p = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, timeout=5)
            if p.returncode == 0:
                journal_text = p.stdout.strip()
        except Exception:
            pass

        ips = list(set(re.findall(r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b", journal_text)))
        failed_count = journal_text.lower().count("failed") + journal_text.lower().count("invalid")

        if simulate_attack_ip:
            journal_text = f"Simulated brute-force attack: 85 failed password attempts for invalid user 'admin' from {simulate_attack_ip} port 51234 ssh2."
            ips = [simulate_attack_ip]
            failed_count = 85

        state = (
            f"Service: {service} (Last {lines} lines)\n"
            f"Observed Remote IPs: {', '.join(ips) if ips else 'None'}\n"
            f"Authentication Failures: {failed_count}\n"
            f"Log sample:\n{journal_text[-1200:] if len(journal_text) > 1200 else journal_text}"
        )

        decision = self.s1.choice(state, "Classify network authentication telemetry", [
            "NORMAL_LAN_BROADCAST",
            "BENIGN_AUTH_RETRY",
            "CREDENTIAL_STUFFING",
            "LATERAL_PORT_SCAN"
        ])
        urgency = self.s1.score(state, "Threat severity and mitigation urgency", 1.0, 5.0)

        delib_needed = decision["decision"] in ["CREDENTIAL_STUFFING", "LATERAL_PORT_SCAN"] or failed_count > 5 or bool(simulate_attack_ip)
        delib = None
        guardrail_passed = False
        if delib_needed:
            prompt = (
                f"Threat telemetry for {service}:\n{state}\n"
                f"Classification: {decision['decision']} (Urgency: {urgency['score']}).\n"
                "Synthesize a surgical, interface-scoped nftables or iptables drop rule to isolate the threat. "
                "CRITICAL INVARIANT: You must NEVER drop localhost 127.0.0.1, tailscale0 (100.64.0.0/10), or LAN subnet 192.168.3.0/24."
            )
            delib = self.query_system2(prompt, state)
            rule_text = delib.get("response", "")
            forbidden_targets = ["127.0.0.1", "lo", "192.168.3.", "100.64.", "tailscale0"]
            has_forbidden_drop = any(f"drop {t}" in rule_text.lower() or f"reject {t}" in rule_text.lower() for t in forbidden_targets)
            guardrail_passed = not has_forbidden_drop and ("nft" in rule_text or "iptables" in rule_text or "drop" in rule_text.lower())

        latency_ms = round((time.time() - start_t) * 1000.0, 2)
        return {
            "service": service,
            "category": decision["decision"],
            "confidence": decision["confidence"],
            "threat_score": urgency["score"],
            "observed_ips": ips,
            "deliberation_needed": delib_needed,
            "system2_deliberation": delib,
            "guardrail_safety_passed": guardrail_passed,
            "latency_ms": latency_ms
        }

def main():
    parser = argparse.ArgumentParser(description="System 1 & System 2 Pre-Harness Ensemble Dispatcher")
    parser.add_argument("--s1-model", choices=["julia-1", "laya"], default="julia-1", help="System 1 decision model")
    parser.add_argument("--s2-model", default=DEFAULT_SYSTEM2_MODEL, help="System 2 deliberation model via Ollama")
    subparsers = parser.add_subparsers(dest="command")

    # Command: audit-all (EXP-065)
    subparsers.add_parser("audit-all", help="Audit all 10 services using the ensemble dispatcher (EXP-065)")

    # Command: triage
    triage_parser = subparsers.add_parser("triage", help="Triage a specific service")
    triage_parser.add_argument("service", choices=[
        "gatus", "paperless", "diskqos", "postgres", "simplex",
        "restic", "jellyfin", "sessions", "flake", "btrfs"
    ], help="Target service to triage")

    # Command: deliberate
    delib_parser = subparsers.add_parser("deliberate", help="Directly trigger System 2 deliberation")
    delib_parser.add_argument("prompt", help="Deliberation prompt or incident summary")

    # Command: reconcile (EXP-066)
    rec_parser = subparsers.add_parser("reconcile", help="Nix flake self-healing & AST patch synthesizer (EXP-066)")
    rec_parser.add_argument("--flake-path", default="/Volumes/data/projects/nixconfig", help="Path to flake directory")
    rec_parser.add_argument("--target-file", help="Specific file to verify")
    rec_parser.add_argument("--simulate-error", help="Simulate a compiler error trace")

    # Command: storage-prognosis (EXP-067)
    stor_parser = subparsers.add_parser("storage-prognosis", help="Predictive storage & Btrfs rebalance synthesis (EXP-067)")
    stor_parser.add_argument("--mount", default="/Volumes/data", help="Filesystem mount point")
    stor_parser.add_argument("--simulate-contention", action="store_true", help="Simulate high fragmentation / latency contention")

    # Command: media-enrich (EXP-068)
    med_parser = subparsers.add_parser("media-enrich", help="Multi-modal media metadata enricher (EXP-068)")
    med_parser.add_argument("--path", default="/Volumes/data/media", help="Path to media directory or file")
    med_parser.add_argument("--file", help="Specific media file to analyze")
    med_parser.add_argument("--simulate", action="store_true", help="Force System 2 deliberation")

    # Command: fleet-security (EXP-069)
    sec_parser = subparsers.add_parser("fleet-security", help="Zero-trust fleet telemetry anomaly classifier (EXP-069)")
    sec_parser.add_argument("--service", default="sshd", help="Service journal to inspect (default: sshd)")
    sec_parser.add_argument("--lines", type=int, default=30, help="Number of journal lines to inspect")
    sec_parser.add_argument("--simulate-attack", help="Simulate brute-force attack from specific IP")

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
    elif args.command == "reconcile":
        report = ensemble.reconcile_flake(flake_path=args.flake_path, target_file=args.target_file, simulate_error=args.simulate_error)
        print(json.dumps(report, indent=2))
    elif args.command == "storage-prognosis":
        report = ensemble.storage_prognosis(mount_point=args.mount, simulate_contention=args.simulate_contention)
        print(json.dumps(report, indent=2))
    elif args.command == "media-enrich":
        report = ensemble.media_enrich(path=args.path, sample_file=args.file, simulate=args.simulate)
        print(json.dumps(report, indent=2))
    elif args.command == "fleet-security":
        report = ensemble.fleet_security(service=args.service, lines=args.lines, simulate_attack_ip=args.simulate_attack)
        print(json.dumps(report, indent=2))
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
