#!/usr/bin/env python3
"""Sync the compiled fleet inventory into inventory-site.

`nix eval --json .#inventory.hosts` is the compiled truth about every machine:
hostname, kind, arch, status, hardware, network names, traits and services.
inventory-site is where a person can search that alongside the household's other
things. This is the pipe between them.

    inventory-sync.py --dry-run
    inventory-sync.py --api https://delphi.cloudforest-kardashev.ts.net:8466
    inventory-sync.py --in hosts.json --only delphi,clanker --format toon

The mapping is the service's own: `source = inventory.toml` and
`source_key = host/<name>` are what `POST /api/import/inventory-toml` writes, so
a sync and an import update the same rows instead of filing each host twice.
That route takes the TOML file itself; this one takes the evaluated JSON, which
is what a flake exposes without reading a file.

Nothing writes the database directly: the server owns the schema and the FTS
index, and `(source, source_key)` is its upsert key.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

UA = "nixconfig-inventory-sync/1.0"
DEFAULT_SOURCE = "inventory.toml"
DEFAULT_CATEGORY = "fleet-host"


class SyncError(RuntimeError):
    """The server refused an item; the run reports it and keeps going."""


def load_hosts(path: str = "", evaluate: bool = False) -> dict:
    """The host table, from a JSON file or from the flake's evaluated attr."""
    if path:
        with open(os.path.expanduser(path), encoding="utf-8") as handle:
            document = json.load(handle)
    elif evaluate:
        result = subprocess.run(
            ["nix", "eval", "--json", ".#inventory.hosts"],
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            raise SyncError(f"nix eval failed: {(result.stderr or '').strip()[:200]}")
        document = json.loads(result.stdout or "{}")
    else:
        document = json.load(sys.stdin)
    # A whole `.#inventory` object carries `hosts`; a bare table does not.
    if isinstance(document, dict) and isinstance(document.get("hosts"), dict):
        document = document["hosts"]
    if not isinstance(document, dict):
        raise SyncError("the inventory is not a host table")
    return document


def text(value) -> str:
    return str(value or "").strip()


def first_non_blank(*values) -> str:
    for value in values:
        if text(value):
            return text(value)
    return ""


def unique(values) -> list:
    seen, out = set(), []
    for value in values:
        item = text(value)
        if item and item not in seen:
            seen.add(item)
            out.append(item)
    return out


def location_of(host: dict) -> str:
    network = host.get("network") or {}
    parts = []
    if text(network.get("tailscale_hostname")):
        parts.append("tailnet:" + text(network["tailscale_hostname"]))
    if text(network.get("lan_ip")):
        parts.append("lan:" + text(network["lan_ip"]))
    return " / ".join(parts) or text(network.get("ssh_alias")) or "fleet"


def hardware_line(host: dict) -> str:
    hardware = host.get("hardware") or {}
    parts = [
        text(hardware.get(key))
        for key in ("cpu", "gpu", "ram", "storage_type", "display", "battery")
    ]
    return "; ".join(part for part in parts if part)


def tailnet_links(host: dict) -> list:
    """The host's tailnet mounts as `{label, port, url}`, ports as integers."""
    rows = []
    for link in (host.get("network") or {}).get("links") or []:
        if not isinstance(link, dict):
            continue
        port = link.get("port")
        try:
            port = int(port) if text(port) else None
        except (TypeError, ValueError):
            port = None
        rows.append({"label": text(link.get("label")), "port": port, "url": text(link.get("url"))})
    return rows


def declared_services(path: str) -> dict:
    """`software.services` from inventory.toml: the structured half of a host.

    The compiled `.#inventory.hosts` keeps `key_services` as prose and drops this
    table, so the ports a host claims only exist in the TOML.
    """
    import tomllib

    with open(os.path.expanduser(path), "rb") as handle:
        document = tomllib.load(handle)
    table = {}
    for key, host in (document.get("hosts") or {}).items():
        if not isinstance(host, dict):
            continue
        rows = []
        for service in (host.get("software") or {}).get("services") or []:
            if not isinstance(service, dict):
                continue
            port = service.get("port")
            try:
                port = int(port) if text(port) else None
            except (TypeError, ValueError):
                port = None
            rows.append({"name": text(service.get("name")), "port": port})
        if rows:
            table[key] = rows
    return table


def endpoint_notes(links: list, services: list) -> str:
    """What a person searching the site wants beside a host: where it answers."""
    parts = []
    if links:
        parts.append(
            "Endpoints: "
            + "; ".join(
                f"{link['label'] or 'link'} :{link['port']}" if link["port"] else (link["label"] or "link")
                for link in links
            )
        )
    if services:
        parts.append(
            "Declared: "
            + "; ".join(
                f"{service['name']} :{service['port']}" if service["port"] else service["name"]
                for service in services
            )
        )
    return "\n\n".join(part for part in parts if part)


def port_conflicts(host_key: str, links: list, services: list) -> list:
    """Two mounts or two units cannot share one port; a mount and the unit behind
    it sharing one is corroboration, which is how the fleet declares them."""
    conflicts = []
    for kind, rows, name_of in (
        ("link", links, lambda row: row["label"] or "(unlabelled)"),
        ("service", services, lambda row: row["name"] or "(unnamed)"),
    ):
        claims = {}
        for row in rows:
            if row["port"]:
                claims.setdefault(row["port"], []).append(name_of(row))
        for port, names in sorted(claims.items()):
            if len(set(names)) > 1:
                conflicts.append(f"{host_key}: port {port} is two {kind}s: {', '.join(sorted(set(names)))}")
    return conflicts


def notes_of(host: dict, services=()) -> str:
    hardware = host.get("hardware") or {}
    software = host.get("software") or {}
    notes = []
    if text(host.get("status_detail")):
        notes.append(text(host["status_detail"]))
    if hardware_line(host):
        notes.append("Hardware: " + hardware_line(host))
    if text(hardware.get("storage_layout")):
        notes.append("Storage layout: " + text(hardware["storage_layout"]))
    key_services = unique(software.get("key_services") or [])
    if key_services:
        notes.append("Services: " + "; ".join(key_services))
    endpoints = endpoint_notes(tailnet_links(host), list(services))
    if endpoints:
        notes.append(endpoints)
    for note in host.get("notes") or []:
        if text(note):
            notes.append(text(note))
    return "\n\n".join(notes)


def host_item(key: str, host: dict, source: str = DEFAULT_SOURCE, services=()) -> dict:
    """One host as the API's item input, in the service's own vocabulary."""
    hardware = host.get("hardware") or {}
    software = host.get("software") or {}
    persona = host.get("persona") or {}
    model = text(hardware.get("model"))
    manufacturer = model.split()[0] if len(model.split()) > 1 else ""
    tags = unique(
        ["fleet", host.get("status"), host.get("kind"), host.get("arch")]
        + list(software.get("traits") or [])
    )
    return {
        "source": source,
        "source_key": "host/" + key,
        "name": first_non_blank(host.get("hostname"), key),
        "category": first_non_blank(host.get("category"), DEFAULT_CATEGORY),
        "location": location_of(host),
        "description": first_non_blank(host.get("role"), persona.get("title")),
        "manufacturer": manufacturer,
        "model": model,
        "serial": text(host.get("serial")),
        "purchase_date": "",
        "warranty_until": "",
        "value_cents": 0,
        "currency": "EUR",
        "quantity": 1,
        "url": "",
        "notes": notes_of(host, services),
        "tags": tags,
        "archived": text(host.get("status")) in {"retired", "gone", "decommissioned"},
    }


def build_items(hosts: dict, source: str = DEFAULT_SOURCE, only=(), services=None) -> tuple:
    """Every host as an item, plus the hosts skipped and why."""
    wanted = {name.strip() for name in only if name.strip()}
    services = services or {}
    items, warnings = [], []
    for key in sorted(hosts):
        host = hosts[key]
        if not isinstance(host, dict):
            warnings.append(f"skipped {key}: not a host record")
            continue
        if wanted and key not in wanted and text(host.get("hostname")) not in wanted:
            continue
        item = host_item(key, host, source=source, services=services.get(key) or ())
        if not item["name"]:
            warnings.append(f"skipped {key}: no hostname")
            continue
        if not item["source_key"]:
            warnings.append(f"skipped {key}: no source key")
            continue
        items.append(item)
    return items, warnings


def post_item(api: str, payload: dict, token: str = "", timeout: int = 30) -> dict:
    body = json.dumps(payload).encode()
    headers = {"Content-Type": "application/json", "User-Agent": UA}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"{api.rstrip('/')}/api/items", data=body, headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:300]
        raise SyncError(f"{exc.code} {detail}") from exc
    except urllib.error.URLError as exc:
        raise SyncError(f"api unreachable: {exc.reason}") from exc


def to_toon(document) -> str:
    binary = shutil.which("toon")
    if binary:
        try:
            result = subprocess.run(
                [binary],
                input=json.dumps(document),
                capture_output=True,
                text=True,
                timeout=30,
                check=True,
            )
            if result.stdout.strip():
                return result.stdout.rstrip("\n")
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass
    return json.dumps(document, indent=2)


def emit(document: dict, fmt: str) -> None:
    print(to_toon(document) if fmt == "toon" else json.dumps(document, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync compiled inventory.hosts into inventory-site /api/items."
    )
    parser.add_argument("--api", default="http://127.0.0.1:8103", help="inventory-site base URL")
    parser.add_argument("--in", dest="input_path", help="hosts JSON file; default stdin")
    parser.add_argument("--eval", action="store_true", help="evaluate .#inventory.hosts from this flake")
    parser.add_argument("--source", default=DEFAULT_SOURCE, help="source label written on every row")
    parser.add_argument("--only", default="", help="comma-separated host keys")
    parser.add_argument("--token-env", default="INVENTORY_SITE_ADMIN_TOKEN")
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--format", choices=("json", "toon"), default="json")
    parser.add_argument("--dry-run", action="store_true", help="print payloads, POST nothing")
    parser.add_argument(
        "--toml",
        default="",
        help="inventory.toml to take declared service ports from and audit links against",
    )
    args = parser.parse_args()

    only = [part for part in args.only.split(",") if part.strip()]
    try:
        hosts = load_hosts(path=args.input_path, evaluate=args.eval or not args.input_path and sys.stdin.isatty())
    except (OSError, json.JSONDecodeError, SyncError) as exc:
        emit({"error": str(exc)}, args.format)
        return 2

    warnings = []
    services = {}
    endpoints = {}
    drift = {"only_in_toml": [], "only_in_compiled": []}
    if args.toml:
        try:
            services = declared_services(args.toml)
        except (OSError, ValueError) as exc:
            emit({"error": f"{args.toml}: {exc}"}, args.format)
            return 2
        links_total = sum(len(tailnet_links(host)) for host in hosts.values() if isinstance(host, dict))
        conflicts = []
        for key in sorted(set(hosts) | set(services)):
            host = hosts.get(key) if isinstance(hosts.get(key), dict) else {}
            conflicts += port_conflicts(key, tailnet_links(host), services.get(key) or [])
        if set(services) - set(hosts):
            drift["only_in_toml"] = sorted(set(services) - set(hosts))
        if set(hosts) - set(services):
            drift["only_in_compiled"] = sorted(set(hosts) - set(services))
        endpoints = {
            "links": links_total,
            "declared": sum(len(rows) for rows in services.values()),
            "with_port": sum(1 for rows in services.values() for row in rows if row["port"]),
            "conflicts": conflicts,
        }
        warnings += [f"drift: {key} is declared in the TOML but not compiled" for key in drift["only_in_toml"]]

    items, extra_warnings = build_items(hosts, source=args.source, only=only, services=services)
    warnings += extra_warnings
    token = os.environ.get(args.token_env, "").strip()
    created = updated = 0
    failed = []
    for item in items:
        if args.dry_run:
            print(json.dumps({"would_post": item}, sort_keys=True), file=sys.stderr)
            continue
        try:
            answer = post_item(args.api, item, token=token, timeout=args.timeout)
            if answer.get("created"):
                created += 1
            else:
                updated += 1
        except SyncError as exc:
            failed.append({"host": item["source_key"], "error": str(exc)[:300]})

    summary = {
        "run": "inventory-sync",
        "dry_run": args.dry_run,
        "api": args.api,
        "source": args.source,
        "hosts": len(hosts),
        "items": len(items),
        "created": created,
        "updated": updated,
        "failed": failed,
        "warnings": warnings,
        "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    if args.toml:
        summary["endpoints"] = endpoints
        summary["drift"] = drift
    emit(summary, args.format)
    return 1 if failed or endpoints.get("conflicts") else 0


if __name__ == "__main__":
    sys.exit(main())
