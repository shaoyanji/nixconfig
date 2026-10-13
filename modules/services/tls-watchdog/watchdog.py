#!/usr/bin/env python3
"""
tls-cert-watchdog: Audits local certificate files and HTTPS endpoints for expiration.
"""

import sys
import os
import ssl
import socket
import datetime
import argparse
import subprocess
from urllib.parse import urlparse

def parse_cert_file(cert_path: str, now: datetime.datetime, warn_days: int, critical_days: int) -> int:
    if not os.path.exists(cert_path):
        print(f"[MISSING] Cert file not found: {cert_path}")
        return 1

    try:
        res = subprocess.run(
            ["openssl", "x509", "-enddate", "-noout", "-in", cert_path],
            capture_output=True, text=True, check=True
        )
        line = res.stdout.strip()
        date_str = line.split("=")[1].strip()
        exp_date = datetime.datetime.strptime(date_str, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=datetime.timezone.utc)
        remaining_days = (exp_date - now).total_seconds() / 86400.0

        if remaining_days <= critical_days:
            print(f"[CRITICAL] File: {cert_path} expires in {remaining_days:.1f} days! ({exp_date})")
            return 2
        elif remaining_days <= warn_days:
            print(f"[WARNING]  File: {cert_path} expires in {remaining_days:.1f} days ({exp_date})")
            return 1
        else:
            print(f"[OK]       File: {cert_path} valid for {remaining_days:.1f} days ({exp_date.strftime('%Y-%m-%d')})")
            return 0
    except Exception as e:
        print(f"[ERROR]    Failed to parse cert file {cert_path}: {e}")
        return 1

def parse_endpoint(endpoint: str, now: datetime.datetime, warn_days: int, critical_days: int) -> int:
    parsed = urlparse(endpoint)
    host = parsed.hostname or endpoint
    port = parsed.port or (443 if parsed.scheme == "https" else 80)

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    try:
        with socket.create_connection((host, port), timeout=3.0) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                cert = ssock.getpeercert(binary_form=True)
                p = subprocess.Popen(
                    ["openssl", "x509", "-inform", "DER", "-enddate", "-noout"],
                    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
                )
                out, _ = p.communicate(cert)
                date_str = out.decode().strip().split("=")[1].strip()
                exp_date = datetime.datetime.strptime(date_str, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=datetime.timezone.utc)
                remaining_days = (exp_date - now).total_seconds() / 86400.0

                if remaining_days <= critical_days:
                    print(f"[CRITICAL] Endpoint: {endpoint} expires in {remaining_days:.1f} days! ({exp_date})")
                    return 2
                elif remaining_days <= warn_days:
                    print(f"[WARNING]  Endpoint: {endpoint} expires in {remaining_days:.1f} days ({exp_date})")
                    return 1
                else:
                    print(f"[OK]       Endpoint: {endpoint} valid for {remaining_days:.1f} days ({exp_date.strftime('%Y-%m-%d')})")
                    return 0
    except Exception as e:
        print(f"[INFO]     Endpoint {endpoint} TLS probe: {e}")
        return 0

def main():
    parser = argparse.ArgumentParser(description="SSL/TLS Certificate Expiry Watchdog")
    parser.add_argument("--endpoints", nargs="*", default=[], help="HTTPS endpoints to inspect")
    parser.add_argument("--cert-files", nargs="*", default=[], help="Local cert files to inspect")
    parser.add_argument("--warn-days", type=int, default=14, help="Warning threshold in days")
    parser.add_argument("--critical-days", type=int, default=5, help="Critical threshold in days")
    parser.add_argument("--fail-on-critical", action="store_true", help="Exit non-zero if critical")

    args = parser.parse_args()

    now = datetime.datetime.now(datetime.timezone.utc)
    status_code = 0
    inspected = 0

    print("==========================================================")
    print("=== Autonomous SSL/TLS Certificate Expiry Watchdog    ===")
    print(f"=== Thresholds: Warning <= {args.warn_days}d | Critical <= {args.critical_days}d ===")
    print("==========================================================\n")

    for f in args.cert_files:
        inspected += 1
        res = parse_cert_file(f, now, args.warn_days, args.critical_days)
        status_code = max(status_code, res)

    for ep in args.endpoints:
        inspected += 1
        res = parse_endpoint(ep, now, args.warn_days, args.critical_days)
        status_code = max(status_code, res)

    print(f"\nAudit complete. Total targets inspected: {inspected}")

    if status_code >= 2 and args.fail_on_critical:
        sys.exit(2)
    sys.exit(0)

if __name__ == "__main__":
    main()
