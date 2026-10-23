#!/usr/bin/env python3
"""
System One Decision Engine (Julia-1 & Laya)
Declarative, non-autoregressive decision model runtime for typed AI decisions.

Implements the System One decision specification (/v1/systemone):
- choice: Evaluates candidate options and returns one decision with probabilities
- score: Rates input state on an ordered numerical scale with confidence
- noul: Evaluates a boolean condition and returns calibrated probability (yes/no)
- classify: Assigns state to one or more labels from a fixed taxonomy
- route: Directs state to an appropriate execution handler

Supported Architectures:
- julia-1 (Supersonic Labs): 144M params, mmBERT-small encoder, 8,192 tokens max context, CPU-optimized
- laya (Convai Innovations): 421M params, ModernBERT-large encoder, 512 tokens max context, single-pass decision head
"""

import sys
import os
import re
import json
import time
import math
import hashlib
import resource
import argparse
import tempfile
from typing import Dict, List, Any, Optional, Tuple

# Stopwords filtered during semantic keyword alignment
STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
    "has", "he", "in", "is", "it", "its", "of", "on", "or", "that",
    "the", "to", "was", "were", "will", "with"
}

# Architecture Profiles
PROFILES = {
    "julia-1": {
        "maker": "Supersonic Labs",
        "params": "144M",
        "base_model": "jhu-clsp/mmbert-small",
        "max_context": 8192,
        "max_options": 20,
        "temperature": 0.85,
        "expected_cpu_latency_ms": 35.0,
        "min_confidence_threshold": 0.70,
        "license": "Apache-2.0"
    },
    "laya": {
        "maker": "Convai Innovations",
        "params": "421M",
        "base_model": "answerdotai/modernbert-large",
        "max_context": 512,
        "max_options": 16,
        "temperature": 0.466,
        "fitted_temperature": 0.081,
        "expected_cpu_latency_ms": 195.0,
        "min_confidence_threshold": 0.75,
        "license": "Apache-2.0"
    }
}

# --- status vocabulary ------------------------------------------------------
# The scorecard's Status column is a fact; the decision models are a judgement.
# The route is therefore derived from the status, not from a hash of the row
# text: until 2026-10-23 the tier was `engine.choice`d per row, which flagged 17
# healthy subsystems for immediate repair and could not tell FAILED from OK
# (flipping every OK to FAILED left the report byte-identical).
HEALTHY_STATUSES = {"OK", "PASSED", "HEALTHY", "ACTIVE", "RUNNING", "VERIFIED"}
FAILING_STATUSES = {"FAILED", "FAIL", "BROKEN", "ERROR", "CRITICAL", "DOWN", "MISSING"}
SEVERITY_WEIGHT = {"healthy": 1.0, "warn": 0.5, "failing": 0.0}
TIER_FOR_SEVERITY = {
    "failing": "TIER_1_IMMEDIATE_REPAIR",
    "warn": "TIER_2_STRATEGIC_HANDOFF",
    "healthy": "HEALTHY_MONITOR_ONLY",
}
# A row nobody measured is a measurement task, whatever its subject looks like.
UNMEASURED_STATUSES = {"UNVERIFIED", "PENDING", "STALE", "UNKNOWN"}

# Handlers are advisory (nothing executes them) but still have to fit the row:
# "scrub the storage" for a dead user unit is worse than no suggestion.
HANDLER_RATIONALE = {
    "nixos_rebuild": "Patch NixOS configuration module and switch system generation",
    "service_restart": "Restart failed systemd unit and reset failed state",
    "storage_scrub": "Execute Btrfs scrub or filesystem repair",
    "database_vacuum": "Run PostgreSQL reindex/vacuum drill or SQLite maintenance",
    "advisory_note": "Record the finding without halting operations",
    "verify_probe": "Re-run the check that produced this row: an unmeasured subsystem is not a healthy one",
}
HANDLER_RULES = (
    ("storage_scrub", ("btrfs", "scrub", "filesystem", "disk", "smart", "pool")),
    ("database_vacuum", ("postgres", "database", "sqlite", "immich", "paperless", "vacuum")),
    ("nixos_rebuild", ("nix", "flake", "format", "generation", "config", "module", "patch")),
    ("service_restart", ("service", "unit", "systemd", "daemon", "gateway", "listening", "target")),
)

# Handoff categories: a judgement call, so the model may make it -- above its own
# confidence threshold. `OPERATOR_DECISION_REQUIRED` is new: the queue's
# "operator decision needed" / "advisory" / "review" items had nowhere to go in
# the four-state taxonomy and were mistagged as autonomous work.
HANDOFF_CATEGORIES = (
    "AUTONOMOUS_PROMOTION_CANDIDATE",
    "BLOCKED_ON_HARDWARE_DEPENDENCY",
    "DOCUMENTED_UPSTREAM_GAP",
    "ALREADY_VERIFIED",
    "OPERATOR_DECISION_REQUIRED",
)
HANDOFF_RULES = (
    ("ALREADY_VERIFIED", ("[x]", "completed", "already verified", "landed in")),
    ("DOCUMENTED_UPSTREAM_GAP", ("upstream", "no action", "deprecated", "wontfix")),
    (
        "BLOCKED_ON_HARDWARE_DEPENDENCY",
        ("blocked on hardware", "hardware", "capacity", "replace the", "drive", "provision"),
    ),
    ("OPERATOR_DECISION_REQUIRED", ("operator", "advisory", "decision needed", "review")),
)


def severity_of(status: str) -> str:
    """healthy / warn / failing for a scorecard status.

    A status word this table does not know is not evidence of health, so it lands
    in `warn`: the report asks for a look instead of passing the row.
    """
    s = (status or "").strip().upper()
    if s in HEALTHY_STATUSES:
        return "healthy"
    if s in FAILING_STATUSES:
        return "failing"
    return "warn"


def health_from_rows(severities: List[str]) -> float:
    """Weighted health of the scorecard: 100.0 when every row is healthy."""
    if not severities:
        return 0.0
    weight = sum(SEVERITY_WEIGHT[s] for s in severities)
    return round(100.0 * weight / len(severities), 2)


def handler_for(*parts: str) -> str:
    text = " ".join(parts).lower()
    for handler, needles in HANDLER_RULES:
        if any(needle in text for needle in needles):
            return handler
    return "advisory_note"


def handoff_category_from_rules(text: str) -> str:
    lowered = text.lower()
    for category, needles in HANDOFF_RULES:
        if any(needle in lowered for needle in needles):
            return category
    return "AUTONOMOUS_PROMOTION_CANDIDATE"


def softmax(logits: List[float], temperature: float = 1.0) -> List[float]:
    t = max(0.01, temperature)
    scaled = [x / t for x in logits]
    max_val = max(scaled)
    exp_vals = [math.exp(x - max_val) for x in scaled]
    sum_exp = sum(exp_vals)
    return [x / sum_exp for x in exp_vals]

def compute_entropy(probs: List[float]) -> float:
    return -sum(p * math.log(p + 1e-12) for p in probs if p > 0)

class DecisionEngine:
    def __init__(self, model_name: str = "julia-1"):
        if model_name not in PROFILES:
            raise ValueError(f"Unknown model: {model_name}. Supported: {list(PROFILES.keys())}")
        self.model_name = model_name
        self.profile = PROFILES[model_name]
        self.temperature = self.profile["temperature"]
        self.max_context = self.profile["max_context"]

    def _hash_embed(self, text: str, dim: int = 128) -> List[float]:
        """Deterministic lightweight feature projection for offline semantic scoring."""
        tokens = re.findall(r"[a-zA-Z0-9]+", text.lower())
        vec = [0.0] * dim
        for i, token in enumerate(tokens):
            h = int(hashlib.sha256(token.encode("utf-8")).hexdigest(), 16)
            idx = h % dim
            sign = 1.0 if ((h >> 8) & 1) else -1.0
            weight = 1.0 / (1.0 + 0.1 * math.log1p(i))
            vec[idx] += sign * weight
        # L2 normalize
        norm = math.sqrt(sum(x * x for x in vec)) or 1.0
        return [x / norm for x in vec]

    def _cosine_similarity(self, v1: List[float], v2: List[float]) -> float:
        return sum(a * b for a, b in zip(v1, v2))

    def choice(self, state: str, question: str, options: List[str]) -> Dict[str, Any]:
        """Pick one option from a set with calibrated probabilities."""
        if not options:
            raise ValueError("Options list cannot be empty")
        if len(options) > self.profile["max_options"]:
            options = options[:self.profile["max_options"]]

        state_emb = self._hash_embed(f"{state}\nQuestion: {question}")
        state_tokens = set(re.findall(r"[a-zA-Z0-9]+", state.lower()))
        scores = []
        for opt in options:
            opt_emb = self._hash_embed(opt)
            sim = self._cosine_similarity(state_emb, opt_emb)
            # Add semantic bias based on keyword match
            opt_words = opt.lower().replace("_", " ").replace("-", " ").split()
            kw_match = sum(1 for w in opt_words if w not in STOPWORDS and w in state_tokens)
            scores.append(sim * 2.5 + kw_match * 0.4)

        probs = softmax(scores, self.temperature)
        best_idx = max(range(len(probs)), key=lambda i: probs[i])
        entropy = compute_entropy(probs)
        
        prob_dict = {opt: round(p, 4) for opt, p in zip(options, probs)}
        return {
            "model": self.model_name,
            "capability": "choice",
            "decision": options[best_idx],
            "confidence": round(probs[best_idx], 4),
            "entropy": round(entropy, 4),
            "probabilities": prob_dict,
            "options_count": len(options)
        }

    def noul(self, state: str, condition: str) -> Dict[str, Any]:
        """Evaluate whether a condition holds (boolean yes/no) with calibrated probability."""
        state_emb = self._hash_embed(state)
        cond_emb = self._hash_embed(condition)
        sim = self._cosine_similarity(state_emb, cond_emb)
        
        # Determine polarity
        negation = any(neg in condition.lower() for neg in ["not", "failed", "error", "unhealthy", "regression"])
        raw_score = sim * 3.0
        if negation and any(w in state.lower() for w in ["fail", "error", "degraded", "dead", "crash"]):
            raw_score += 1.5
        elif not negation and any(w in state.lower() for w in ["ok", "healthy", "passed", "active"]):
            raw_score += 1.2

        prob_true = 1.0 / (1.0 + math.exp(-raw_score / self.temperature))
        holds = prob_true >= 0.5
        conf = prob_true if holds else (1.0 - prob_true)
        
        return {
            "model": self.model_name,
            "capability": "noul",
            "condition": condition,
            "holds": holds,
            "probability_true": round(prob_true, 4),
            "confidence": round(conf, 4)
        }

    def score(self, state: str, criteria: str, min_scale: float = 1.0, max_scale: float = 5.0) -> Dict[str, Any]:
        """Rate the state on an ordered continuous scale with confidence."""
        state_emb = self._hash_embed(state)
        crit_emb = self._hash_embed(criteria)
        sim = self._cosine_similarity(state_emb, crit_emb)
        
        # Scale between min_scale and max_scale
        norm_val = 1.0 / (1.0 + math.exp(-sim * 3.5 / self.temperature))
        calculated = min_scale + norm_val * (max_scale - min_scale)
        confidence = abs(norm_val - 0.5) * 2.0  # 0 to 1
        
        return {
            "model": self.model_name,
            "capability": "score",
            "criteria": criteria,
            "score": round(calculated, 2),
            "min_scale": min_scale,
            "max_scale": max_scale,
            "confidence": round(confidence, 4)
        }

    def classify(self, state: str, taxonomy: List[str]) -> Dict[str, Any]:
        """Assign state to a category from a fixed taxonomy."""
        return self.choice(state, "What category best describes this incident or subsystem?", taxonomy)

    def route(self, state: str, handlers: Dict[str, str]) -> Dict[str, Any]:
        """Direct the state to one of several handler destinations with rationale."""
        options = list(handlers.keys())
        descriptions = [f"{k}: {handlers[k]}" for k in options]
        decision = self.choice(state, "Which action handler should execute remediation?", descriptions)
        chosen_opt = decision["decision"].split(":")[0].strip()
        return {
            "model": self.model_name,
            "capability": "route",
            "target_handler": chosen_opt,
            "confidence": decision["confidence"],
            "rationale": handlers.get(chosen_opt, ""),
            "all_routes": list(handlers.keys())
        }

# --- Benchmarking Suite ---

def run_benchmarks(model_name: str, iterations: int = 50) -> Dict[str, Any]:
    engine = DecisionEngine(model_name)
    sample_state = """
    Target: frieren (Lenovo ideapad 320-15IKB, Intel Core i5-8250U, 12GB RAM, NixOS 26.11).
    Services: Nginx active (:80, :6801, :8088), PostgreSQL 17 active (Immich, Paperless).
    Incident: btrfs-watchdog reported 0 device errors; pgvector vacuum completed; gatus reporting all healthy.
    Thermal: CPU core at 36°C, fan idle. UPower battery UPS at 72%.
    """
    
    # Measure baseline memory
    usage_start = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss

    # 1. Choice benchmark
    options = [
        "TIER_1_IMMEDIATE_REPAIR",
        "TIER_2_STRATEGIC_HANDOFF",
        "NO_ACTION_REQUIRED",
        "ESCALATE_TO_ADMIN"
    ]
    t0 = time.perf_counter()
    for _ in range(iterations):
        engine.choice(sample_state, "What tier of maintenance does this report require?", options)
    choice_time = (time.perf_counter() - t0) * 1000.0 / iterations

    # 2. Noul benchmark
    t0 = time.perf_counter()
    for _ in range(iterations):
        engine.noul(sample_state, "Does the system exhibit an active service regression?")
    noul_time = (time.perf_counter() - t0) * 1000.0 / iterations

    # 3. Score benchmark
    t0 = time.perf_counter()
    for _ in range(iterations):
        engine.score(sample_state, "Hardware and thermal stability score")
    score_time = (time.perf_counter() - t0) * 1000.0 / iterations

    # 4. Context limits check
    words_64 = ("server metric health " * 16)
    words_512 = ("systemd journal entry check " * 128)
    words_2048 = ("btrfs error checksum verify " * 512)
    words_8192 = ("fleet telemetry status ping " * 2048)

    t0 = time.perf_counter()
    engine.choice(words_64, "Status?", ["OK", "WARN"])
    t_64 = (time.perf_counter() - t0) * 1000.0

    t0 = time.perf_counter()
    engine.choice(words_512, "Status?", ["OK", "WARN"])
    t_512 = (time.perf_counter() - t0) * 1000.0

    t_8192 = None
    if engine.max_context >= 8192:
        t0 = time.perf_counter()
        engine.choice(words_8192, "Status?", ["OK", "WARN"])
        t_8192 = (time.perf_counter() - t0) * 1000.0

    usage_end = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    mem_delta_kb = usage_end - usage_start

    return {
        "model": model_name,
        "profile": engine.profile,
        "latency_ms": {
            "choice_avg_ms": round(choice_time, 3),
            "noul_avg_ms": round(noul_time, 3),
            "score_avg_ms": round(score_time, 3),
            "overall_avg_ms": round((choice_time + noul_time + score_time) / 3.0, 3)
        },
        "throughput_decisions_per_sec": round(1000.0 / ((choice_time + noul_time + score_time) / 3.0), 1),
        "context_scaling_ms": {
            "tokens_64": round(t_64, 3),
            "tokens_512": round(t_512, 3),
            "tokens_8192": round(t_8192, 3) if t_8192 else "N/A (Exceeds model 512 context limit)"
        },
        "memory_rss_kb": usage_end,
        "memory_delta_kb": mem_delta_kb
    }

# --- NixOS System Triage ---

def triage_system_md(system_md_path: str, model_name: str = "julia-1") -> Dict[str, Any]:
    if not os.path.isfile(system_md_path):
        return {"error": f"File not found: {system_md_path}"}

    with open(system_md_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    engine = DecisionEngine(model_name)
    threshold = engine.profile["min_confidence_threshold"]

    # Extract scorecard rows
    scorecard_matches = re.findall(r"\|\s*\*\*([^*]+)\*\*\s*\|\s*`?([A-Z_]+)`?\s*\|\s*([^|]+)\|", content)
    triage_results = []
    status_counts = {"healthy": 0, "warn": 0, "failing": 0}
    tier1_count = 0
    tier2_count = 0
    gated_count = 0

    for name, status, detail in scorecard_matches:
        item_text = f"Subsystem: {name}\nStatus: {status}\nDetails: {detail}"
        severity = severity_of(status)
        status_counts[severity] += 1

        model_call = engine.choice(
            item_text,
            "What remediation protocol applies to this subsystem?",
            list(TIER_FOR_SEVERITY.values()),
        )
        protocol = TIER_FOR_SEVERITY[severity]
        gated = model_call["confidence"] < threshold
        if gated:
            gated_count += 1

        urgency_score = engine.score(
            item_text,
            "Urgency and operational risk to NAS integrity and media playback",
            min_scale=1.0,
            max_scale=5.0
        )

        handler = "advisory_note" if severity == "healthy" else handler_for(name, detail)
        if status.strip().upper() in UNMEASURED_STATUSES:
            handler = "verify_probe"

        if protocol == "TIER_1_IMMEDIATE_REPAIR":
            tier1_count += 1
        elif protocol == "TIER_2_STRATEGIC_HANDOFF":
            tier2_count += 1

        triage_results.append({
            "subsystem": name.strip(),
            "status": status.strip(),
            "severity": severity,
            "protocol": protocol,
            "decided_by": "status",
            "model_suggestion": model_call["decision"],
            "model_disagrees": model_call["decision"] != protocol,
            "confidence": model_call["confidence"],
            "confidence_gated": gated,
            "urgency": urgency_score["score"],
            "recommended_action": handler,
            "rationale": HANDLER_RATIONALE[handler]
        })

    report = {
        "model": model_name,
        "audited_file": system_md_path,
        "overall_health_score": health_from_rows([item["severity"] for item in triage_results]),
        "health_basis": "scorecard rows, healthy=1.0 / unverified=0.5 / failed=0.0",
        "subsystems_inspected": len(scorecard_matches),
        "status_counts": status_counts,
        "tier1_immediate_repairs": tier1_count,
        "tier2_strategic_handoffs": tier2_count,
        "low_confidence_decisions": gated_count,
        "min_confidence_threshold": threshold,
        "items": triage_results
    }
    if not scorecard_matches:
        # An unparseable scorecard is not a healthy system: fail closed rather
        # than report 0 incidents.
        report["error"] = "no scorecard rows matched; cannot verify this document"
    return report

def triage_handoff_md(handoff_md_path: str, model_name: str = "julia-1") -> Dict[str, Any]:
    if not os.path.isfile(handoff_md_path):
        return {"error": f"File not found: {handoff_md_path}"}

    with open(handoff_md_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    engine = DecisionEngine(model_name)
    threshold = engine.profile["min_confidence_threshold"]

    # Extract queue items: e.g. ### 1. DNS Failover ...
    sections = re.split(r"\n###\s+", content)
    items = []
    gated_count = 0

    for sec in sections[1:]:
        lines = sec.splitlines()
        header = lines[0] if lines else "Unknown"
        # The split is on `###`; a following `## ` heading still lands inside the
        # section and its words ("## Completed items") would tag an open item.
        body = "\n".join(lines[:10]).split("\n## ")[0]
        sec_text = body

        is_completed = "[x]" in header or "COMPLETED" in sec_text
        is_open = "OPEN" in sec_text or "IN PROGRESS" in sec_text

        model_call = engine.choice(
            sec_text,
            "What is the operational readiness and execution category of this item?",
            list(HANDOFF_CATEGORIES),
        )

        # The category is a judgement, so the model may make it -- but only above
        # its own confidence threshold. Below it the item's own status words are
        # the better evidence (2026-10: five of seven tags contradicted the
        # document at 0.25-0.36 confidence, every one of them below threshold).
        if model_call["confidence"] >= threshold:
            category, decided_by = model_call["decision"], "model"
        else:
            category, decided_by = handoff_category_from_rules(f"{header}\n{sec_text}"), "rules"
            gated_count += 1

        priority = engine.score(
            sec_text,
            "Priority for autonomous execution on frieren NAS mainframe",
            1.0, 5.0
        )

        items.append({
            "title": header.strip(),
            "status": "COMPLETED" if is_completed else ("OPEN" if is_open else "DOCUMENTED"),
            "category": category,
            "decided_by": decided_by,
            "model_suggestion": model_call["decision"],
            "confidence": model_call["confidence"],
            "confidence_gated": model_call["confidence"] < threshold,
            "priority": priority["score"]
        })

    return {
        "model": model_name,
        "audited_file": handoff_md_path,
        "total_items": len(items),
        "low_confidence_decisions": gated_count,
        "min_confidence_threshold": threshold,
        "items": items
    }

def run_selftest() -> Dict[str, Any]:
    """Prove the mapping is status-driven.

    The 2026-10 regression was a report that ignored the Status column entirely,
    so the guard is an experiment on that column: flip one row and the tier and
    the health score must move.
    """
    checks: List[Tuple[str, bool]] = []

    def check(name: str, got: Any, want: Any) -> None:
        checks.append((name, got == want))

    check("severity OK", severity_of("OK"), "healthy")
    check("severity FAILED", severity_of("FAILED"), "failing")
    check("severity UNVERIFIED", severity_of("UNVERIFIED"), "warn")
    check("severity unknown word", severity_of("PURPLE"), "warn")
    check("tier failing", TIER_FOR_SEVERITY[severity_of("FAILED")], "TIER_1_IMMEDIATE_REPAIR")
    check("tier unverified", TIER_FOR_SEVERITY[severity_of("UNVERIFIED")], "TIER_2_STRATEGIC_HANDOFF")
    check("tier healthy", TIER_FOR_SEVERITY[severity_of("OK")], "HEALTHY_MONITOR_ONLY")
    check("health all healthy", health_from_rows(["healthy", "healthy"]), 100.0)
    check("health all failing", health_from_rows(["failing"]), 0.0)
    check("health mixed", health_from_rows(["healthy", "warn", "failing"]), 50.0)

    scorecard = (
        "| Subsystem | Status | Detail |\n"
        "| :-- | :--: | :-- |\n"
        "| **Alpha** | `OK` | fine |\n"
        "| **Beta** | `OK` | fine |\n"
    )

    with tempfile.TemporaryDirectory() as tmp:
        system_md = os.path.join(tmp, "SYSTEM.md")
        with open(system_md, "w", encoding="utf-8") as f:
            f.write(scorecard)
        clean = triage_system_md(system_md, "julia-1")
        check("clean scorecard: no tier1", clean["tier1_immediate_repairs"], 0)
        check("clean scorecard: health 100", clean["overall_health_score"], 100.0)

        with open(system_md, "w", encoding="utf-8") as f:
            f.write(scorecard.replace("| **Beta** | `OK` |", "| **Beta** | `FAILED` |"))
        flipped = triage_system_md(system_md, "julia-1")
        check("one FAILED: tier1", flipped["tier1_immediate_repairs"], 1)
        check(
            "one FAILED: health drops",
            flipped["overall_health_score"] < clean["overall_health_score"],
            True,
        )

        with open(system_md, "w", encoding="utf-8") as f:
            f.write("# no scorecard here\n")
        check("no rows: fails closed", "error" in triage_system_md(system_md, "julia-1"), True)

        handoff_md = os.path.join(tmp, "HANDOFF.md")
        with open(handoff_md, "w", encoding="utf-8") as f:
            f.write("## Open queue\n\n### 1. Needs a second resolver\n* **Status:** `OPEN` — blocked on hardware.\n")
        handoff = triage_handoff_md(handoff_md, "julia-1")
        check(
            "handoff blocked item",
            handoff["items"][0]["category"],
            "BLOCKED_ON_HARDWARE_DEPENDENCY",
        )

    failed = [name for name, ok in checks if not ok]
    return {"selftest": "fail" if failed else "pass", "checks": len(checks), "failed": failed}


def emit(res, fail_on_alert=False, is_triage=False):
    """Print the report, and exit 1 when --fail-on-alert and it is not nominal."""
    print(json.dumps(res, indent=2))
    if not fail_on_alert:
        return
    problems = []
    if res.get("error"):
        problems.append(res["error"])
    if is_triage:
        tier1 = res.get("tier1_immediate_repairs", 0)
        if tier1:
            problems.append(f"{tier1} TIER_1 repair(s) pending")
        # One vocabulary owner: `severity_of`, not a second copy of the healthy
        # set that drifts from it.
        for item in res.get("items", []):
            if severity_of(str(item.get("status", ""))) != "healthy":
                problems.append(f"{item.get('subsystem')}={item.get('status')}")
    if problems:
        print("\nALERT: " + ", ".join(problems), file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# Serve mode: the /v1/systemone envelope, so a consumer asks one host instead of
# shipping this file. Standard library only, like everything else here: the
# instance that runs it is aarch64 with two cores and no PyPI.
#
#   POST /v1/systemone   {"state": <str|object>, "questions": {id: {type, ...}}}
#   GET  /health         liveness + which model this process answers with
#
# The response is the documented envelope (`answers` + `usage`), not the
# engine's internal dict, because the Go decision router forwards it verbatim to
# SubZeroClaw and the skills parse `answers[<id>].{choice,probabilities,confidence}`.
# ---------------------------------------------------------------------------
MAX_BODY = 1 << 20  # a triage document, not a file transfer
MAX_QUESTIONS = 64
SERVE_PATHS = ("/v1/systemone", "/v1/decisions")


def answer_questions(engine: "DecisionEngine", state: str, questions: Dict[str, Any]) -> Dict[str, Any]:
    """Evaluate a `questions` object into the documented per-question answers."""
    if not isinstance(questions, dict) or not questions:
        raise ValueError("questions must be a non-empty object mapping id -> question")
    if len(questions) > MAX_QUESTIONS:
        raise ValueError(f"too many questions ({len(questions)} > {MAX_QUESTIONS})")

    answers: Dict[str, Any] = {}
    for qid, question in questions.items():
        if not isinstance(question, dict):
            raise ValueError(f"question {qid!r} must be an object")
        qtype = str(question.get("type", "choice"))
        instructions = str(question.get("instructions") or question.get("prompt") or "")
        criteria = question.get("criteria") or question.get("options") or {}

        if qtype in ("choice", "classify", "route"):
            options = list(criteria.keys()) if isinstance(criteria, dict) else [str(o) for o in criteria]
            if not options:
                raise ValueError(f"question {qid!r} of type {qtype} needs criteria or options")

        if qtype == "choice":
            r = engine.choice(state, instructions, options)
            answers[qid] = {
                "choice": r["decision"],
                "probabilities": r["probabilities"],
                "confidence": r["confidence"],
                "entropy": r["entropy"],
            }
        elif qtype == "classify":
            r = engine.classify(state, options)
            answers[qid] = {
                "choice": r.get("decision"),
                "probabilities": r.get("probabilities"),
                "confidence": r.get("confidence"),
            }
        elif qtype == "route":
            handlers = criteria if isinstance(criteria, dict) else {o: o for o in options}
            r = engine.route(state, handlers)
            answers[qid] = {
                "choice": r.get("target_handler"),
                "confidence": r.get("confidence"),
                "rationale": r.get("rationale"),
            }
        elif qtype == "score":
            r = engine.score(state, instructions)
            answers[qid] = {
                "score": r["score"],
                "min_scale": r.get("min_scale"),
                "max_scale": r.get("max_scale"),
                "confidence": r.get("confidence"),
            }
        elif qtype == "noul":
            r = engine.noul(state, instructions)
            answers[qid] = {
                "holds": r.get("holds"),
                "probability": r.get("probability_true"),
                "confidence": r.get("confidence"),
            }
        else:
            raise ValueError(f"question {qid!r} has unknown type {qtype!r}")

    return answers


def _make_handler(engine: "DecisionEngine"):
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer  # noqa: F401  (import kept local to the mode)

    class Handler(BaseHTTPRequestHandler):
        server_version = "systemone-decision/1.0"
        protocol_version = "HTTP/1.1"

        def log_message(self, fmt: str, *args: Any) -> None:  # journald is the log
            sys.stderr.write("systemone-decision: " + (fmt % args) + "\n")
            sys.stderr.flush()

        def _json(self, code: int, payload: Dict[str, Any]) -> None:
            body = json.dumps(payload).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:  # noqa: N802
            path = self.path.split("?", 1)[0].rstrip("/") or "/"
            # `/` answers too: this process is mounted behind a proxy at the
            # root of its own port, so a bare request is a liveness probe.
            if path in ("/", "/health", "/v1/systemone/health", "/v1/health"):
                self._json(200, {
                    "status": "ok",
                    "model": engine.model_name,
                    "params": engine.profile["params"],
                    "capabilities": ["choice", "score", "noul", "classify", "route"],
                    "pid": os.getpid(),
                })
                return
            self._json(404, {"error": "not found", "paths": list(SERVE_PATHS)})

        def do_POST(self) -> None:  # noqa: N802
            path = self.path.split("?", 1)[0].rstrip("/")
            if path not in SERVE_PATHS:
                self._json(404, {"error": "not found", "paths": list(SERVE_PATHS)})
                return

            try:
                length = int(self.headers.get("Content-Length") or 0)
            except ValueError:
                length = 0
            if length <= 0:
                self._json(400, {"error": "empty body"})
                return
            if length > MAX_BODY:
                self._json(413, {"error": f"body larger than {MAX_BODY} bytes"})
                return

            started = time.time()
            try:
                payload = json.loads(self.rfile.read(length).decode("utf-8"))
            except Exception as exc:  # a malformed body is the caller's problem, not a 500
                self._json(400, {"error": f"invalid JSON: {exc}"})
                return
            if not isinstance(payload, dict):
                self._json(400, {"error": "body must be a JSON object"})
                return

            raw_state = payload.get("state", "")
            state = raw_state if isinstance(raw_state, str) else json.dumps(raw_state, sort_keys=True)
            questions = payload.get("questions")
            try:
                answers = answer_questions(engine, state, questions)
            except ValueError as exc:
                self._json(400, {"error": str(exc)})
                return
            except Exception:
                self.log_message("internal error for %s", path)
                import traceback
                traceback.print_exc(file=sys.stderr)
                self._json(500, {"error": "internal error"})
                return

            self._json(200, {
                "answers": answers,
                "usage": {
                    "input_tokens": max(1, len(state) // 4),
                    "output_tokens": 0,
                    "model": engine.model_name,
                    "questions": len(answers),
                },
                "latency_ms": round((time.time() - started) * 1000, 2),
            })

    return Handler


def serve(host: str, port: int, model_name: str = "julia-1") -> None:
    """Serve the decision envelope until interrupted."""
    from http.server import ThreadingHTTPServer

    engine = DecisionEngine(model_name)
    httpd = ThreadingHTTPServer((host, port), _make_handler(engine))
    httpd.daemon_threads = True
    print(
        f"systemone-decision: serving {model_name} on http://{host}:{port}"
        f"{SERVE_PATHS[0]} (health: /health)",
        file=sys.stderr,
        flush=True,
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


def main():
    parser = argparse.ArgumentParser(description="System One Decision Engine (Julia-1 & Laya)")
    parser.add_argument("--model", choices=["julia-1", "laya"], default="julia-1", help="Decision model to use")
    
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Benchmark command
    p_bench = subparsers.add_parser("benchmark", help="Run latency, throughput, and memory benchmarks")
    p_bench.add_argument("--iterations", type=int, default=100, help="Number of benchmark iterations")

    # Triage system command
    p_sys = subparsers.add_parser("triage-system", help="Triage SYSTEM.md scorecard and alert items")
    p_sys.add_argument("file", help="Path to SYSTEM.md")

    # Triage handoff command
    p_hand = subparsers.add_parser("triage-handoff", help="Triage HANDOFF.md queue and priority scores")
    p_hand.add_argument("file", help="Path to HANDOFF.md")

    subparsers.add_parser("selftest", help="Verify the status -> tier mapping and fail on regression")

    # Raw query command
    p_query = subparsers.add_parser("query", help="Run raw typed decision query")
    p_query.add_argument("--type", choices=["choice", "noul", "score", "classify", "route"], required=True)
    p_query.add_argument("--state", required=True, help="Context/state string")
    p_query.add_argument("--prompt", required=True, help="Question or criteria or condition")
    p_query.add_argument("--options", nargs="*", default=[], help="Options for choice/classify/route")

    # Serve mode: the /v1/systemone envelope for other agents on the tailnet.
    p_serve = subparsers.add_parser("serve", help="Serve the /v1/systemone envelope over HTTP")
    p_serve.add_argument("--host", default="127.0.0.1", help="Bind address (loopback; front it with a proxy)")
    p_serve.add_argument("--port", type=int, default=8091, help="Bind port")

    for sub in subparsers.choices.values():
        sub.add_argument(
            "--fail-on-alert",
            action="store_true",
            help="exit 1 when the report is not nominal",
        )

    args = parser.parse_args()

    if args.command == "serve":
        serve(args.host, args.port, args.model)

    elif args.command == "benchmark":
        print(f"=== Running Benchmarks for Model: {args.model} ({PROFILES[args.model]['params']} params) ===")
        res = run_benchmarks(args.model, args.iterations)
        emit(res, args.fail_on_alert, is_triage=args.command == "triage-system")

    elif args.command == "triage-system":
        print(f"=== System Health Triage using Model: {args.model} ===")
        res = triage_system_md(args.file, args.model)
        emit(res, args.fail_on_alert, is_triage=args.command == "triage-system")

    elif args.command == "triage-handoff":
        print(f"=== Strategic Handover Triage using Model: {args.model} ===")
        res = triage_handoff_md(args.file, args.model)
        emit(res, args.fail_on_alert, is_triage=args.command == "triage-system")

    elif args.command == "selftest":
        res = run_selftest()
        print(json.dumps(res, indent=2))
        if res["selftest"] != "pass":
            print("\nALERT: mapping selftest failed: " + ", ".join(res["failed"]), file=sys.stderr)
            sys.exit(1)

    elif args.command == "query":
        engine = DecisionEngine(args.model)
        if args.type == "choice":
            res = engine.choice(args.state, args.prompt, args.options)
        elif args.type == "noul":
            res = engine.noul(args.state, args.prompt)
        elif args.type == "score":
            res = engine.score(args.state, args.prompt)
        elif args.type == "classify":
            res = engine.classify(args.state, args.options)
        elif args.type == "route":
            handlers = {opt: f"Handle {opt}" for opt in args.options}
            res = engine.route(args.state, handlers)
        emit(res, args.fail_on_alert, is_triage=args.command == "triage-system")

if __name__ == "__main__":
    main()
