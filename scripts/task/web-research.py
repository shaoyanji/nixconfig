#!/usr/bin/env python3
"""Search, extract and health-check the web from one command.

Three modes, one output contract, so an agent can cite what it read:

    web-research.py search "nix flake devshell" --max 5
    web-research.py extract https://nixos.org/manual/nix/stable/ --max-chars 4000
    web-research.py health https://example.com --via clanker

Providers are Context.dev, Tavily and Firecrawl (keys from `~/.hermes/.env`),
plus `agent-browser` — locally or on clanker over `task instabox:exec`. Search
asks every configured provider and merges, because they disagree more than they
overlap; extraction walks the layers until one returns text.

Every result carries a citation id (`s1`, `s2`, …) and a `sources` list with
URL, title and access time, and duplicates are collapsed by canonical URL so a
page two providers found is one source with two witnesses. `--format markdown`
renders that as a report: linked titles, `[sN]` citations in the text, and the
same ids resolved again under `## Sources`.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

UA = "nixconfig-web-research/1.0"
KEYS_FILE = "~/.hermes/.env"
KEY_NAMES = ("FIRECRAWL_API_KEY", "TAVILY_API_KEY", "CONTEXT_API_KEY", "CONTEXT_DEV_API_KEY")
# v2 answers `{success, data: {web: [...]}}`; v1's flat `data` list is what the
# deprecated endpoint returned, and its parser is kept so an older key still works.
FIRECRAWL_SEARCH = "https://api.firecrawl.dev/v2/search"

# Pages that answer 200 and still say nothing: a shell that needs JavaScript.
MIN_RENDERED_CHARS = 200


class Unavailable(RuntimeError):
    """This provider cannot answer here; the next one may."""


# -- identity --------------------------------------------------------------


def canonical(url: str) -> str:
    """The identity of a page: no fragment, no tracking, no trailing slash."""
    parts = urllib.parse.urlsplit((url or "").strip())
    query = [
        (k, v)
        for k, v in urllib.parse.parse_qsl(parts.query, keep_blank_values=False)
        if not k.lower().startswith("utm_")
        and k.lower() not in {"ref", "ref_src", "gclid", "fbclid", "mc_cid", "mc_eid"}
    ]
    path = parts.path.rstrip("/") or "/"
    return urllib.parse.urlunsplit(
        (parts.scheme.lower() or "https", parts.netloc.lower().removeprefix("www."), path, urllib.parse.urlencode(query), "")
    )


def host_of(url: str) -> str:
    return urllib.parse.urlsplit(url).netloc.lower().removeprefix("www.")


def clean(text: str, limit: int = 400) -> str:
    flat = re.sub(r"\s+", " ", (text or "")).strip()
    return flat[:limit]


# -- provider answers ------------------------------------------------------


def from_tavily(payload: dict) -> list:
    return [
        {"title": clean(item.get("title"), 200), "url": item.get("url", ""), "snippet": clean(item.get("content")), "score": item.get("score")}
        for item in payload.get("results") or []
        if item.get("url")
    ]


def from_context(payload: dict) -> list:
    return [
        {"title": clean(item.get("title"), 200), "url": item.get("url", ""), "snippet": clean(item.get("description")), "score": item.get("relevance")}
        for item in payload.get("results") or []
        if item.get("url")
    ]


def from_firecrawl(payload: dict) -> list:
    data = payload.get("data")
    if isinstance(data, dict):
        items = [item for block in data.values() if isinstance(block, list) for item in block]
    else:
        items = data or []
    return [
        {"title": clean(item.get("title"), 200), "url": item.get("url", ""), "snippet": clean(item.get("description") or item.get("markdown")), "score": None}
        for item in items
        if isinstance(item, dict) and item.get("url")
    ]


PARSERS = {"tavily": from_tavily, "context": from_context, "firecrawl": from_firecrawl}


def merge(results: list) -> list:
    """One entry per page, with every provider that found it kept as witness."""
    order, merged = [], {}
    for result in results:
        key = canonical(result.get("url", ""))
        if not key:
            continue
        if key not in merged:
            merged[key] = {
                "url": result["url"],
                "canonical": key,
                "title": result.get("title") or "",
                "snippet": result.get("snippet") or "",
                "providers": [],
            }
            order.append(key)
        entry = merged[key]
        provider = result.get("provider", "")
        if provider and provider not in entry["providers"]:
            entry["providers"].append(provider)
        if len(result.get("snippet") or "") > len(entry["snippet"]):
            entry["snippet"] = result["snippet"]
        if not entry["title"] and result.get("title"):
            entry["title"] = result["title"]
    return [merged[key] for key in order]


def cite(entries: list, accessed: str | None = None) -> tuple:
    """Number the results and list them as sources, one id per page."""
    stamp = accessed or datetime.now(timezone.utc).isoformat(timespec="seconds")
    for index, entry in enumerate(entries, start=1):
        entry["id"] = f"s{index}"
    sources = [
        {"id": entry["id"], "url": entry["url"], "title": entry.get("title") or "", "accessed": stamp}
        for entry in entries
    ]
    return entries, sources


# -- providers -------------------------------------------------------------


def load_keys(path: str = KEYS_FILE) -> dict:
    found = {}
    try:
        with open(os.path.expanduser(path), encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                name, value = line.split("=", 1)
                if name.strip() in KEY_NAMES:
                    found[name.strip()] = value.strip().strip('"').strip("'")
    except OSError:
        pass
    for name in KEY_NAMES:
        if os.environ.get(name):
            found[name] = os.environ[name]
    return found


def context_key(keys: dict) -> str:
    return keys.get("CONTEXT_API_KEY") or keys.get("CONTEXT_DEV_API_KEY") or ""


def post_json(url: str, body: dict, key: str = "", timeout: int = 60, auth: bool = True) -> dict:
    headers = {"Content-Type": "application/json", "User-Agent": UA}
    if auth and key:
        headers["Authorization"] = f"Bearer {key}"
    request = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise Unavailable(f"{host_of(url)} answered {exc.code}: {exc.read()[:200].decode('utf-8', 'replace')}") from exc
    except urllib.error.URLError as exc:
        raise Unavailable(f"{host_of(url)} unreachable: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise Unavailable(f"{host_of(url)} answered unparsable JSON: {exc}") from exc


def search_provider(provider: str, query: str, limit: int, keys: dict, timeout: int, depth: str = "basic") -> list:
    if provider == "tavily":
        key = keys.get("TAVILY_API_KEY", "")
        if not key:
            raise Unavailable("TAVILY_API_KEY is not set")
        payload = post_json(
            "https://api.tavily.com/search",
            {"query": query, "api_key": key, "max_results": limit, "search_depth": depth},
            timeout=timeout,
            auth=False,
        )
    elif provider == "context":
        key = context_key(keys)
        if not key:
            raise Unavailable("CONTEXT_API_KEY is not set")
        payload = post_json(
            "https://api.context.dev/v1/web/search",
            {"query": query, "numResults": limit},
            key=key,
            timeout=timeout,
        )
    else:
        key = keys.get("FIRECRAWL_API_KEY", "")
        if not key:
            raise Unavailable("FIRECRAWL_API_KEY is not set")
        payload = post_json(
            FIRECRAWL_SEARCH, {"query": query, "limit": limit}, key=key, timeout=timeout
        )
    results = PARSERS[provider](payload)
    for result in results:
        result["provider"] = provider
    warnings = []
    if provider == "firecrawl":
        notes = list(payload.get("warnings") or [])
        if payload.get("warning"):
            notes.append(payload["warning"])
        warnings.extend(f"firecrawl: {clean(note, 200)}" for note in notes if str(note).strip())
    return results, warnings


def extract_markdown(provider: str, url: str, keys: dict, timeout: int) -> str:
    if provider == "firecrawl":
        key = keys.get("FIRECRAWL_API_KEY", "")
        if not key:
            raise Unavailable("FIRECRAWL_API_KEY is not set")
        payload = post_json(
            "https://api.firecrawl.dev/v1/scrape",
            {"url": url, "formats": ["markdown"], "onlyMainContent": True},
            key=key,
            timeout=timeout,
        )
        markdown = (payload.get("data") or {}).get("markdown") or ""
    elif provider == "context":
        key = context_key(keys)
        if not key:
            raise Unavailable("CONTEXT_API_KEY is not set")
        payload = post_json(
            "https://api.context.dev/v1/web/scrape",
            {"url": url, "formats": {"markdown": True}, "sharedParams": {"mainContentOnly": True}},
            key=key,
            timeout=timeout,
        )
        block = payload.get("markdown") or {}
        markdown = (block.get("data") or "") if block.get("success") else ""
    elif provider == "tavily":
        key = keys.get("TAVILY_API_KEY", "")
        if not key:
            raise Unavailable("TAVILY_API_KEY is not set")
        payload = post_json("https://api.tavily.com/extract", {"urls": [url], "api_key": key}, timeout=timeout, auth=False)
        results = payload.get("results") or []
        markdown = (results[0].get("raw_content") if results else "") or ""
    else:
        request = urllib.request.Request(url, headers={"User-Agent": UA})
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                markdown = response.read().decode("utf-8", "replace")
        except (urllib.error.HTTPError, urllib.error.URLError) as exc:
            raise Unavailable(f"http fetch failed: {getattr(exc, 'reason', exc)}") from exc
    if not markdown.strip():
        raise Unavailable(f"{provider} returned no content")
    return markdown


# -- the browser, local or on clanker --------------------------------------


def browser_argv(via: str, binary: str, args: list) -> list:
    """`agent-browser …` here, or the same command inside clanker."""
    if via == "local":
        return [binary, *args]
    inner = "export PATH=$HOME/.nix-profile/bin:$PATH; " + " ".join([binary, *map(shlex.quote, args)])
    return ["task", "--silent", "instabox:exec", "--", "clanker", inner]


def run_browser(via: str, binary: str, args: list, timeout: int) -> str:
    argv = browser_argv(via, binary, args)
    try:
        result = subprocess.run(argv, check=True, timeout=timeout, capture_output=True, text=True)
    except FileNotFoundError as exc:
        raise Unavailable(f"{argv[0]} is not on PATH") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or "").strip().splitlines()
        raise Unavailable(f"browser command failed: {detail[-1][:160] if detail else exc.returncode}") from exc
    return result.stdout.strip()


PROBE_JS = (
    "JSON.stringify({title:document.title,ready:document.readyState,"
    "textChars:((document.body&&document.body.innerText)||'').length,"
    "links:document.querySelectorAll('a[href]').length,"
    "scripts:document.querySelectorAll('script').length,"
    "height:document.documentElement.scrollHeight,"
    "appMount:!!document.querySelector('#root,#__next,#app,[data-reactroot]')})"
)


def browser_text(via: str, binary: str, url: str, timeout: int) -> str:
    """The page's visible text, after its JavaScript ran."""
    run_browser(via, binary, ["open", url], timeout)
    try:
        raw = run_browser(via, binary, ["eval", "document.body?document.body.innerText:''"], timeout)
        # The CLI prints a JavaScript string as JSON, quotes included.
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            return raw
        return value if isinstance(value, str) else raw
    finally:
        try:
            run_browser(via, binary, ["close"], 30)
        except Unavailable:
            pass


def title_from_markdown(text: str) -> str:
    """A page's own heading, which markdown keeps as `# Title`."""
    for line in (text or "").splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            return clean(stripped[2:], 200)
    return ""


def probe_page(url: str, via: str, binary: str, timeout: int) -> dict:
    """What the browser actually rendered for a page, as measurements."""
    started = time.monotonic()
    http_status = 0
    try:
        request = urllib.request.Request(url, headers={"User-Agent": UA}, method="GET")
        with urllib.request.urlopen(request, timeout=min(timeout, 20)) as response:
            http_status = response.status
            response.read(2048)
    except urllib.error.HTTPError as exc:
        http_status = exc.code
    except (urllib.error.URLError, OSError):
        http_status = 0
    run_browser(via, binary, ["open", url], timeout)
    try:
        raw = run_browser(via, binary, ["eval", PROBE_JS], timeout)
    finally:
        try:
            run_browser(via, binary, ["close"], 30)
        except Unavailable:
            pass
    try:
        value = json.loads(raw)
        if isinstance(value, str):
            value = json.loads(value)
    except json.JSONDecodeError as exc:
        raise Unavailable(f"browser answered unparsable JSON: {exc}") from exc
    value.update({"url": url, "http_status": http_status, "ms": int((time.monotonic() - started) * 1000)})
    return value


def health_verdict(page: dict) -> tuple:
    """`ok` and the reasons a rendered page is not usable."""
    problems = []
    if page.get("http_status", 0) >= 400:
        problems.append(f"http {page['http_status']}")
    if page.get("ready") != "complete":
        problems.append(f"document {page.get('ready')}")
    if (page.get("textChars") or 0) < MIN_RENDERED_CHARS:
        problems.append(f"only {page.get('textChars') or 0} rendered chars")
    if not (page.get("title") or "").strip():
        problems.append("no title")
    if page.get("appMount") and (page.get("textChars") or 0) < MIN_RENDERED_CHARS:
        problems.append("app shell never hydrated")
    return (not problems), problems


# -- output ----------------------------------------------------------------


def to_toon(document) -> str:
    """TOON via the fleet's encoder, with a readable fallback if it is missing."""
    binary = shutil.which("toon")
    if binary:
        try:
            result = subprocess.run(
                [binary],
                input=json.dumps(document),
                check=True,
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.stdout.strip():
                return result.stdout.rstrip("\n")
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass
    return fallback_toon(document)


def fallback_toon(value, indent: int = 0) -> str:
    pad = "  " * indent
    if isinstance(value, dict):
        return "\n".join(f"{pad}{key}: {fallback_toon(item, indent + 1).lstrip()}" for key, item in value.items())
    if isinstance(value, list):
        if all(isinstance(item, dict) for item in value) and value:
            keys = list(value[0])
            rows = ["\n".join(f"{'  ' * (indent + 1)}{k}: {fallback_toon(value_row.get(k), indent + 2).lstrip()}" for k in keys) for value_row in value]
            return f"[{len(value)}]{{" + ",".join(keys) + "}:\n" + "\n".join(rows)
        return "\n".join(f"{pad}- {fallback_toon(item, indent + 1).lstrip()}" for item in value)
    if isinstance(value, str):
        return value
    return json.dumps(value)


MD_ESCAPE = {"\\": "\\\\", "[": "\\[", "]": "\\]"}


def md_text(value, limit: int = 240) -> str:
    """Text that cannot break the link it is printed inside."""
    return "".join(MD_ESCAPE.get(char, char) for char in clean(value, limit))


def md_snippet(value, limit: int = 200) -> str:
    """A one-line teaser: fences and escapes lifted from page text are noise."""
    text = clean(value, limit * 3).replace("`", "").replace("\\", "")
    text = re.sub(r"\s+", " ", text).strip()
    return text[:limit].rstrip() + ("…" if len(text) > limit else "")


def md_url(url: str) -> str:
    return (url or "").replace("(", "%28").replace(")", "%29").replace(" ", "%20")


def md_link(title: str, url: str) -> str:
    label = md_text(title, 200) or md_text(host_of(url), 200) or md_url(url)
    return f"[{label}]({md_url(url)})"


def md_cite(entry: dict) -> str:
    return f"[{entry.get('id') or 's?'}]({md_url(entry.get('url') or '')})"


def sources_markdown(sources: list) -> list:
    lines = ["## Sources", ""]
    for source in sources:
        url = source.get("url") or ""
        title = md_text(source.get("title") or "")
        label = f" — {title}" if title else f" — {md_text(host_of(url))}"
        stamp = f", accessed {source['accessed']}" if source.get("accessed") else ""
        lines.append(f"- **[{source.get('id')}]({md_url(url)})**{label}{stamp}")
    return lines


def warnings_markdown(warnings: list) -> list:
    if not warnings:
        return []
    return ["_Warnings_", ""] + [f"- {md_text(warning, 300)}" for warning in warnings] + [""]


def search_markdown(document: dict) -> list:
    count = document.get("count") or 0
    providers = ", ".join(document.get("providers") or []) or "none answered"
    lines = [f"# {md_text(document.get('query') or 'search', 200)}", ""]
    lines += [f"{count} result{'' if count == 1 else 's'} · providers: {providers}", ""]
    if not document.get("results"):
        lines += ["_No page was found; the warnings below say which layer refused._", ""]
    for entry in document.get("results") or []:
        snippet = md_snippet(entry.get("snippet") or "")
        tail = f" — {snippet}" if snippet else ""
        lines.append(f"- {md_link(entry.get('title'), entry.get('url'))} {md_cite(entry)}{tail}")
    lines.append("")
    lines += warnings_markdown(document.get("warnings") or [])
    lines += sources_markdown(document.get("sources") or [])
    return lines


def extract_report_markdown(document: dict) -> list:
    count = document.get("count") or 0
    lines = ["# Extract", "", f"{count} page{'' if count == 1 else 's'}", ""]
    for entry in document.get("results") or []:
        chars = entry.get("chars") or 0
        lines += [
            f"## {md_link(entry.get('title'), entry.get('url'))} {md_cite(entry)}",
            "",
            f"_{chars} chars via {entry.get('provider') or 'unknown'}_",
            "",
            (entry.get("markdown") or "").strip(),
            "",
        ]
    lines += warnings_markdown(document.get("warnings") or [])
    if document.get("sources"):
        lines += sources_markdown(document["sources"])
    return lines


def health_report_markdown(document: dict) -> list:
    healthy = document.get("healthy") or 0
    count = document.get("count") or 0
    lines = ["# Health", "", f"{healthy} of {count} rendered (via {document.get('via') or 'unknown'})", ""]
    for page in document.get("pages") or []:
        verdict = "ok" if page.get("ok") else "FAIL"
        facts = [f"{page.get('text_chars')} chars", f"{page.get('links')} links", f"http {page.get('http_status')}"]
        problems = "; ".join(page.get("problems") or [])
        line = f"- **{verdict}** {md_link(page.get('title'), page.get('url'))} — {', '.join(facts)}"
        lines.append(line + (f" · {md_text(problems, 300)}" if problems else ""))
    lines.append("")
    lines += warnings_markdown(document.get("warnings") or [])
    return lines


def markdown_report(document: dict) -> str:
    """A cited report: each hit names its source id, and every id resolves below."""
    mode = document.get("mode")
    if mode == "search":
        lines = search_markdown(document)
    elif mode == "extract":
        lines = extract_report_markdown(document)
    elif mode == "health":
        lines = health_report_markdown(document)
    else:
        lines = [f"# {mode or 'report'}", "", "```json", json.dumps(document, indent=2), "```"]
    return "\n".join(lines).rstrip() + "\n"


def emit(document: dict, fmt: str) -> None:
    if fmt == "markdown":
        print(markdown_report(document), end="")
    elif fmt == "toon":
        print(to_toon(document))
    else:
        print(json.dumps(document, indent=2))


# -- modes -----------------------------------------------------------------


def do_search(args, keys: dict) -> dict:
    providers = ["tavily", "context", "firecrawl"] if args.provider == "auto" else [args.provider]
    warnings, collected, used = [], [], []
    for provider in providers:
        try:
            results, notes = search_provider(provider, args.query, args.max, keys, args.timeout, args.depth)
        except Unavailable as exc:
            warnings.append(f"{provider}: {exc}")
            continue
        if not results:
            warnings.append(f"{provider}: no results")
            continue
        used.append(provider)
        collected.extend(results)
        warnings.extend(notes)
    entries = merge(collected)[: args.max]
    if args.fetch and entries:
        for entry in entries:
            try:
                entry["excerpt"] = clean(extract_markdown(args.fetch_provider or "firecrawl", entry["url"], keys, args.timeout), args.excerpt_chars)
            except Unavailable as exc:
                warnings.append(f"excerpt of {entry['url']}: {exc}")
    entries, sources = cite(entries)
    return {
        "mode": "search",
        "query": args.query,
        "providers": used,
        "count": len(entries),
        "results": entries,
        "sources": sources,
        "warnings": warnings,
    }


def do_extract(args, keys: dict) -> dict:
    order = {
        "auto": ["firecrawl", "context", "tavily", "browser", "http"],
        "browser": ["browser"],
        "firecrawl": ["firecrawl"],
        "context": ["context"],
        "tavily": ["tavily"],
        "http": ["http"],
    }[args.provider]
    warnings, entries = [], []
    for url in args.urls:
        for provider in order:
            try:
                if provider == "browser":
                    content = browser_text(args.via, args.agent_browser, url, args.timeout)
                else:
                    content = extract_markdown(provider, url, keys, args.timeout)
            except Unavailable as exc:
                warnings.append(f"{provider} {url}: {exc}")
                continue
            entries.append(
                {
                    "url": url,
                    "canonical": canonical(url),
                    "title": title_from_markdown(content),
                    "provider": provider,
                    "chars": len(content),
                    "markdown": content[: args.max_chars],
                }
            )
            break
        else:
            warnings.append(f"{url}: every provider refused")
    entries, sources = cite(entries)
    return {"mode": "extract", "count": len(entries), "results": entries, "sources": sources, "warnings": warnings}


def do_health(args, keys: dict) -> dict:
    pages, warnings = [], []
    for url in args.urls:
        try:
            page = probe_page(url, args.via, args.agent_browser, args.timeout)
        except Unavailable as exc:
            warnings.append(f"{url}: {exc}")
            pages.append({"url": url, "ok": False, "problems": [str(exc)], "via": args.via})
            continue
        ok, problems = health_verdict(page)
        pages.append(
            {
                "url": url,
                "ok": ok,
                "problems": problems,
                "title": page.get("title", ""),
                "http_status": page.get("http_status"),
                "text_chars": page.get("textChars"),
                "links": page.get("links"),
                "scripts": page.get("scripts"),
                "height": page.get("height"),
                "ms": page.get("ms"),
                "via": args.via,
            }
        )
    healthy = sum(1 for page in pages if page["ok"])
    return {
        "mode": "health",
        "via": args.via,
        "count": len(pages),
        "healthy": healthy,
        "pages": pages,
        "warnings": warnings,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Search, extract and health-check the web.")
    sub = parser.add_subparsers(dest="mode", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--format", choices=("json", "toon", "markdown"), default="json")
    common.add_argument("--timeout", type=int, default=90)
    common.add_argument("--via", choices=("local", "clanker"), default="clanker", help="where agent-browser runs")
    common.add_argument("--agent-browser", default="agent-browser")

    search = sub.add_parser("search", parents=[common], help="ask every configured provider")
    search.add_argument("query")
    search.add_argument("--provider", choices=("auto", "tavily", "context", "firecrawl"), default="auto")
    search.add_argument("--max", type=int, default=5)
    search.add_argument("--depth", choices=("basic", "advanced"), default="basic")
    search.add_argument("--fetch", action="store_true", help="attach an excerpt of each hit")
    search.add_argument("--fetch-provider", choices=("firecrawl", "context", "tavily"), default="firecrawl")
    search.add_argument("--excerpt-chars", type=int, default=600)

    extract = sub.add_parser("extract", parents=[common], help="page text, first provider that answers")
    extract.add_argument("urls", nargs="+")
    extract.add_argument("--provider", choices=("auto", "browser", "firecrawl", "context", "tavily", "http"), default="auto")
    extract.add_argument("--max-chars", type=int, default=20000)

    health = sub.add_parser("health", parents=[common], help="what a browser actually rendered")
    health.add_argument("urls", nargs="+")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    keys = load_keys()
    if args.mode == "search":
        document = do_search(args, keys)
        code = 0 if document["results"] else 1
    elif args.mode == "extract":
        document = do_extract(args, keys)
        code = 0 if document["results"] else 1
    else:
        document = do_health(args, keys)
        code = 0 if document["healthy"] else 1
    emit(document, args.format)
    return code


if __name__ == "__main__":
    sys.exit(main())
