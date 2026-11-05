#!/usr/bin/env python3
"""Serve the zettel reader and its vault export on one loopback port.

The reader is static: `index.html`, `graph.json` and `demo/`. The verbs that
change something are the whole API.

  GET  /api/health        what is being served (note/link counts, vault HEAD)
  GET  /api/note/<id>     raw markdown of one note
  PUT  /api/note/<id>     write it back, commit, re-export the graph, push
  POST /api/new           create a note through the vault's create_note.py
  POST /api/publish       render PDFs through the vault's own publish_md.py
  POST /api/reload        re-export the graph from the working tree
  GET  /publish/<name>    one rendered PDF

There is no authentication of its own: the listener is loopback and the only
route in is the host's `tailscale serve` mount, so "on the tailnet" is the
fence. A write additionally needs `X-Zettel-Write: 1` and, when the browser
sends one, an Origin equal to --tailnet-host — a simple cross-site request can
reach a tailnet name without ever reading the answer, and this is what makes
that request not a write.

Nothing here parses markdown or resolves a link: the vault's exporter does
that, and this process only runs it. A second copy of those rules is how the
page and the gate start disagreeing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

# The three directories a note may live in. A write outside them is a typo or
# an attack; either way it is not this service's business. Ids come from the
# export, which drops the suffix (`zettels/2026…-a-note`); an explicit `.md` is
# accepted because a caller reading `git status` will have one.
ID_RE = re.compile(r"^(?:zettels|010 - MOCs|journal)/[^/\\\x00]+$")
PDF_RE = re.compile(r"^[^/\\\x00]+\.pdf$")
MAX_NOTE = 512 * 1024

# The types whose `create_note.py` target is a directory this service writes to.
# `note`/`idea`/`reference` land in `zettels/notes` and `zettels/ideas`, which
# the id shape here does not cover; offering them would be a button that 400s.
CREATE_TYPES = ("zettel", "moc")

MUTATE = threading.Lock()
CONFIG: dict = {}
HEAD_CACHE = {"at": 0.0, "value": ""}


class Refused(Exception):
    """A request this service answers with a status and a sentence."""

    def __init__(self, code: int, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def vault(*args: str, timeout: int = 60) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(CONFIG["vault"]), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def note_file(note_id: str) -> tuple[str, Path]:
    """`zettels/x` -> (`zettels/x.md`, an absolute path inside the vault)."""
    relative = note_id[:-3] if note_id.endswith(".md") else note_id
    if not ID_RE.match(relative):
        raise Refused(400, "an id is zettels/, 010 - MOCs/ or journal/ plus a name")
    path = CONFIG["vault"] / f"{relative}.md"
    root = CONFIG["vault"].resolve()
    resolved = path.resolve()
    if resolved != root and root not in resolved.parents:
        raise Refused(400, "that path leaves the vault")
    return f"{relative}.md", path


def reexport() -> dict:
    """Regenerate graph.json with the vault's exporter, and swap it in whole."""
    www = CONFIG["www"]
    target = www / "graph.json"
    tmp = www / f".graph.{os.getpid()}.json"
    proc = subprocess.run(
        [sys.executable, "scripts/export_graph.py", "--out", str(tmp)],
        cwd=str(CONFIG["vault"]),
        capture_output=True,
        text=True,
        timeout=240,
    )
    if proc.returncode != 0:
        tmp.unlink(missing_ok=True)
        raise Refused(500, "export failed: " + (proc.stderr.strip() or proc.stdout.strip())[-800:])
    os.replace(tmp, target)
    return read_meta()


def read_meta() -> dict:
    try:
        return json.loads((CONFIG["www"] / "graph.json").read_text(encoding="utf-8")).get("meta", {})
    except (OSError, ValueError):
        return {}


def head() -> str:
    now = time.monotonic()
    if now - HEAD_CACHE["at"] > 5:
        result = vault("rev-parse", "--short", "HEAD")
        HEAD_CACHE["value"] = result.stdout.strip() if result.returncode == 0 else ""
        HEAD_CACHE["at"] = now
    return HEAD_CACHE["value"]


def credentials() -> str | None:
    """A one-run credential store; the token never lands in argv or .git/config."""
    directory = os.environ.get("CREDENTIALS_DIRECTORY")
    if not directory:
        return None
    source = Path(directory) / "github-token"
    if not source.exists():
        return None
    handle = tempfile.NamedTemporaryFile("w", suffix=".gitcred", delete=False)
    with handle:
        handle.write(f"https://x-access-token:{source.read_text(encoding='utf-8').strip()}@github.com\n")
    os.chmod(handle.name, 0o600)
    return handle.name


def push() -> tuple[bool, str]:
    creds = credentials()
    if creds is None:
        return False, "no github-token credential"
    try:
        proc = vault(
            "-c", f"credential.helper=store --file={creds}",
            "push", "--quiet", "origin", f"HEAD:refs/heads/{CONFIG['ref']}",
            timeout=120,
        )
        if proc.returncode == 0:
            return True, ""
        return False, (proc.stderr.strip() or proc.stdout.strip())[-400:]
    finally:
        Path(creds).unlink(missing_ok=True)


def record(relative: str, message: str) -> dict:
    """Commit one path and push, unless the host was configured otherwise."""
    result = {"committed": False, "pushed": False}
    if not CONFIG["commit"]:
        return result
    vault("add", "--", relative)
    if vault("diff", "--cached", "--quiet", "--", relative).returncode == 0:
        return result
    committed = vault(
        "-c", f"user.name={CONFIG['git_name']}",
        "-c", f"user.email={CONFIG['git_email']}",
        "commit", "--quiet", "--only", "-m", message, "--", relative,
    )
    if committed.returncode != 0:
        raise Refused(500, "commit failed: " + (committed.stderr.strip() or committed.stdout.strip())[-400:])
    result["committed"] = True
    if CONFIG["push"]:
        result["pushed"], result["push_error"] = push()
    return result


def write_note(note_id: str, text: str) -> dict:
    relative, path = note_file(note_id)
    if not path.is_file():
        raise Refused(404, f"{relative} is not in the working tree")
    if len(text.encode("utf-8")) > MAX_NOTE:
        raise Refused(413, f"a note over {MAX_NOTE // 1024} KiB is not a zettel")
    mode = path.stat().st_mode & 0o777

    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(text, encoding="utf-8")
    os.chmod(tmp, mode)
    os.replace(tmp, path)

    result = {"id": relative, "bytes": path.stat().st_size}
    result.update(record(relative, f"zettel-graph: edit {relative}"))
    result["meta"] = reexport()
    return result


def create_note(spec: dict) -> dict:
    """Create through the vault's script, so frontmatter is the vault's own."""
    title = " ".join(str(spec.get("title") or "").split())
    if not title:
        raise Refused(400, "a note needs a title")
    if len(title) > 120:
        raise Refused(400, "a title over 120 characters is a paragraph, not a name")
    kind = str(spec.get("type") or "zettel")
    if kind not in CREATE_TYPES:
        raise Refused(400, f"type is one of {list(CREATE_TYPES)}")
    tags = " ".join(str(spec.get("tags") or "").replace(",", " ").split())

    args = [sys.executable, "scripts/create_note.py", "--title", title, "--type", kind, "--root", "."]
    if tags:
        args += ["--tags", tags.replace(" ", ",")]
    proc = subprocess.run(args, cwd=str(CONFIG["vault"]), capture_output=True, text=True, timeout=60)
    if proc.returncode != 0:
        raise Refused(
            500,
            "create_note.py failed: " + (proc.stderr.strip() or proc.stdout.strip())[-600:],
        )

    # The script prints the vault-relative path first; the rest is commentary.
    created = next((line.strip() for line in proc.stdout.splitlines() if line.strip().endswith(".md")), "")
    if not created:
        raise Refused(500, "create_note.py wrote nothing it can name: " + proc.stdout.strip()[-300:])
    relative, path = note_file(created)
    if not path.is_file():
        raise Refused(500, f"create_note.py reported {relative}, which is not there")

    result = {"path": relative, "id": relative[:-3], "bytes": path.stat().st_size}
    result.update(record(relative, f"zettel-graph: add {relative}"))
    result["meta"] = reexport()
    return result


def publish(spec: dict) -> dict:
    if spec.get("all"):
        args = ["scripts/publish_md.py", "--all"]
    else:
        relative, _ = note_file(str(spec.get("note") or ""))
        args = ["scripts/publish_md.py", relative]

    started = time.time()
    proc = subprocess.run(
        [sys.executable, *args],
        cwd=str(CONFIG["vault"]),
        capture_output=True,
        text=True,
        timeout=600,
    )
    output = (proc.stdout + proc.stderr).strip()
    rendered = sorted(
        (p for p in (CONFIG["vault"] / "publish").rglob("*.pdf") if p.stat().st_mtime >= started - 1),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return {
        "ok": proc.returncode == 0,
        "files": [str(p.relative_to(CONFIG["vault"])) for p in rendered[:20]],
        "output": output[-4000:],
        "meta": reexport(),
    }


def read_body(handler: BaseHTTPRequestHandler) -> dict:
    length = int(handler.headers.get("Content-Length") or 0)
    if length <= 0 or length > MAX_NOTE + 4096:
        raise Refused(413, "missing or oversized body")
    try:
        return json.loads(handler.rfile.read(length))
    except ValueError:
        raise Refused(400, "body is not JSON") from None


class Handler(BaseHTTPRequestHandler):
    server_version = "zettel-graph"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("zettel-graph: " + (fmt % args) + "\n")

    # ---- responses -------------------------------------------------------
    def send_json(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def send_file(self, path: Path, ctype: str) -> None:
        try:
            payload = path.read_bytes()
        except OSError:
            raise Refused(404, f"{path.name} is not there") from None
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        # The vault moves under this URL; a cached copy would be yesterday's graph.
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def guard_write(self) -> None:
        if self.headers.get("X-Zettel-Write") != "1":
            raise Refused(403, "writes need X-Zettel-Write: 1")
        origin = self.headers.get("Origin")
        if origin and origin != CONFIG["origin"]:
            raise Refused(403, f"origin {origin} is not {CONFIG['origin']}")
        if (self.headers.get("Content-Type") or "").split(";")[0].strip() != "application/json":
            raise Refused(415, "body must be application/json")

    # ---- routes ----------------------------------------------------------
    def do_GET(self) -> None:
        self.route("GET")

    def do_PUT(self) -> None:
        self.route("PUT")

    def do_POST(self) -> None:
        self.route("POST")

    def route(self, method: str) -> None:
        path = unquote(urlsplit(self.path).path)
        try:
            if path in ("/graph.json", "/api/graph.json"):
                self.send_file(CONFIG["www"] / "graph.json", "application/json")
                return
            if path == "/api/health":
                meta = read_meta()
                self.send_json(200, {
                    "ok": bool(meta),
                    "notes": meta.get("notes", 0),
                    "links": meta.get("links", 0),
                    "generated": meta.get("generated", ""),
                    "vault": head(),
                    "write": True,
                    "publish": CONFIG["publish"],
                })
                return
            if path.startswith("/api/note/") and method == "GET":
                relative, note = note_file(path[len("/api/note/"):])
                self.send_json(200, {"id": relative, "text": note.read_text(encoding="utf-8")})
                return
            if path.startswith("/api/note/") and method == "PUT":
                self.guard_write()
                body = read_body(self)
                if not isinstance(body.get("text"), str):
                    raise Refused(400, "body is {text: <markdown>}")
                with MUTATE:
                    self.send_json(200, write_note(path[len("/api/note/"):], body["text"]))
                return
            if path == "/api/new" and method == "POST":
                self.guard_write()
                spec = read_body(self)
                with MUTATE:
                    self.send_json(201, create_note(spec))
                return
            if path == "/api/reload" and method == "POST":
                self.guard_write()
                with MUTATE:
                    self.send_json(200, {"ok": True, "meta": reexport()})
                return
            if path == "/api/publish" and method == "POST":
                self.guard_write()
                if not CONFIG["publish"]:
                    raise Refused(405, "publish is off on this host")
                spec = read_body(self)
                with MUTATE:
                    self.send_json(200, publish(spec))
                return
            if path.startswith("/publish/"):
                name = path[len("/publish/"):]
                if not PDF_RE.match(name):
                    raise Refused(400, "only a .pdf name is served here")
                self.send_file(CONFIG["vault"] / "publish" / name, "application/pdf")
                return
            if method == "GET":
                self.static(path)
                return
            raise Refused(405, f"{method} is not a route")
        except Refused as refusal:
            self.send_json(refusal.code, {"error": refusal.message})
        except BrokenPipeError:
            pass

    def static(self, path: str) -> None:
        www = CONFIG["www"]
        rel = "index.html" if path in ("", "/") else path.lstrip("/")
        candidate = (www / rel).resolve()
        if www.resolve() not in candidate.parents:
            raise Refused(404, "not found")
        if candidate.is_dir():
            raise Refused(404, "not found")
        ctype = {
            ".html": "text/html; charset=utf-8",
            ".json": "application/json",
            ".js": "text/javascript",
            ".css": "text/css",
            ".svg": "image/svg+xml",
            ".png": "image/png",
        }.get(candidate.suffix, "application/octet-stream")
        self.send_file(candidate, ctype)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--www", required=True, help="directory holding index.html and graph.json")
    parser.add_argument("--vault", required=True, help="vault checkout the exporter and publisher run in")
    parser.add_argument("--port", type=int, default=8083)
    parser.add_argument("--origin", required=True, help="the exact origin the page is served under")
    parser.add_argument("--ref", default="main", help="vault branch a write is pushed to")
    parser.add_argument("--commit", action="store_true")
    parser.add_argument("--push", action="store_true")
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args(argv)

    global CONFIG
    CONFIG = {
        "www": Path(args.www),
        "vault": Path(args.vault),
        "ref": args.ref,
        "commit": args.commit,
        "push": args.push,
        "publish": args.publish,
        "origin": args.origin.rstrip("/"),
        "git_name": "zettel-graph",
        "git_email": "zettel-graph@localhost",
    }

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"zettel-graph: http://127.0.0.1:{args.port} -> {args.www} (vault {args.vault})", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
