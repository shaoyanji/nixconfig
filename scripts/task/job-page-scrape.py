#!/usr/bin/env python3
"""List the postings on a JS-rendered career page, as JSON.

The board APIs `jobsearch-sweep.py` reads answer plain HTML for some ATSs and an
empty shell for others: Workday, Ashby, Lever and most Greenhouse boards build
the list in a framework, so the links exist only once a browser has run. This is
that browser, chosen by cost and falling through when a layer cannot answer:

  browser    agent-browser (headless Chrome): open, read the anchors, close
  firecrawl  POST /v1/scrape, markdown back (a hosted browser, no local Chrome)
  tavily     POST /extract, raw content back
  http       a plain GET plus JSON-LD — the page's own JobPosting data

Keys are read from `~/.hermes/.env` by name and never printed, so a run can be
piped somewhere without carrying a secret into the log. The extraction is
deliberately heuristic: a career page is not a schema, and the one thing worth
asserting is that a link the page shows as a posting is returned once, with a
title, and that a filter link, a nav link and a social link are not.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from html.parser import HTMLParser

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131 Safari/537.36"
)

# A posting URL, per ATS shape rather than per host: the same board runs on a
# company's own domain often enough that a host allowlist would miss half of it.
JOB_SHAPES = (
    re.compile(r"/jobs?/\d{3,}(?:/|$)"),  # greenhouse, personio, smartrecruiters
    re.compile(r"/job/\d{3,}(?:/|$)"),
    re.compile(
        r"/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?:/|$)"
    ),  # lever, ashby
    re.compile(r"/job/[A-Za-z0-9][\w%.-]{2,}(?:/|$)"),  # workday: Title_R-12345
    re.compile(r"/careers?/[a-z0-9-]+/[a-z0-9-]{3,}(?:/|$)"),
)
# A logo carried a UUID in its filename and read as a Lever posting until the
# shape was anchored and assets were refused outright.
ASSET = re.compile(r"\.(png|jpe?g|gif|svg|webp|ico|css|js|pdf)(?:\?|$)", re.I)
GH_JID = re.compile(r"(?:^|[?&])gh_jid=\d+")

NOT_A_POSTING = re.compile(
    r"/(login|signin|sign-in|register|privacy|terms|cookies?|legal|imprint|"
    r"help|faq|blog|news|press|about)(/|$)",
    re.I,
)
THIRD_PARTY = re.compile(
    r"(linkedin\.com|twitter\.com|x\.com|facebook\.com|instagram\.com|"
    r"youtube\.com|glassdoor\.com|google\.[a-z.]+/maps|apple\.com/app)",
    re.I,
)
NAV_TITLES = {
    "all",
    "apply",
    "back",
    "clear",
    "filter",
    "filters",
    "learn more",
    "load more",
    "more",
    "next",
    "previous",
    "remote",
    "reset",
    "see all",
    "see more",
    "show all",
    "show more",
    "view",
    "view all",
    "view job",
}
TRACKING_PARAMS = {"utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "ref"}


def canon(url: str) -> str:
    """The identity of a posting link: no fragment, no tracking, no trailing /."""
    parts = urllib.parse.urlsplit(url)
    query = urllib.parse.parse_qsl(parts.query, keep_blank_values=False)
    kept = [(k, v) for k, v in query if k not in TRACKING_PARAMS]
    path = parts.path.rstrip("/") or "/"
    return urllib.parse.urlunsplit(
        (parts.scheme, parts.netloc.lower(), path, urllib.parse.urlencode(kept), "")
    )


def is_posting(url: str) -> bool:
    if not url or not url.lower().startswith(("http://", "https://")):
        return False
    if THIRD_PARTY.search(url) or ASSET.search(urllib.parse.urlsplit(url).path):
        return False
    if GH_JID.search(urllib.parse.urlsplit(url).query):
        return True
    path = urllib.parse.urlsplit(url).path
    if NOT_A_POSTING.search(path):
        return False
    return any(shape.search(path) for shape in JOB_SHAPES)


META_MARKER = re.compile(r"\s+(?:hybrid|remote|on-?site)\s+[—–-]\s+", re.I)


def clean_title(text: str) -> str:
    """A card's text into its title.

    A rendered card hands the whole block back — `Sr. Customer Success Manager
    ST HYBRID — REGULAR FULL TIME (SALARY)ATLANTA, GEORGIA` — so the work-type
    marker ends the title, which is the boundary the page itself draws.
    """
    title = re.sub(r"\s+", " ", (strip_markdown(text) if text else "")).strip(" -|·—\t")
    marker = META_MARKER.search(title)
    if marker and marker.start() > 2:
        title = title[: marker.start()].strip()
    return title[:200]


def keep_title(title: str, allow_numeric: bool = False) -> bool:
    low = title.lower()
    if len(title) < 3 or low in NAV_TITLES:
        return False
    # A lone number or a filter chip is not a job title, except as a last
    # resort: `/jobs/4567890` with an "Apply" label is a posting, and dropping
    # it would lose the one thing the page was asked for.
    return allow_numeric or bool(re.search(r"[A-Za-z]", title))


def looks_like_location(text: str) -> bool:
    line = text.strip(" -|·—\t")
    if not line or len(line) > 60 or not re.search(r"[A-Za-z]", line):
        return False
    low = line.lower()
    return not low.startswith(("apply", "view", "learn", "read", "see", "show", "back"))


# Greenhouse cards put the city list straight after the title with no separator
# element, so "Applied Scientist, Engineering San Francisco, CA" is one text
# node. The suffix is `City, XX`, optionally `;`-separated, and the split has to
# prefer the city over the department: "Engineering San Francisco" is two words
# and looks exactly like a place until a role word is refused.
CITY_TAIL = re.compile(
    r"^[A-Z][\w .'’&()/-]{1,40},\s*(?:[A-Z]{2}|[A-Z][\w.]{1,20})"
    r"(?:\s*;\s*[A-Z][^;]{2,60})*$"
)
ROLE_WORDS = frozenset(
    """
    analyst assistant consultant customer data design director engineering
    engineer executive finance foundation global group growth head institute
    intern international lab labs lead learning legal manager marketing officer
    operations partner partnerships people platform policy principal product
    program research safety sales science security senior specialist staff
    success support systems team
    """.split()
)


def split_title_location(text: str):
    """A rendered card label into title and location."""
    title = clean_title(text)
    for word in re.finditer(r"\S+", title):
        start = word.start()
        if start < 3:
            continue
        candidate = title[start:]
        if not CITY_TAIL.match(candidate):
            continue
        city = candidate.split(",", 1)[0]
        words = city.replace("-", " ").split()
        bare = {w.strip("()&,;:'\"’‘….").lower() for w in words}
        if len(words) > 3 or ROLE_WORDS.intersection(bare):
            continue
        return title[:start].strip(" ,&|-–—"), re.sub(r"\s+", " ", candidate)[:80]
    return title, None


def strip_markdown(text: str) -> str:
    # A card label arrives with the page's own line breaks in it (`<br> <br>` on
    # Greenhouse), and a title that keeps them never matches the row twice.
    plain = re.sub(r"<br\s*/?>", " ", text or "", flags=re.I)
    plain = re.sub(r"<[^>]{1,80}>", " ", plain)
    plain = html.unescape(plain)
    return re.sub(r"[*_`]", "", plain.replace("\\", " ")).strip()


def slug_title(url: str):
    """A last-resort title: the posting's own slug."""
    slug = clean_title(urllib.parse.unquote(url.rstrip("/").rsplit("/", 1)[-1]))
    return slug if keep_title(slug, allow_numeric=True) else None


def from_anchors(pairs, page_url: str):
    """Postings from (href, label[, location]) triples, one row per URL.

    The same posting appears more than once on a real page: an "Apply" button
    with no title, and the card itself with the title. Collecting the best label
    per canonical URL rather than the first one is what turns those two anchors
    into one named posting.
    """
    order, best = [], {}
    for pair in pairs:
        href, label = pair[0], pair[1]
        location = pair[2] if len(pair) > 2 else None
        url = urllib.parse.urljoin(page_url, (href or "").strip())
        if not is_posting(url):
            continue
        key = canon(url)
        if key not in best:
            order.append(key)
            best[key] = {"title": None, "location": None}
        entry = best[key]
        cleaned, derived = split_title_location(strip_markdown(label))
        if entry["location"] is None:
            entry["location"] = (location or derived or None)
            if entry["location"]:
                entry["location"] = entry["location"][:80]
        if entry["title"] is None and keep_title(cleaned):
            entry["title"] = cleaned

    found = []
    for key in order:
        title = best[key]["title"] or slug_title(key)
        if not title:
            continue
        found.append({"title": title, "url": key, "location": best[key]["location"]})
    return found


# Lever and Ashby wrap the card label across lines inside the link, so the
# label has to be matched past a newline: a line-anchored regex found the
# "Apply" anchor and nothing else, and every title fell back to the UUID.
# The closing paren is optional: Firecrawl's Lever cards end the link at the
# URL, and requiring the paren made the card invisible while the "Apply"
# anchor next to it was found.
MD_LINK = re.compile(r"\[([^\]]{1,400})\]\((https?://[^)\s]+)\)?", re.S)
PAYLOAD = re.compile(r"\)\s*(.+)$")  # "(Salary)Atlanta, Georgia" -> the city


def split_label(label: str):
    """A card label into its title line and the location tail."""
    lines = [line for line in strip_markdown(label).splitlines() if line.strip()]
    if not lines:
        return "", None
    location = None
    if len(lines) > 1:
        tail = re.sub(r"\s+", " ", lines[1]).strip()
        match = PAYLOAD.search(tail)
        location = (match.group(1) if match else tail)[:80] or None
    return lines[0], location


def from_markdown(text: str, page_url: str):
    """Postings from Firecrawl/Tavily markdown, link label and following line."""
    pairs = []
    lines = text.splitlines()
    for label, href in MD_LINK.findall(text):
        title, location = split_label(label)
        pairs.append((href, title, location))
    for index, line in enumerate(lines):
        for _label, href in MD_LINK.findall(line):
            if index + 1 < len(lines) and looks_like_location(lines[index + 1]):
                pairs.append((href, "", lines[index + 1].strip()))
    return from_anchors(pairs, page_url)


class AnchorParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.pairs = []
        self._href = None
        self._text = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self._href = dict(attrs).get("href")
            self._text = []

    def handle_data(self, data):
        if self._href is not None:
            self._text.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self._href:
            self.pairs.append((self._href, "".join(self._text)))
            self._href = None


JSONLD = re.compile(
    r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
    re.I | re.S,
)


def from_jsonld(html: str):
    jobs = []
    for blob in JSONLD.findall(html):
        try:
            data = json.loads(blob.strip())
        except json.JSONDecodeError:
            continue
        for item in data if isinstance(data, list) else [data]:
            if not isinstance(item, dict):
                continue
            if item.get("@type") != "JobPosting":
                continue
            title = clean_title(str(item.get("title") or ""))
            url = item.get("url") or item.get("@id") or ""
            if title and url:
                jobs.append({"title": title, "url": canon(url), "location": None})
    return jobs


def from_html(html: str, page_url: str):
    jobs = from_jsonld(html)
    if jobs:
        return jobs
    parser = AnchorParser()
    try:
        parser.feed(html)
    except Exception:  # noqa: BLE001 - a malformed page is a page with fewer anchors
        pass
    return from_anchors(parser.pairs, page_url)


def load_keys(path: str, names) -> dict:
    """Named keys from an env file, never its other lines."""
    wanted = set(names)
    found = {}
    try:
        with open(os.path.expanduser(path), encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                name, value = line.split("=", 1)
                if name in wanted:
                    found[name] = value.strip().strip('"').strip("'")
    except OSError:
        pass
    for name in wanted:
        if os.environ.get(name):
            found[name] = os.environ[name]
    return found


class Unavailable(RuntimeError):
    """This layer cannot answer here; the next one may."""


def fetch_http(url: str, timeout: int) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", "replace")


# A card wraps its title in a heading; the anchor's own text also carries the
# work type and the city, so the heading is what the title is read from.
BROWSER_JS = (
    "JSON.stringify([...document.querySelectorAll('a[href]')].map(a=>{"
    "const h=a.querySelector('h1,h2,h3,h4,h5,h6');"
    "const t=h?(h.innerText||h.textContent||''):(a.innerText||a.textContent||'');"
    "return {h:a.href,t:String(t).trim().slice(0,200)};})"
    ".filter(x=>x.h&&x.t).slice(0,3000))"
)


def fetch_browser(url: str, timeout: int, binary: str) -> str:
    if not shutil.which(binary):
        raise Unavailable(f"{binary} is not on PATH")
    try:
        try:
            subprocess.run(
                [binary, "open", url], check=True, timeout=timeout, capture_output=True
            )
            result = subprocess.run(
                [binary, "eval", BROWSER_JS],
                check=True,
                timeout=timeout,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as exc:
            # A refused navigation is this layer's answer, not the run's: the
            # next backend may still read the page.
            detail = (exc.stderr or b"")
            if isinstance(detail, bytes):
                detail = detail.decode("utf-8", "replace")
            lines = [line for line in detail.strip().splitlines() if line.strip()]
            raise Unavailable(
                f"the browser could not open {url}: "
                f"{lines[-1][:160] if lines else f'exit {exc.returncode}'}"
            ) from exc
    finally:
        subprocess.run(
            [binary, "close"], timeout=30, capture_output=True, check=False
        )
    raw = result.stdout.strip()
    if not raw:
        raise Unavailable("the browser returned no anchors")
    try:
        value = json.loads(raw)
        if isinstance(value, str):  # the CLI prints a JSON value as a JSON string
            value = json.loads(value)
    except json.JSONDecodeError as exc:
        raise Unavailable(f"the browser answered unparsable JSON: {exc}") from exc
    return json.dumps([{"h": item.get("h"), "t": item.get("t")} for item in value])


def fetch_firecrawl(url: str, timeout: int, key: str) -> str:
    if not key:
        raise Unavailable("FIRECRAWL_API_KEY is not set")
    body = json.dumps({"url": url, "formats": ["markdown"], "onlyMainContent": True})
    request = urllib.request.Request(
        "https://api.firecrawl.dev/v1/scrape",
        data=body.encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    markdown = (payload.get("data") or {}).get("markdown") or ""
    if not markdown:
        raise Unavailable("firecrawl returned no markdown")
    return markdown


def fetch_tavily(url: str, timeout: int, key: str) -> str:
    if not key:
        raise Unavailable("TAVILY_API_KEY is not set")
    body = json.dumps({"urls": [url], "api_key": key})
    request = urllib.request.Request(
        "https://api.tavily.com/extract",
        data=body.encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    results = payload.get("results") or []
    content = (results[0].get("raw_content") if results else "") or ""
    if not content:
        raise Unavailable("tavily returned no content")
    return content


BACKENDS = ("auto", "browser", "firecrawl", "tavily", "http")


def collect(url: str, backend: str, args, keys: dict):
    order = {
        "auto": ["browser", "firecrawl", "http"],
        "browser": ["browser"],
        "firecrawl": ["firecrawl"],
        "tavily": ["tavily"],
        "http": ["http"],
    }[backend]
    warnings = []
    for name in order:
        try:
            if name == "browser":
                jobs = from_anchors(
                    [(a["h"], a["t"]) for a in json.loads(fetch_browser(url, args.timeout, args.agent_browser))],
                    url,
                )
            elif name == "firecrawl":
                jobs = from_markdown(fetch_firecrawl(url, args.timeout, keys.get("FIRECRAWL_API_KEY", "")), url)
            elif name == "tavily":
                jobs = from_markdown(fetch_tavily(url, args.timeout, keys.get("TAVILY_API_KEY", "")), url)
            else:
                jobs = from_html(fetch_http(url, args.timeout), url)
        except (
            Unavailable,
            urllib.error.URLError,
            TimeoutError,
            OSError,
            subprocess.SubprocessError,
        ) as exc:
            warnings.append(f"{name}: {str(exc)[:200]}")
            continue
        if not jobs:
            warnings.append(f"{name}: no postings recognised")
            continue
        return jobs, name, warnings
    return [], None, warnings


def main() -> int:
    parser = argparse.ArgumentParser(
        description="List the postings on a JS-rendered career page.",
        epilog="Exits 0 with an empty list when a page answers but has no postings.",
    )
    parser.add_argument("url", nargs="+", help="career page URL")
    parser.add_argument("--backend", choices=BACKENDS, default="auto")
    parser.add_argument("--max", type=int, default=0, help="cap postings per page")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--agent-browser", default="agent-browser")
    parser.add_argument("--env-file", default="~/.hermes/.env")
    parser.add_argument("--out", help="write the JSON here instead of stdout")
    parser.add_argument("--json", action="store_true", help="JSON even when a terminal")
    args = parser.parse_args()

    keys = load_keys(args.env_file, ("FIRECRAWL_API_KEY", "TAVILY_API_KEY"))
    results = []
    for url in args.url:
        jobs, used, warnings = collect(url, args.backend, args, keys)
        if args.max:
            jobs = jobs[: args.max]
        results.append(
            {
                "url": url,
                "backend": used,
                "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "count": len(jobs),
                "jobs": jobs,
                "warnings": warnings,
            }
        )

    payload = json.dumps(results, indent=2)
    if args.out:
        with open(os.path.expanduser(args.out), "w", encoding="utf-8") as handle:
            handle.write(payload + "\n")
    if args.json or args.out or not sys.stdout.isatty():
        print(payload)
    else:
        for page in results:
            print(f"{page['url']}  [{page['backend'] or 'unavailable'}]  {page['count']}")
            for job in page["jobs"]:
                print(f"  {job['title']}  —  {job['location'] or ''}  {job['url']}")
            for warning in page["warnings"]:
                print(f"  ! {warning}")
    return 0 if any(page["count"] for page in results) else 1


if __name__ == "__main__":
    sys.exit(main())
