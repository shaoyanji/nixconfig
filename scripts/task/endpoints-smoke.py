#!/usr/bin/env python3
# Probe every `tailscale serve` mount a host declares, not just its unit.
# docs/delphi-runtime.md — `checks:delphi:endpoints` is the caller.
"""Ask each compiled mount for its page and say which ones do not answer.

The registry comes from `services.servicePortal.mounts`, so the list is the
config's, not a copy: one entry per mount, each with the loopback `upstream` the
mount fronts. A mount whose upstream is down answers 502/504 (or times out) while
its systemd unit is happily `active` — the state `services:validate:host` cannot
see, because it only asks systemd.

Verdicts: connection refused, a timeout and any 5xx are failures. A 4xx means
something is listening and answering (radicale refuses `/` by design, the archive
answers `401` without a token), so it passes unless `--expect` narrows it.
"""

import argparse
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

# Codes that mean "listening and answering" even though the page is not the one a
# human sees: auth-gated mounts, and machine-facing services with no `/` page.
ANSWERED = {401, 403, 404, 405}


class ProbeError(Exception):
    """A mount that did not answer at all."""


def to_toon(summary):
    if not summary:
        return "empty"
    lines = []
    for key, value in summary.items():
        if isinstance(value, dict):
            lines.append(f"{key}:")
            for inner, leaf in value.items():
                if isinstance(leaf, dict):
                    lines.append(f"  {inner}:")
                    for k2, v2 in leaf.items():
                        lines.append(f"    {k2}: {json.dumps(v2)}")
                elif isinstance(leaf, list):
                    lines.append(f"  {inner}[{len(leaf)}]:")
                    lines.extend(f"    {json.dumps(item)}" for item in leaf)
                else:
                    lines.append(f"  {inner}: {json.dumps(leaf)}")
        elif isinstance(value, list):
            lines.append(f"{key}[{len(value)}]:")
            lines.extend(f"  {json.dumps(item)}" for item in value)
        else:
            lines.append(f"{key}: {json.dumps(value)}")
    return "\n".join(lines)


def probe(url, timeout, opener=None):
    """Return the HTTP status, or raise ProbeError with the reason."""
    opener = opener or urllib.request.urlopen
    request = urllib.request.Request(url, method="GET")
    try:
        with opener(request, timeout=timeout) as response:
            return response.status
    except urllib.error.HTTPError as exc:
        return exc.code
    except urllib.error.URLError as exc:
        raise ProbeError(f"unreachable: {exc.reason}") from exc
    except (TimeoutError, OSError) as exc:
        raise ProbeError(f"unreachable: {exc}") from exc


def check_mount(url, timeout, answered, opener=None):
    """(ok, status, detail) for one mount."""
    try:
        status = probe(url, timeout, opener)
    except ProbeError as exc:
        return False, None, str(exc)
    if status >= 500:
        return False, status, f"upstream failed: {status}"
    if answered and status not in answered:
        return False, status, f"answered {status}, expected one of {sorted(answered)}"
    return True, status, f"answered {status}"


def main(argv=None, opener=None):
    parser = argparse.ArgumentParser(description="Probe every tailnet mount a host declares.")
    parser.add_argument("--host", default="delphi.cloudforest-kardashev.ts.net",
                        help="tailnet host serving the mounts")
    parser.add_argument("--scheme", default="https", choices=["https", "http"])
    parser.add_argument("--path", default="/", help="path each mount is asked for")
    parser.add_argument("--timeout", type=float, default=8.0)
    parser.add_argument("--expect", default="",
                        help="comma-separated status codes a mount must answer with")
    parser.add_argument("--in", dest="infile", default="-",
                        help="mounts JSON ({name: {port, upstream}}), - for stdin")
    parser.add_argument("--format", default="json", choices=["json", "toon"])
    args = parser.parse_args(argv)

    try:
        raw = sys.stdin.read() if args.infile == "-" else open(args.infile, encoding="utf-8").read()
        mounts = json.loads(raw)
    except (OSError, ValueError) as exc:
        print(f"endpoints-smoke: cannot read the mount registry: {exc}", file=sys.stderr)
        return 2
    if not isinstance(mounts, dict) or not mounts:
        print("endpoints-smoke: the registry is empty — is servicePortal enabled on this host?",
              file=sys.stderr)
        return 2

    answered = {int(code) for code in args.expect.split(",") if code.strip()} or None
    summary = {
        "host": args.host,
        "mounts": {},
        "failed": [],
        "at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    for name in sorted(mounts):
        port = mounts[name].get("port")
        url = f"{args.scheme}://{args.host}:{port}{args.path}"
        ok, status, detail = check_mount(url, args.timeout, answered, opener)
        summary["mounts"][name] = {
            "port": port,
            "url": url,
            "status": status,
            "ok": ok,
            "detail": detail,
        }
        if not ok:
            summary["failed"].append(name)

    summary["ok"] = not summary["failed"]
    rendered = to_toon(summary) if args.format == "toon" else json.dumps(summary, indent=2)
    print(rendered)
    if summary["failed"]:
        print(f"endpoints-smoke: {len(summary['failed'])} mount(s) did not answer: "
              f"{', '.join(summary['failed'])}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
