#!/usr/bin/env python3
"""Benchmark an email-archive API against the uniform contract.

The contract is deliberately small, because the point is to let architectures
compete on the same questions rather than on the same implementation. A rival
is a server that answers these four routes with these shapes; nothing about
PostgreSQL, NpgsqlRest or the storage engine is part of it:

    GET  /health                          -> 200, any body
    GET  /api/list-emails?lim=N           -> 200, JSON array of rows
    GET  /api/emails-search?q=<text>      -> 200, JSON array of rows
    POST /api/add-email  (nine keys)      -> 200, JSON array with id + messageId

Rows carry the same camelCase keys either way. Unknown or missing query
parameters must be a 4xx -- the champion answers 404 (its router does not know
the parameter) and a rival answering 400 is equally acceptable, because the
rejection is the contract and the code is the engine's business.

Two numbers are reported per operation: p50/p95 latency in milliseconds, and a
correctness verdict from the shape checks. `score` folds them into one figure
(higher is better) so a champion and a rival can be compared by a single line,
and the JSON keeps everything needed to disagree with that score.

Reads are the default. Ingest (`--write`) inserts rows marked `bench:` and the
cleanup statement is printed with the result; it is opt-in because it touches
the archive.
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

# Fixed so two architectures see the same work. Words, not addresses: nothing
# here is allowed to depend on one mailbox's content beyond "some mail exists".
QUERIES = [
    "invoice",
    "order",
    "receipt",
    "unsubscribe",
    "verification",
    "notification",
    "security",
    "ticket",
    "trip",
    "account",
]

LIST_LIMITS = [1, 20, 100]

REQUIRED_LIST_KEYS = {
    "id",
    "messageId",
    "sender",
    "subject",
    "sentAt",
    "labels",
    "attachmentPath",
    "bodyLength",
}
REQUIRED_SEARCH_KEYS = {"id", "messageId", "sender", "subject", "sentAt", "snippet"}


def request(url, body=None, timeout=15):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"} if data else {},
        method="POST" if data else "GET",
    )
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            payload = response.read()
            code = response.status
    except urllib.error.HTTPError as exc:
        payload = exc.read()
        code = exc.code
    elapsed = (time.perf_counter() - started) * 1000.0
    return code, payload, elapsed


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, int(round(fraction * (len(ordered) - 1)))))
    return ordered[index]


def summarise(name, prompt, samples, codes, rows, checks):
    latencies = [s for s, code in zip(samples, codes) if code == 200]
    return {
        "op": name,
        "param": prompt,
        "iterations": len(samples),
        "ok": all(code == 200 for code in codes),
        "p50_ms": round(percentile(latencies, 0.50), 2) if latencies else None,
        "p95_ms": round(percentile(latencies, 0.95), 2) if latencies else None,
        "max_ms": round(max(latencies), 2) if latencies else None,
        "rows": rows,
        "checks": checks,
    }


class Bench:
    def __init__(self, args):
        self.args = args
        self.base = args.base.rstrip("/")
        self.results = []
        self.checks = 0
        self.failures = []

    def check(self, label, condition):
        self.checks += 1
        if not condition:
            self.failures.append(label)
        return condition

    def measure(self, name, prompt, url, body=None):
        for _ in range(self.args.warmup):
            request(url, body)
        samples, codes, rows = [], [], None
        for _ in range(self.args.iterations):
            code, payload, elapsed = request(url, body)
            samples.append(elapsed)
            codes.append(code)
            rows = self.parse_rows(payload, rows)
        self.results.append(summarise(name, prompt, samples, codes, rows, self.checks))
        return codes

    @staticmethod
    def parse_rows(payload, fallback):
        try:
            parsed = json.loads(payload or b"null")
        except json.JSONDecodeError:
            return fallback
        return len(parsed) if isinstance(parsed, list) else fallback

    def shaped(self, url, required):
        code, payload, _ = request(url)
        if code != 200:
            return None
        try:
            rows = json.loads(payload)
        except json.JSONDecodeError:
            return None
        if not isinstance(rows, list):
            return None
        if rows and not required.issubset(rows[0].keys()):
            return rows[0].keys()
        return "ok"

    def run(self):
        print(f"target      {self.base}")
        code, payload, _ = request(f"{self.base}/health")
        health = self.check("health 200", code == 200)
        print(f"health      {code} {payload[:40].decode(errors='replace') if payload else ''}")

        for limit in LIST_LIMITS:
            url = f"{self.base}/api/list-emails?lim={limit}"
            verdict = self.shaped(url, REQUIRED_LIST_KEYS)
            self.check(f"list-emails lim={limit} shape", verdict == "ok")
            self.measure("list-emails", f"lim={limit}", url)

        for query in QUERIES:
            url = f"{self.base}/api/emails-search?q={query}"
            verdict = self.shaped(url, REQUIRED_SEARCH_KEYS)
            self.check(f"emails-search q={query} shape", verdict == "ok")
            self.measure("emails-search", f"q={query}", url)

        # A rejection is part of the contract; the status may be 400 or 404.
        code, _, _ = request(f"{self.base}/api/list-emails?bogus=1")
        self.check("unknown parameter rejected 4xx", 400 <= code < 500)
        print(f"rejection   unknown param -> {code}")

        if self.args.write:
            run = time.strftime("%Y%m%dT%H%M%S")
            body = {
                "messageId": f"bench:{run}:0",
                "threadId": "",
                "sender": "bench@local",
                "recipients": "bench@local",
                "subject": "benchmark row",
                "sentAt": "",
                "labels": "bench",
                "bodyPlain": "benchmark row",
                "attachmentPath": "",
            }
            code, payload, _ = request(f"{self.base}/api/add-email", body)
            self.check("add-email 200", code == 200)
            self.results.append(
                {
                    "op": "add-email",
                    "param": "one row",
                    "iterations": 1,
                    "ok": code == 200,
                    "p50_ms": None,
                    "p95_ms": None,
                    "max_ms": None,
                    "rows": 1,
                    "checks": self.checks,
                }
            )
            print(f"ingest      {code} {payload[:60].decode(errors='replace')}")
            print(f"cleanup     delete from emails where message_id like 'bench:%';")

        self.report(health)
        return 0 if not self.failures else 1

    def report(self, health):
        print()
        print(f"{'operation':<16}{'param':<14}{'n':>4}{'p50':>9}{'p95':>9}{'max':>9}{'rows':>6}")
        for row in self.results:
            print(
                f"{row['op']:<16}{row['param']:<14}{row['iterations']:>4}"
                f"{(row['p50_ms'] if row['p50_ms'] is not None else '-'):>9}"
                f"{(row['p95_ms'] if row['p95_ms'] is not None else '-'):>9}"
                f"{(row['max_ms'] if row['max_ms'] is not None else '-'):>9}"
                f"{(row['rows'] if row['rows'] is not None else '-'):>6}"
            )

        timed = [r["p95_ms"] for r in self.results if r["p95_ms"]]
        geometric = None
        if timed:
            product = 1.0
            for value in timed:
                product *= max(value, 0.001)
            geometric = product ** (1.0 / len(timed))
        correctness = (self.checks - len(self.failures)) / self.checks if self.checks else 0
        score = round(correctness * 1000.0 / geometric, 2) if geometric else 0.0

        print()
        print(f"checks      {self.checks - len(self.failures)}/{self.checks} passed")
        if self.failures:
            for failure in self.failures:
                print(f"  FAILED    {failure}")
        print(f"p95 geometric mean  {round(geometric, 2) if geometric else '-'} ms")
        print(f"score       {score}   (1000 / p95 geometric mean, x correctness)")

        result = {
            "target": self.base,
            "when": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "iterations": self.args.iterations,
            "label": self.args.label,
            "checks": {"passed": self.checks - len(self.failures), "total": self.checks},
            "failures": self.failures,
            "p95_geomean_ms": round(geometric, 2) if geometric else None,
            "score": score,
            "results": self.results,
        }
        if self.args.out:
            with open(self.args.out, "w", encoding="utf-8") as handle:
                json.dump(result, handle, indent=2)
                handle.write("\n")
            print(f"json        {self.args.out}")
        if self.args.json:
            print(json.dumps(result, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:8080", help="API base URL")
    parser.add_argument("--iterations", type=int, default=30)
    parser.add_argument("--warmup", type=int, default=3)
    parser.add_argument("--write", action="store_true", help="also POST one ingest row")
    parser.add_argument("--out", help="write the JSON result here")
    parser.add_argument("--json", action="store_true", help="print the JSON result too")
    parser.add_argument("--label", default=os.uname().nodename)
    args = parser.parse_args()
    try:
        return Bench(args).run()
    except urllib.error.URLError as exc:
        print(f"email-bench: cannot reach {args.base}: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
