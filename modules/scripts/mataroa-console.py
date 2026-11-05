#!/usr/bin/env python3
"""A tailnet console over a mataroa.blog blog, with markdown files as the source.

mataroa gives you a form in a browser and an API. Neither gives you a directory
of files you can grep, diff, commit or edit in vim, and the API alone makes
"what is on my blog?" a question you answer by reading HTTP. So this service
keeps the posts as files and treats the blog as a deployment target:

  $STATE/posts/<slug>.md     frontmatter `title`, `published_at`, then markdown
  GET  /                     the ledger: local files, and how each differs
  GET  /p/<slug>             one post, rendered
  GET  /e/<slug>             the editor (`/e/new` for a new one)
  POST /save                 write the file (no network)
  POST /publish              POST a new post or PATCH an existing one
  POST /unpublish            set published_at empty, which mataroa reads as draft
  POST /pull                 copy posts that exist only on the blog into files
  GET  /api/state            the same ledger as JSON
  GET  /api/post/<slug>      one post as JSON
  PUT  /api/post/<slug>      save it as JSON (this is the curl path)
  POST /api/publish/<slug>   publish it
  POST /api/unpublish/<slug> unpublish it
  POST /api/pull             import remote-only posts

There is no authentication of its own: the listener is loopback and the only
route in is the host's `tailscale serve` mount, so "on the tailnet" is the
fence. A write also needs `X-Mataroa-Write: 1` and, when the browser sends one,
an Origin equal to --origin: a page somewhere else can send a request to a
tailnet address without reading the answer, and this is what makes that request
not a write.

The token never leaves this process: it is read from LoadCredential, sent as a
bearer header, and never rendered, logged or written into a post file.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlsplit

SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,80}$")
MAX_BODY = 512 * 1024

CONFIG: dict = {}
MUTATE = threading.Lock()
REMOTE_CACHE = {"at": 0.0, "posts": {}, "error": ""}


class Refused(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


# ------------------------------------------------------------------ storage

def state_dir() -> Path:
    return CONFIG["state"]


def posts_dir() -> Path:
    d = state_dir() / "posts"
    d.mkdir(parents=True, exist_ok=True)
    return d


def post_path(slug: str) -> Path:
    if not SLUG_RE.match(slug or ""):
        raise Refused(400, f"bad slug {slug!r}")
    return posts_dir() / f"{slug}.md"


def slugify(title: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (title or "").lower()).strip("-")
    return slug[:80] or "untitled"


def parse_doc(text: str) -> tuple[dict, str]:
    meta, body = {}, text
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            for line in text[4:end].splitlines():
                if ":" in line:
                    key, _, value = line.partition(":")
                    meta[key.strip()] = value.strip().strip('"')
            body = text[end + 4 :].lstrip("\n")
    return meta, body


def read_post(slug: str) -> dict:
    path = post_path(slug)
    try:
        meta, body = parse_doc(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise Refused(404, f"no local post {slug}") from None
    return {
        "slug": slug,
        "title": meta.get("title") or slug.replace("-", " ").title(),
        "published_at": meta.get("published_at", ""),
        "body": body,
        "mtime": path.stat().st_mtime,
    }


def write_post(slug: str, title: str, body: str, published_at: str) -> dict:
    if len(body.encode("utf-8")) > MAX_BODY:
        raise Refused(413, f"body over {MAX_BODY} bytes")
    slug = (slug or slugify(title)).strip()
    path = post_path(slug)
    front = [f"title: {title.strip()}", f"published_at: {published_at.strip()}"]
    path.write_text("---\n" + "\n".join(front) + "\n---\n\n" + body.lstrip("\n") + "\n",
                    encoding="utf-8")
    git_commit(f"post: {slug}")
    return read_post(slug)


def list_local() -> list[dict]:
    out = []
    for path in sorted(posts_dir().glob("*.md")):
        try:
            out.append(read_post(path.stem))
        except Refused:
            continue
    out.sort(key=lambda p: (p["published_at"] or "", p["title"].lower()), reverse=True)
    return out


def git_commit(message: str) -> None:
    """The file history is the point; a missing git is not an error."""
    if not CONFIG.get("commit"):
        return
    repo = str(state_dir())
    # Identity on the command line, not in a config: the unit has no login shell
    # and its HOME is the state directory, so `git commit` found no user.name and
    # exited 128 — ten imported posts, an empty `git log`, and the edit trail the
    # docs promise did not exist (measured 2026-11-05).
    ident = [
        "-c", "user.name=mataroa-console",
        "-c", "user.email=mataroa-console@localhost",
        "-c", "commit.gpgsign=false",
    ]
    try:
        if not (state_dir() / ".git").is_dir():
            subprocess.run(["git", "init", "-q", repo], check=True, timeout=10)
        subprocess.run(["git", "-C", repo, "add", "-A"], check=True, timeout=10)
        run = subprocess.run(["git", "-C", repo, "diff", "--cached", "--quiet"], timeout=10)
        if run.returncode != 0:
            subprocess.run(["git", "-C", repo, *ident, "commit", "-q", "-m", message],
                           check=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as exc:
        sys.stderr.write(f"mataroa-console: git commit skipped ({exc})\n")


# -------------------------------------------------------------------- remote

def api(method: str, path: str, payload: dict | None = None) -> dict:
    token = CONFIG["token"]
    if not token:
        raise Refused(503, "no mataroa token in the environment")
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        CONFIG["api_base"].rstrip("/") + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as response:
            return json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:300]
        raise Refused(502, f"mataroa {method} {path} -> {exc.code}: {detail}") from None
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise Refused(502, f"mataroa {method} {path} failed: {exc}") from None


def remote_posts(refresh: bool = False) -> dict:
    now = time.time()
    if not refresh and now - REMOTE_CACHE["at"] < 30:
        return REMOTE_CACHE["posts"]
    try:
        listing = api("GET", "/posts/")
        posts = {p["slug"]: p for p in listing.get("post_list", []) if p.get("slug")}
        REMOTE_CACHE.update(at=now, posts=posts, error="")
    except Refused as exc:
        REMOTE_CACHE.update(at=now, posts={}, error=exc.message)
    return REMOTE_CACHE["posts"]


def ledger(refresh: bool = False) -> dict:
    local = {p["slug"]: p for p in list_local()}
    remote = remote_posts(refresh)
    rows = []
    for slug in sorted(set(local) | set(remote)):
        lp, rp = local.get(slug), remote.get(slug)
        if lp and rp:
            same = (lp["body"].strip() == (rp.get("body") or "").strip()
                    and lp["published_at"] == (rp.get("published_at") or ""))
            state = "in-sync" if same else "differs"
        elif lp:
            state = "local-only"
        else:
            state = "remote-only"
        rows.append({
            "slug": slug,
            "title": (lp or rp).get("title", slug),
            "published_at": (lp or {}).get("published_at", (rp or {}).get("published_at") or ""),
            "local": bool(lp),
            "remote": bool(rp),
            "state": state,
            "url": (rp or {}).get("url", ""),
        })
    rows.sort(key=lambda r: (r["published_at"] or "", r["title"].lower()), reverse=True)
    return {"posts": rows, "error": REMOTE_CACHE["error"], "remote_count": len(remote)}


def publish(slug: str, published_at: str | None = None) -> dict:
    post = read_post(slug)
    when = (published_at if published_at is not None else post["published_at"]) or ""
    payload = {"title": post["title"], "body": post["body"]}
    if when:
        payload["published_at"] = when
    known = remote_posts(refresh=True)
    if slug in known:
        result = api("PATCH", f"/posts/{quote(slug)}/", payload)
    else:
        if not when:
            payload["published_at"] = date.today().isoformat()
        result = api("POST", "/posts/", payload)
    new_slug = result.get("slug", slug)
    if new_slug != slug:
        post_path(slug).unlink(missing_ok=True)
    write_post(new_slug, post["title"], post["body"], payload.get("published_at", when))
    remote_posts(refresh=True)
    return {"slug": new_slug, "url": result.get("url", ""), "published_at": payload.get("published_at", "")}


def unpublish(slug: str) -> dict:
    read_post(slug)
    result = api("PATCH", f"/posts/{quote(slug)}/", {"published_at": ""})
    post = read_post(slug)
    write_post(slug, post["title"], post["body"], "")
    remote_posts(refresh=True)
    return {"slug": slug, "url": result.get("url", "")}


def pull() -> dict:
    remote = remote_posts(refresh=True)
    imported = []
    for slug, rp in remote.items():
        if not SLUG_RE.match(slug) or post_path(slug).exists():
            continue
        write_post(slug, rp.get("title") or slug, rp.get("body") or "", rp.get("published_at") or "")
        imported.append(slug)
    # Also on a pull that imported nothing: a repo whose earlier commits failed
    # still has files and no history, and this is the one call that repairs it.
    git_commit("pull: import remote posts")
    return {"imported": sorted(imported)}


# ------------------------------------------------------------------ markdown

def render(markdown: str) -> str:
    binary = CONFIG.get("comrak")
    if binary:
        try:
            proc = subprocess.run(
                [binary, "--unsafe", "-e", "table", "-e", "footnotes", "-e", "tasklist",
                 "-e", "strikethrough", "-e", "autolink", "--smart", "--gemoji"],
                input=markdown, capture_output=True, text=True, timeout=15,
            )
            if proc.returncode == 0:
                return proc.stdout
        except (OSError, subprocess.SubprocessError):
            pass
    import html
    return "<pre>" + html.escape(markdown) + "</pre>"


# ---------------------------------------------------------------------- page

STYLE = """
:root{--ink:#16130f;--paper:#faf7f0;--muted:#6d6558;--accent:#b23b1d;--line:#ddd5c6}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);
 font:16px/1.62 ui-serif,Georgia,serif}
header,main{max-width:60rem;margin:0 auto;padding:1.4rem 1.2rem}
header{display:flex;gap:1rem;align-items:baseline;flex-wrap:wrap;
 border-bottom:1px solid var(--line)}
header b{font:600 .78rem/1.4 ui-monospace,monospace;letter-spacing:.16em;text-transform:uppercase}
header a{color:var(--accent);text-decoration:none}
header .sp{flex:1}
nav a{margin-right:.9rem}
table{border-collapse:collapse;width:100%;font-size:.92rem}
td,th{padding:.42rem .5rem;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
th{font:400 .68rem/1.4 ui-monospace,monospace;letter-spacing:.12em;text-transform:uppercase;color:var(--muted)}
code,pre{font-family:ui-monospace,SFMono-Regular,monospace;font-size:.86rem}
pre{background:#f2ece0;padding:.8rem;overflow:auto}
a{color:var(--accent)}
input[type=text],input[type=date],textarea{width:100%;padding:.55rem;border:1px solid var(--line);
 background:#fffdf7;color:inherit;font:inherit}
textarea{min-height:26rem;font-family:ui-monospace,monospace;font-size:.88rem;line-height:1.55}
button{padding:.5rem .9rem;border:1px solid var(--ink);background:var(--ink);color:var(--paper);
 font:600 .74rem/1 ui-monospace,monospace;letter-spacing:.1em;text-transform:uppercase;cursor:pointer}
button.ghost{background:transparent;color:var(--ink)}
.row{display:grid;grid-template-columns:1fr auto;gap:1rem;align-items:end;margin-bottom:1rem}
.badge{font:400 .7rem/1.4 ui-monospace,monospace;padding:.1rem .45rem;border:1px solid var(--line);color:var(--muted)}
.badge.sync{border-color:#7a9b6a;color:#4d6b3f}
.badge.differs{border-color:#c58a2a;color:#8a5f15}
.badge.local-only{border-color:#9a9a9a}
.badge.remote-only{border-color:var(--accent);color:var(--accent)}
.note{color:var(--muted);font-size:.9rem}
.err{color:var(--accent)}
.actions{display:flex;gap:.6rem;flex-wrap:wrap;margin:1.2rem 0}
"""


def page(title: str, body: str) -> bytes:
    return (f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title><style>{STYLE}</style></head>
<body><header><b>mataroa console</b><nav>
<a href="/">ledger</a><a href="/e/new">new post</a>
</nav><span class="sp"></span>
<span class="note">{esc(CONFIG.get("blog_url") or "mataroa.blog")}</span>
</header><main>{body}</main></body></html>
""").encode("utf-8")


def esc(text: object) -> str:
    import html
    return html.escape(str(text), quote=True)


def ledger_page(data: dict) -> bytes:
    rows = []
    for row in data["posts"]:
        rows.append(
            f'<tr><td><a href="/p/{esc(row["slug"])}">{esc(row["title"])}</a></td>'
            f'<td><span class="badge {esc(row["state"])}">{esc(row["state"])}</span></td>'
            f'<td>{esc(row["published_at"] or "draft")}</td>'
            f'<td><a href="/e/{esc(row["slug"])}">edit</a>'
            + (f' · <a href="{esc(row["url"])}">live</a>' if row["url"] else "")
            + "</td></tr>"
        )
    error = (f'<p class="err">remote: {esc(data["error"])}</p>' if data["error"] else "")
    body = f"""<h1>Posts</h1>
<p class="note">{len(data["posts"])} local files · {data["remote_count"]} on the blog.
<div class="actions">
<form method="post" action="/pull"><button class="ghost">Pull remote-only</button></form>
</div>
{error}
<table><thead><tr><th>title</th><th>state</th><th>published</th><th></th></tr></thead>
<tbody>{''.join(rows) or '<tr><td colspan="4" class="note">no posts yet</td></tr>'}</tbody></table>"""
    return page("mataroa console", body)


def editor_page(post: dict | None, slug: str) -> bytes:
    post = post or {"title": "", "body": "", "published_at": ""}
    body = f"""<h1>{'Edit' if post["title"] else 'New post'}</h1>
<form method="post" action="/save">
<input type="hidden" name="slug" value="{esc(slug)}">
<div class="row"><div><label class="note">title</label>
<input type="text" name="title" value="{esc(post["title"])}" autofocus></div>
<div><label class="note">published</label>
<input type="date" name="published_at" value="{esc(post["published_at"])}"></div></div>
<label class="note">markdown</label>
<textarea name="body" spellcheck="false">{esc(post["body"])}</textarea>
<div class="actions">
<button>save file</button>
<button class="ghost" formaction="/publish">save and publish</button>
<button class="ghost" formaction="/unpublish">unpublish</button>
</div></form>
<p class="note">Files live in <code>posts/&lt;slug&gt;.md</code> on the host. Saving
commits the change; publishing sends it to mataroa and takes its slug back.</p>"""
    return page(f"edit {slug}", body)


def post_page(post: dict) -> bytes:
    body = f"""<h1>{esc(post["title"])}</h1>
<p class="note">{esc(post["published_at"] or "draft")} · <code>{esc(post["slug"])}</code>
· <a href="/e/{esc(post["slug"])}">edit</a></p>
<article>{render(post["body"])}</article>"""
    return page(post["title"], body)


# -------------------------------------------------------------------- server

class Handler(BaseHTTPRequestHandler):
    server_version = "mataroa-console"
    sys_version = ""

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))

    # -- helpers
    def send_body(self, status: int, payload: bytes, ctype: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def json(self, status: int, value: dict) -> None:
        self.send_body(status, json.dumps(value, indent=1).encode(), "application/json")

    def refuse(self, exc: Refused) -> None:
        self.json(exc.status, {"ok": False, "error": exc.message})

    def body_bytes(self) -> bytes:
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY * 2 or length < 0:
            raise Refused(413, "request body too large")
        return self.rfile.read(length) if length else b""

    def guard_write(self) -> None:
        """The curl path: an explicit header, plus the origin when one is sent."""
        if self.headers.get("X-Mataroa-Write") != "1":
            raise Refused(403, "writes need X-Mataroa-Write: 1")
        origin = self.headers.get("Origin")
        if origin and origin != CONFIG["origin"]:
            raise Refused(403, f"origin {origin} is not {CONFIG['origin']}")

    def guard_form(self) -> None:
        """The browser path: a form cannot set a header, so the Origin is the guard.

        Browsers send Origin on every form POST, so a page on another site cannot
        post here; a request with no Origin at all is not a browser form, and the
        documented scriptable path is the JSON API next to it.
        """
        if self.headers.get("Origin") != CONFIG["origin"]:
            raise Refused(403, "form posts must come from the console's own origin")

    def form(self) -> dict:
        raw = self.body_bytes().decode("utf-8")
        fields = {k: v[0] for k, v in parse_qs(raw, keep_blank_values=True).items()}
        return fields

    def json_body(self) -> dict:
        raw = self.body_bytes()
        if not raw:
            return {}
        try:
            value = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            raise Refused(400, "body is not JSON") from None
        if not isinstance(value, dict):
            raise Refused(400, "body must be a JSON object")
        return value

    # -- routing
    def do_GET(self) -> None:
        self.route("GET")

    def do_POST(self) -> None:
        self.route("POST")

    def do_PUT(self) -> None:
        self.route("PUT")

    def do_DELETE(self) -> None:
        self.route("DELETE")

    def route(self, method: str) -> None:
        path = unquote(urlsplit(self.path).path)
        try:
            if method == "GET" and path == "/":
                return self.send_body(200, ledger_page(ledger()), "text/html; charset=utf-8")
            if method == "GET" and path == "/api/state":
                return self.json(200, {"ok": True, **ledger(refresh=True)})
            if method == "GET" and path.startswith("/api/post/"):
                return self.json(200, {"ok": True, "post": read_post(path.rsplit("/", 1)[-1])})
            if method == "GET" and path.startswith("/p/"):
                return self.send_body(200, post_page(read_post(path[3:])), "text/html; charset=utf-8")
            if method == "GET" and path.startswith("/e/"):
                slug = path[3:]
                post = None if slug == "new" else read_post(slug)
                return self.send_body(200, editor_page(post, slug), "text/html; charset=utf-8")

            if method == "PUT" and path.startswith("/api/post/"):
                self.guard_write()
                slug = path.rsplit("/", 1)[-1]
                data = self.json_body()
                post = write_post(slug, data.get("title") or slug,
                                  data.get("body") or "", data.get("published_at") or "")
                return self.json(200, {"ok": True, "post": post})

            if method == "POST" and path.startswith("/api/publish/"):
                self.guard_write()
                slug = path.rsplit("/", 1)[-1]
                data = self.json_body()
                return self.json(200, {"ok": True, **publish(slug, data.get("published_at"))})

            if method == "POST" and path.startswith("/api/unpublish/"):
                self.guard_write()
                return self.json(200, {"ok": True, **unpublish(path.rsplit("/", 1)[-1])})

            if method == "POST" and path == "/api/pull":
                self.guard_write()
                return self.json(200, {"ok": True, **pull()})

            if method == "DELETE" and path.startswith("/api/post/"):
                self.guard_write()
                post_path(path.rsplit("/", 1)[-1]).unlink(missing_ok=True)
                git_commit("delete a local post")
                return self.json(200, {"ok": True})

            if method == "POST" and path in ("/save", "/publish", "/unpublish", "/pull"):
                self.guard_form()
                fields = self.form()
                if path == "/pull":
                    result = pull()
                    return self.redirect("/?pulled=" + ",".join(result["imported"]))
                slug = fields.get("slug") or "new"
                if slug == "new":
                    slug = ""
                if path in ("/save", "/publish"):
                    title = fields.get("title") or "untitled"
                    body = fields.get("body") or ""
                    published = fields.get("published_at") or ""
                    slug = write_post(slug, title, body, published)["slug"]
                    if path == "/publish":
                        publish(slug, published)
                elif path == "/unpublish":
                    unpublish(slug)
                return self.redirect(f"/e/{quote(slug)}")
            raise Refused(404, f"no route for {method} {path}")
        except Refused as exc:
            if path.startswith("/api/") or method in ("PUT", "DELETE"):
                return self.refuse(exc)
            body = f'<h1>{exc.status}</h1><p class="err">{esc(exc.message)}</p>'
            return self.send_body(exc.status, page("error", body), "text/html; charset=utf-8")
        except Exception as exc:  # noqa: BLE001 - a crash must not kill the daemon
            sys.stderr.write(f"mataroa-console: {type(exc).__name__}: {exc}\n")
            self.json(500, {"ok": False, "error": f"{type(exc).__name__}: {exc}"})

    def redirect(self, location: str) -> None:
        self.send_response(303)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.end_headers()


def main() -> int:
    parser = argparse.ArgumentParser(description="A tailnet console over a mataroa blog")
    parser.add_argument("--state", required=True, help="directory holding posts/ and .git")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--origin", required=True, help="exact tailnet origin a browser posts from")
    parser.add_argument("--api-base", default="https://mataroa.blog/api")
    parser.add_argument("--blog-url", default="")
    parser.add_argument("--comrak", default=shutil.which("comrak") or "")
    parser.add_argument("--no-commit", dest="commit", action="store_false")
    args = parser.parse_args()

    creds = os.environ.get("CREDENTIALS_DIRECTORY")
    token = ""
    if creds and (Path(creds) / "mataroa-token").is_file():
        token = (Path(creds) / "mataroa-token").read_text(encoding="utf-8").strip()
    token = token or os.environ.get("MATAROA_TOKEN", "").strip()

    CONFIG.update(
        state=Path(args.state), origin=args.origin.rstrip("/"), api_base=args.api_base,
        blog_url=args.blog_url, comrak=args.comrak, commit=args.commit, token=token,
    )
    posts_dir()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    sys.stderr.write(
        f"mataroa-console: http://127.0.0.1:{args.port} · state {args.state} · "
        f"token {'loaded' if token else 'MISSING'} · comrak {args.comrak or 'missing'}\n"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
