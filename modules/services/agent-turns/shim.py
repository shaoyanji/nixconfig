#!/usr/bin/env python3
"""The only network surface in front of the local xs store.

xs itself has no authentication and does have DELETE and POST /import, so the
append-only promise cannot be made by the store: it is made here, by exposing
exactly two routes and answering 405 to every other method.

  POST /v1/events   append one agent turn       -> 201 {"id": <frame id>}
  GET  /v1/events   query recent turns          -> 200 {"count": n, "events": [...]}
  GET  /healthz     liveness, no auth           -> 200 {"ok": true}

Everything else is 404 (unknown path) or 405 (update/delete). The store is
reached over its Unix socket only; this process never speaks TCP to xs.

One token per holder, never one shared token: a revoked agent must not take the
fleet's credential with it. AGENT_TURNS_TOKENS is `name=/path` pairs, colon
separated, and the access log names the token that authenticated.
"""

import base64
import hmac
import http.client
import json
import os
import re
import socket
import sqlite3
import sys
import threading
import urllib.parse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOPIC = "agent.turns"
MAX_BODY = 16 * 1024
DEFAULT_LIMIT = 50
MAX_LIMIT = 200

SOCKET_PATH = os.environ.get("XS_SOCKET", "")
TOKEN_SPEC = os.environ.get("AGENT_TURNS_TOKENS", "")
TOKEN_FILE = os.environ.get("AGENT_TURNS_TOKEN_FILE", "")  # one-token compatibility
DB_PATH = os.environ.get("AGENT_TURNS_DB", "")
BIND_HOST = os.environ.get("AGENT_TURNS_BIND", "127.0.0.1")
BIND_PORT = int(os.environ.get("AGENT_TURNS_PORT", "8093"))

FIELDS = {
    "id",
    "ts",
    "source",
    "kind",
    "subject",
    "action",
    "rationale",
    "base_commit",
    "branch",
    "files_changed",
    "commits",
    "outcome",
    "claims",
}

REQUIRED = {"id", "ts", "source", "kind", "subject", "action", "outcome"}

UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
TS_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$")
SOURCE_RE = re.compile(r"^[A-Za-z0-9._-]{1,64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{7,40}$")
BRANCH_RE = re.compile(r"^[A-Za-z0-9._/-]{1,200}$")
OUTCOME_RE = re.compile(r"^(done|in_progress|blocked|failed)(: .+)?$")

# Key material is refused in every field, including paths and hashes.
KEY_MATERIAL = [
    re.compile(r"-----BEGIN[A-Z ]*PRIVATE KEY"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"\bsk-[A-Za-z0-9]{16,}"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bage1[0-9a-z]{20,}\b"),
    re.compile(r"\bssh-(rsa|ed25519) AAAA[A-Za-z0-9+/=]{20,}"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\."),
]
# Credential-shaped prose is refused in the free-text fields. Paths and commit
# hashes are exempt: `modules/secrets.yaml` is an honest file name, not a secret.
SENSITIVE_WORD = re.compile(
    r"\b(password|passwd|passphrase|secret|api[_-]?key|apikey|access[_-]?token|"
    r"refresh[_-]?token|bearer\s+[A-Za-z0-9._~+/=-]{8,}|private[_-]?key)\b",
    re.IGNORECASE,
)
FREETEXT = ("source", "subject", "action", "rationale", "outcome")
FREETEXT_LIST = ("claims",)
MAX_FREETEXT = {"source": 64, "subject": 200, "action": 500, "rationale": 1000, "outcome": 300}

_lock = threading.Lock()


class BadRequest(Exception):
    pass


class AuthFailed(Exception):
    pass


def load_token(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            token = fh.read().strip()
    except OSError as exc:
        raise SystemExit(f"agent-turns shim: cannot read token file {path}: {exc}")
    if len(token) < 32:
        raise SystemExit(f"agent-turns shim: token in {path} is empty or too short; refusing to start")
    return token


def load_tokens(spec, legacy):
    """Map token name to token value, from `name=/path` pairs."""
    items = [item.strip() for item in spec.split(":") if item.strip()] if spec else []
    if legacy:
        items.append(legacy)
    if not items:
        raise SystemExit("agent-turns shim: no tokens configured (AGENT_TURNS_TOKENS); refusing to start")
    tokens = {}
    for item in items:
        name, sep, path = item.partition("=")
        if not sep:
            name, path = os.path.basename(item), item
        tokens[name] = load_token(path)
    return tokens


TOKENS = load_tokens(TOKEN_SPEC, TOKEN_FILE)


class UnixConnection(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__("localhost", timeout=10)
        self.unix_path = path

    def connect(self):
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect(self.unix_path)
        self.sock = sock


def xs_request(method, path, body=None):
    conn = UnixConnection(SOCKET_PATH)
    try:
        headers = {"Content-Type": "application/json"} if body is not None else {}
        conn.request(method, path, body=body, headers=headers)
        resp = conn.getresponse()
        payload = resp.read()
        return resp.status, payload
    finally:
        conn.close()


def xs_append(payload):
    status, body = xs_request("POST", f"/append/{TOPIC}?ttl=forever", payload)
    if status != 200:
        raise RuntimeError(f"xs append failed: HTTP {status}")
    frame = json.loads(body)
    return frame["id"]


def xs_last(limit):
    status, body = xs_request("GET", f"/last/{TOPIC}?last={limit}")
    if status == 404:
        return []
    if status != 200:
        raise RuntimeError(f"xs read failed: HTTP {status}")
    frames = []
    for line in body.decode("utf-8").splitlines():
        line = line.strip()
        if line:
            frames.append(json.loads(line))
    return frames


def xs_content(frame_hash):
    # Raw, not percent-encoded: the store matches the path segment verbatim, and
    # a base64 hash with a '/' in it still routes (measured against 0.14.2).
    status, body = xs_request("GET", f"/cas/{frame_hash}")
    if status != 200:
        return None
    try:
        return json.loads(body)
    except (ValueError, UnicodeDecodeError):
        return None


def validate(entry):
    unknown = set(entry) - FIELDS
    if unknown:
        raise BadRequest(f"unknown field(s): {', '.join(sorted(unknown))}")
    missing = REQUIRED - set(entry)
    if missing:
        raise BadRequest(f"missing field(s): {', '.join(sorted(missing))}")

    if entry["kind"] != "turn":
        raise BadRequest("kind must be 'turn'")
    if not UUID_RE.match(str(entry["id"])):
        raise BadRequest("id must be a client-generated UUID")
    if not TS_RE.match(str(entry["ts"])):
        raise BadRequest("ts must be an RFC 3339 timestamp with a timezone")
    try:
        datetime.fromisoformat(str(entry["ts"]).replace("Z", "+00:00"))
    except ValueError:
        raise BadRequest("ts is not a valid timestamp")
    if not SOURCE_RE.match(str(entry["source"])):
        raise BadRequest("source must be a short agent name")
    if not str(entry["subject"]).strip():
        raise BadRequest("subject must not be empty")
    if not str(entry["action"]).strip():
        raise BadRequest("action must not be empty")

    outcome = str(entry["outcome"])
    if not OUTCOME_RE.match(outcome):
        raise BadRequest("outcome must be done, in_progress, blocked or failed")
    if outcome.split(":", 1)[0] in ("blocked", "failed") and ":" not in outcome:
        raise BadRequest("a blocked or failed outcome needs a one-line note after ': '")

    for key, cap in MAX_FREETEXT.items():
        value = entry.get(key)
        if value is None:
            if key == "rationale":
                continue
            raise BadRequest(f"{key} must not be null")
        if not isinstance(value, str):
            raise BadRequest(f"{key} must be a string")
        if len(value) > cap:
            raise BadRequest(f"{key} is longer than {cap} characters")

    if entry.get("rationale") is not None and not isinstance(entry["rationale"], str):
        raise BadRequest("rationale must be a string or null")

    base = entry.get("base_commit")
    if base is not None and not COMMIT_RE.match(str(base)):
        raise BadRequest("base_commit must be a git commit hash or null")
    branch = entry.get("branch")
    if branch is not None and not BRANCH_RE.match(str(branch)):
        raise BadRequest("branch must be a branch name or null")

    for key in ("files_changed", "commits", "claims"):
        value = entry.get(key, [])
        if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
            raise BadRequest(f"{key} must be a list of strings")
        if len(value) > 100:
            raise BadRequest(f"{key} has more than 100 entries")
        if any(len(v) > 300 for v in value):
            raise BadRequest(f"{key} has an entry longer than 300 characters")
    for commit in entry.get("commits", []):
        if not COMMIT_RE.match(commit):
            raise BadRequest("commits must be git commit hashes")

    for pattern in KEY_MATERIAL:
        for key, value in entry.items():
            haystack = " ".join(value) if isinstance(value, list) else str(value)
            if pattern.search(haystack):
                raise BadRequest(f"field '{key}' contains key material; refusal")
    for key in FREETEXT:
        value = entry.get(key)
        if isinstance(value, str) and SENSITIVE_WORD.search(value):
            raise BadRequest(f"field '{key}' reads like it contains a credential; refusal")
    for key in FREETEXT_LIST:
        for item in entry.get(key, []):
            if SENSITIVE_WORD.search(item):
                raise BadRequest(f"field '{key}' reads like it contains a credential; refusal")


def canonical(entry):
    return json.dumps(entry, sort_keys=True, separators=(",", ":")).encode("utf-8")


def db():
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=FULL")
    conn.execute(
        "CREATE TABLE IF NOT EXISTS turn_dedup ("
        "client_uuid TEXT PRIMARY KEY, frame_id TEXT NOT NULL, created_at TEXT NOT NULL)"
    )
    return conn


def subject_repo(subject):
    """The schema carries the repo inside `subject` as `<repo>:<task>`."""
    return subject.split(":", 1)[0] if ":" in subject else None


class Handler(BaseHTTPRequestHandler):
    server_version = "agent-turns/1"
    sys_version = ""

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))

    def _send(self, status, payload, extra_headers=None):
        body = json.dumps(payload, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        for key, value in (extra_headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    token_name = None

    def _auth(self):
        header = self.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            raise AuthFailed("missing bearer token")
        presented = header[len("Bearer ") :].strip()
        # No early exit: a constant-time miss on every token does not leak which
        # slot matched, which matters once more than one holder exists.
        matched = None
        for name, token in TOKENS.items():
            if hmac.compare_digest(presented, token):
                matched = name
        if matched is None:
            raise AuthFailed("bad bearer token")
        self.token_name = matched

    def _read_body(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            raise BadRequest("bad Content-Length")
        if length <= 0:
            raise BadRequest("empty body")
        if length > MAX_BODY:
            raise BadRequest(f"body larger than {MAX_BODY} bytes")
        return self.rfile.read(length)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/healthz":
            self._send(200, {"ok": True})
            return
        if parsed.path != "/v1/events":
            self._send(404, {"error": "not found"})
            return
        try:
            self._auth()
        except AuthFailed as exc:
            self._send(401, {"error": str(exc)})
            return

        params = urllib.parse.parse_qs(parsed.query)
        try:
            limit = int(params.get("limit", [DEFAULT_LIMIT])[0])
        except ValueError:
            self._send(400, {"error": "limit must be an integer"})
            return
        limit = max(1, min(limit, MAX_LIMIT))
        want_subject = params.get("subject", [None])[0]
        want_repo = params.get("repo", [None])[0]
        want_source = params.get("source", [None])[0]

        try:
            frames = xs_last(limit)
        except Exception as exc:  # noqa: BLE001 - a dead store is a 502, not a crash
            self._send(502, {"error": f"store unavailable: {exc}"})
            return

        events = []
        for frame in frames:
            if frame.get("hash") is None:
                continue
            entry = xs_content(frame["hash"])
            if not isinstance(entry, dict):
                continue
            if want_subject and entry.get("subject") != want_subject:
                continue
            if want_repo:
                repo = subject_repo(str(entry.get("subject", "")))
                if repo != want_repo:
                    continue
            if want_source and entry.get("source") != want_source:
                continue
            entry["_frame"] = frame.get("id")
            events.append(entry)

        events.reverse()
        self._send(200, {"count": len(events), "scanned": len(frames), "events": events})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/v1/events":
            self._send(404, {"error": "not found"})
            return
        try:
            self._auth()
        except AuthFailed as exc:
            self._send(401, {"error": str(exc)})
            return
        try:
            raw = self._read_body()
            entry = json.loads(raw)
            if not isinstance(entry, dict):
                raise BadRequest("body must be a JSON object")
            validate(entry)
        except BadRequest as exc:
            self._send(400, {"error": str(exc)})
            return
        except (ValueError, UnicodeDecodeError):
            self._send(400, {"error": "malformed JSON"})
            return

        client_uuid = entry["id"]
        with _lock:
            conn = db()
            try:
                row = conn.execute(
                    "SELECT frame_id FROM turn_dedup WHERE client_uuid = ?", (client_uuid,)
                ).fetchone()
                if row is not None:
                    # Logged separately from a real append, so a replay does not
                    # read like a second turn when an operator counts the log.
                    sys.stderr.write(
                        f"dedup token={self.token_name} client={client_uuid} frame={row[0]}\n"
                    )
                    self._send(200, {"id": row[0], "client_uuid": client_uuid, "duplicate": True})
                    return
                conn.execute(
                    "INSERT INTO turn_dedup (client_uuid, frame_id, created_at) VALUES (?, ?, ?)",
                    (client_uuid, "", datetime.now(timezone.utc).isoformat()),
                )
                conn.commit()
                try:
                    frame_id = xs_append(canonical(entry))
                except Exception:
                    conn.execute("DELETE FROM turn_dedup WHERE client_uuid = ?", (client_uuid,))
                    conn.commit()
                    raise
                conn.execute(
                    "UPDATE turn_dedup SET frame_id = ? WHERE client_uuid = ?",
                    (frame_id, client_uuid),
                )
                conn.commit()
            except Exception as exc:  # noqa: BLE001
                self._send(502, {"error": f"append failed: {exc}"})
                return
            finally:
                conn.close()

        sys.stderr.write(f"append token={self.token_name} source={entry['source']} client={client_uuid}\n")
        self._send(201, {"id": frame_id, "client_uuid": client_uuid, "duplicate": False})

    def _readonly(self):
        self._send(405, {"error": "this endpoint is append-only"}, {"Allow": "GET, POST"})

    do_PUT = _readonly
    do_PATCH = _readonly
    do_DELETE = _readonly


def main():
    if not SOCKET_PATH or not os.path.exists(SOCKET_PATH):
        raise SystemExit(f"agent-turns shim: xs socket not found at {SOCKET_PATH!r}")
    if not DB_PATH:
        raise SystemExit("agent-turns shim: AGENT_TURNS_DB is not set")
    server = ThreadingHTTPServer((BIND_HOST, BIND_PORT), Handler)
    server.daemon_threads = True
    sys.stderr.write(f"agent-turns shim listening on {BIND_HOST}:{BIND_PORT}, store socket {SOCKET_PATH}\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
