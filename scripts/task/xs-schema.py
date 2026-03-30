#!/usr/bin/env python3
"""Auxiliary schema helper for xs-helper Phase 3 events."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, Mapping, Optional

XS_BIN = os.environ.get("XS_SCHEMA_BIN", "xs")
XS_ADDR = os.environ.get("XS_SCHEMA_ADDR")


def load_payload(path: str) -> Mapping[str, Any]:
    text = Path(path).read_text(encoding="utf-8")
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"file {path} is not valid JSON: {exc}") from exc


def normalize(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {k: normalize(value[k]) for k in sorted(value)}
    if isinstance(value, list):
        return [normalize(item) for item in value]
    if isinstance(value, str):
        return value
    if isinstance(value, (int, float, bool)) or value is None:
        return value
    return str(value)


def stable_serialize(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def digest(value: Any) -> str:
    normalized = normalize(value)
    serialized = stable_serialize(normalized).encode("utf-8")
    return hashlib.sha256(serialized).hexdigest()


def prefixed_id(prefix: str, raw: str) -> str:
    return f"{prefix}:{raw[:20]}"


def ensure_prefixed(value: str, prefix: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError(f"{prefix} identifier cannot be empty")
    if stripped.startswith(f"{prefix}:"):
        return stripped
    return f"{prefix}:{stripped}"


def fetch_hash_payload(hash_value: Optional[str]) -> Optional[Any]:
    if not hash_value or not XS_ADDR:
        return None
    try:
        result = subprocess.run(
            [XS_BIN, "cas", XS_ADDR, hash_value],
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


def extract_payload(obj: Any) -> Any:
    if isinstance(obj, str):
        try:
            return json.loads(obj)
        except json.JSONDecodeError:
            return obj
    if isinstance(obj, Mapping):
        if "kind" in obj or "record_id" in obj or "contract_id" in obj:
            return obj
        if "hash" in obj:
            fetched = fetch_hash_payload(obj.get("hash"))
            if fetched is not None:
                return extract_payload(fetched)
        for key in ("payload", "content", "body", "data", "frame"):
            if key in obj:
                return extract_payload(obj[key])
        return obj
    return obj


def frame_topic(frame: Mapping[str, Any], payload: Mapping[str, Any]) -> Optional[str]:
    if payload is not None:
        topic = payload.get("topic")
        if isinstance(topic, str) and topic:
            return topic
    topic = frame.get("topic")
    if isinstance(topic, str) and topic:
        return topic
    meta = frame.get("meta")
    if isinstance(meta, Mapping):
        topic = meta.get("topic")
        if isinstance(topic, str) and topic:
            return topic
    frame_meta = frame.get("frame")
    if isinstance(frame_meta, Mapping):
        topic = frame_meta.get("topic")
        if isinstance(topic, str) and topic:
            return topic
    return None


def read_frames() -> Iterable[Mapping[str, Any]]:
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            candidate = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(candidate, Mapping):
            yield candidate


def output_event(event: Mapping[str, Any]) -> None:
    print(json.dumps(event, sort_keys=True))


def command_define_contract(args: argparse.Namespace) -> None:
    data = dict(load_payload(args.input))
    packet_id = data.get("packet_id")
    if not isinstance(packet_id, str) or not packet_id.strip():
        raise SystemExit("contract definition requires a packet_id field")
    pkt_id = ensure_prefixed(packet_id, "pkt")

    projection = data.get("projection")
    if projection is None:
        raise SystemExit("contract definition requires a projection field")
    projection_norm = normalize(projection)
    projection_digest = digest(projection_norm)
    prj_id = prefixed_id("prj", projection_digest)

    executor = normalize(data.get("executor", {}))
    executor_digest = digest(executor)
    exe_id = prefixed_id("exe", executor_digest)

    contract_metadata = normalize(data.get("contract", {}))
    extras = {k: normalize(v) for k, v in sorted(data.items()) if k not in {"packet_id", "projection", "executor", "contract"}}

    contract_seed = {
        "topic": args.topic,
        "packet": pkt_id,
        "projection": prj_id,
        "executor": exe_id,
        "contract": contract_metadata,
        "extras": extras,
    }
    contract_digest = digest(contract_seed)
    ctr_id = prefixed_id("ctr", contract_digest)

    event = {
        "kind": "contract.define",
        "topic": args.topic,
        "contract_id": ctr_id,
        "ctr": ctr_id,
        "packet_id": packet_id,
        "pkt": pkt_id,
        "projection_digest": prj_id,
        "prj": prj_id,
        "executor_id": exe_id,
        "exe": exe_id,
        "projection": projection_norm,
        "executor": executor,
        "contract": contract_metadata,
        "extras": extras,
        "timestamp": args.timestamp,
        "producer": args.producer,
    }
    output_event(event)


def resolve_record_fields(data: Mapping[str, Any]) -> Dict[str, Any]:
    contract_id = data.get("contract_id")
    if not isinstance(contract_id, str) or not contract_id.strip():
        raise SystemExit("record requires a contract_id")
    contract_id = ensure_prefixed(contract_id, "ctr")
    packet_id = data.get("packet_id")
    if not isinstance(packet_id, str) or not packet_id.strip():
        raise SystemExit("record requires a packet_id")
    pkt_id = ensure_prefixed(packet_id, "pkt")

    projection_digest = data.get("projection_digest")
    projection_norm = None
    if isinstance(projection_digest, str) and projection_digest.strip():
        prj_id = ensure_prefixed(projection_digest, "prj")
    else:
        projection = data.get("projection")
        if projection is None:
            raise SystemExit("record requires a projection or projection_digest")
        projection_norm = normalize(projection)
        prj_id = prefixed_id("prj", digest(projection_norm))
    record_payload = data.get("payload")
    if record_payload is None:
        raise SystemExit("record requires a payload")
    payload_norm = normalize(record_payload)

    executor = normalize(data.get("executor", {}))

    trace_data = data.get("trace")
    normalized_trace = normalize(trace_data) if trace_data is not None else None

    extras = {
        k: normalize(v)
        for k, v in sorted(data.items())
        if k
        not in {
            "contract_id",
            "packet_id",
            "projection",
            "projection_digest",
            "payload",
            "executor",
            "trace",
        }
    }

    return {
        "contract_id": contract_id,
        "packet_id": packet_id,
        "pkt": pkt_id,
        "projection_digest": prj_id,
        "projection": projection_norm,
        "payload": payload_norm,
        "executor": executor,
        "trace": normalized_trace,
        "extras": extras,
    }


def command_emit_record(args: argparse.Namespace) -> None:
    data = load_payload(args.input)
    fields = resolve_record_fields(data)
    executor_digest = digest(fields["executor"])
    exe_id = prefixed_id("exe", executor_digest)

    record_seed = {
        "contract_id": fields["contract_id"],
        "packet_id": fields["pkt"],
        "payload": fields["payload"],
        "projection": fields["projection_digest"],
        "executor": exe_id,
        "trace": fields["trace"],
        "extras": fields["extras"],
        "status": args.status,
    }
    rec_id = prefixed_id("rec", digest(record_seed))

    event = {
        "kind": "record.append" if args.status == "append" else "record.fail",
        "topic": args.topic,
        "record_id": rec_id,
        "rec": rec_id,
        "contract_id": fields["contract_id"],
        "ctr": fields["contract_id"],
        "packet_id": fields["packet_id"],
        "pkt": fields["pkt"],
        "projection_digest": fields["projection_digest"],
        "prj": fields["projection_digest"],
        "executor_id": exe_id,
        "exe": exe_id,
        "payload": fields["payload"],
        "trace": fields["trace"],
        "extras": fields["extras"],
        "status": args.status,
        "timestamp": args.timestamp,
        "producer": args.producer,
    }
    output_event(event)


def command_trace_link(args: argparse.Namespace) -> None:
    event = {
        "kind": "trace.link",
        "topic": args.topic,
        "child_record_id": args.child,
        "parent_record_id": args.parent,
        "child_rec": args.child,
        "parent_rec": args.parent,
        "timestamp": args.timestamp,
        "producer": args.producer,
    }
    output_event(event)


def command_show_record(args: argparse.Namespace) -> None:
    found = False
    for frame in read_frames():
        payload = extract_payload(frame)
        if not isinstance(payload, Mapping):
            continue
        record_id = payload.get("record_id") or payload.get("rec")
        if record_id != args.record:
            continue
        topic = frame_topic(frame, payload)
        print(f"record: {record_id} kind={payload.get('kind')} topic={topic}")
        print(json.dumps(payload, indent=2, sort_keys=True))
        found = True
    if not found:
        raise SystemExit(1)


def command_record_topic(args: argparse.Namespace) -> None:
    for frame in read_frames():
        payload = extract_payload(frame)
        if not isinstance(payload, Mapping):
            continue
        record_id = payload.get("record_id") or payload.get("rec")
        if record_id != args.record:
            continue
        topic = frame_topic(frame, payload)
        if topic:
            print(topic)
            return
    raise SystemExit(1)


def command_show_trace(args: argparse.Namespace) -> None:
    for frame in read_frames():
        payload = extract_payload(frame)
        if not isinstance(payload, Mapping):
            continue
        if payload.get("kind") != "trace.link":
            continue
        topic = frame_topic(frame, payload)
        if args.topic and topic != args.topic:
            continue
        print(f"trace.link child={payload.get('child_record_id')} parent={payload.get('parent_record_id')} topic={topic}")
        print(json.dumps(payload, indent=2, sort_keys=True))


def main() -> None:
    parser = argparse.ArgumentParser(prog="xs-schema")
    subparsers = parser.add_subparsers(dest="command", required=True)

    contract_parser = subparsers.add_parser("define-contract")
    contract_parser.add_argument("--topic", required=True)
    contract_parser.add_argument("--input", required=True)
    contract_parser.add_argument("--producer", required=True)
    contract_parser.add_argument("--timestamp", required=True)

    record_parser = subparsers.add_parser("emit-record")
    record_parser.add_argument("--topic", required=True)
    record_parser.add_argument("--input", required=True)
    record_parser.add_argument("--producer", required=True)
    record_parser.add_argument("--timestamp", required=True)
    record_parser.add_argument("--status", choices=("append", "fail"), default="append")

    trace_parser = subparsers.add_parser("trace-link")
    trace_parser.add_argument("--topic", required=True)
    trace_parser.add_argument("--child", required=True)
    trace_parser.add_argument("--parent", required=True)
    trace_parser.add_argument("--producer", required=True)
    trace_parser.add_argument("--timestamp", required=True)

    show_record_parser = subparsers.add_parser("show-record")
    show_record_parser.add_argument("--record", required=True)

    show_trace_parser = subparsers.add_parser("show-trace")
    show_trace_parser.add_argument("--topic", required=True)

    record_topic_parser = subparsers.add_parser("record-topic")
    record_topic_parser.add_argument("--record", required=True)

    args = parser.parse_args()
    if args.command == "define-contract":
        command_define_contract(args)
    elif args.command == "emit-record":
        command_emit_record(args)
    elif args.command == "trace-link":
        command_trace_link(args)
    elif args.command == "show-record":
        command_show_record(args)
    elif args.command == "show-trace":
        command_show_trace(args)
    elif args.command == "record-topic":
        command_record_topic(args)
    else:
        parser.print_help()
        raise SystemExit(1)


if __name__ == "__main__":
    main()
