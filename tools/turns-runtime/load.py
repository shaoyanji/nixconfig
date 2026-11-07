#!/usr/bin/env python3
"""Open N SSE streams, publish turns, and report what the fan-out cost.

The server under test is measured from the outside: how many of N readers
connected, whether each got its history frame, and the p50/p99 of a published
turn reaching them (the server stamps the publish time in a `: bench` comment,
which the dashboard's own parser ignores).

Both framings are handled: HTTP/1.1 chunked (what Go/axum/Bandit send) and raw
bodies, because a client that only understands one of them measures the client.
"""
import argparse
import asyncio
import json
import statistics
import sys
import time


async def sse_lines(reader, chunked):
    """Yield SSE lines, decoding chunked transfer encoding when present."""
    if not chunked:
        while True:
            line = await reader.readline()
            if not line:
                return
            yield line.decode(errors="replace").rstrip("\r\n")
        return

    buf = b""
    while True:
        size_line = await reader.readline()
        if not size_line:
            return
        size = int(size_line.strip().split(b";")[0] or b"0", 16)
        if size == 0:
            await reader.readline()
            return
        body = await reader.readexactly(size)
        await reader.readline()
        buf += body
        # Chunks end on arbitrary boundaries, so only complete lines are yielded.
        while b"\n" in buf:
            line, _, buf = buf.partition(b"\n")
            yield line.decode(errors="replace").rstrip("\r")


async def open_stream(host, port, stats, idx):
    path = "/api/stream"
    reader, writer = await asyncio.open_connection(host, port)
    writer.write(
        (
            f"GET {path} HTTP/1.1\r\nHost: {host}:{port}\r\n"
            "Accept: text/event-stream\r\nConnection: keep-alive\r\n\r\n"
        ).encode()
    )
    await writer.drain()
    status = await reader.readline()
    if b"200" not in status:
        stats["errors"] += 1
        writer.close()
        return
    headers = {}
    while True:
        line = await reader.readline()
        if line in (b"\r\n", b"\n", b""):
            break
        key, _, value = line.decode(errors="replace").partition(":")
        headers[key.strip().lower()] = value.strip()

    history = False
    async for line in sse_lines(reader, "chunked" in headers.get("transfer-encoding", "")):
        if line.startswith("data: elements ") and not history:
            history = True
            stats["history"] += 1
        elif line.startswith(": bench "):
            _, _, seq, ms = line.split()
            stats["frames"] += 1
            stats["latency"].append(time.time() * 1000 - int(ms))
    writer.close()


async def publish(host, port, every, until, stats):
    while time.time() < until:
        try:
            reader, writer = await asyncio.open_connection(host, port)
            writer.write(
                (
                    f"POST /api/broadcast HTTP/1.1\r\nHost: {host}:{port}\r\n"
                    "Content-Length: 0\r\nConnection: close\r\n\r\n"
                ).encode()
            )
            await writer.drain()
            body = await reader.read()
            line = body.split(b"\r\n\r\n", 1)[-1].decode(errors="replace").strip()
            stats["published"] += 1
            try:
                stats["clients_seen"] = json.loads(line).get("clients", 0)
            except ValueError:
                pass
            writer.close()
        except OSError:
            stats["publish_errors"] += 1
        await asyncio.sleep(every)


def pct(values, p):
    if not values:
        return 0
    ordered = sorted(values)
    return round(ordered[min(len(ordered) - 1, int(len(ordered) * p))], 1)


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--clients", type=int, default=1000)
    ap.add_argument("--seconds", type=float, default=20)
    ap.add_argument("--every", type=float, default=1.0, help="publish interval")
    args = ap.parse_args()

    stats = {
        "clients": 0,
        "history": 0,
        "frames": 0,
        "latency": [],
        "errors": 0,
        "published": 0,
        "publish_errors": 0,
        "clients_seen": 0,
    }
    start = time.time()
    tasks = [
        asyncio.create_task(open_stream(args.host, args.port, stats, i))
        for i in range(args.clients)
    ]
    # Give the readers time to connect and take their history frame before the
    # clock on the fan-out starts, so latency is not connect cost.
    await asyncio.sleep(3)
    stats["clients"] = sum(1 for t in tasks if not t.done())
    pub = asyncio.create_task(
        publish(args.host, args.port, args.every, time.time() + args.seconds, stats)
    )
    await pub
    await asyncio.sleep(1)
    for t in tasks:
        t.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)

    out = {
        "clients": args.clients,
        "connected": stats["clients"],
        "history_frames": stats["history"],
        "published": stats["published"],
        "frames": stats["frames"],
        "p50_ms": pct(stats["latency"], 0.50),
        "p99_ms": pct(stats["latency"], 0.99),
        "max_ms": round(max(stats["latency"]), 1) if stats["latency"] else 0,
        "errors": stats["errors"],
        "publish_errors": stats["publish_errors"],
        "server_clients_seen": stats["clients_seen"],
        "seconds": round(time.time() - start, 1),
    }
    json.dump(out, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    asyncio.run(main())
