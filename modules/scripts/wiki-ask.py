#!/usr/bin/env python3
"""wiki-ask — fan-out retrieval over local ZIM archives, gated to a token budget.

Measured limits this is built around (frieren, 2026-11-04):
  * `kiwix-search` ANDs its terms: "btrfs scrub repair EIO" returns 0 hits, so a
    long incident query has to be relaxed before it can retrieve anything;
  * it returns at most 10 titles per query, so recall comes from fanning out
    across archives and sub-queries, then fusing;
  * it returns titles only. Text comes from kiwix-serve /content over loopback.
  * `wikisearch` (the existing wrapper) picks the first archive in the library
    and prints raw titles, which is why a btrfs query answered "F2FS".

Stages, in order: relax -> fan out -> fuse (reciprocal rank) -> collapse
translation stubs -> gate on p -> quote the best-matching SECTION, not the lead.

Output is JSON (a program consumes it); `--toon` converts through `toon -e`
rather than emitting a hand-built shape. Every verdict is appended to a JSONL so
the gate can be calibrated and BM25's misses are measured, not argued about.
"""

import argparse
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
from xml.etree import ElementTree

LIBRARY = os.environ.get("KIWIX_LIBRARY", "/var/lib/kiwix/library.xml")
SERVE = os.environ.get("KIWIX_HOST", "http://127.0.0.1:8088").rstrip("/")
RRF_K = 60
ANSWER_P, EXPAND_P = 0.62, 0.38
STOP = {
    "the", "and", "for", "with", "from", "how", "what", "why", "does", "into", "not",
    "can", "you", "are", "was", "were", "when", "where", "which", "this", "that",
    "have", "has", "had", "but", "all", "any", "its", "it", "of", "on", "in", "to",
    "is", "a", "an", "as", "at", "by", "or", "if", "than", "then", "there", "their",
    # Filler verbs are the single biggest source of junk: `make` alone returns ten
    # Wikipedia titles per archive and outvotes the term that carries the question
    # (measured on "how do I make a nix flake devshell").
    "make", "makes", "use", "uses", "using", "get", "got", "create", "set", "run",
    "do", "configure", "need", "want", "help", "like", "just",
    "about", "after", "before", "should", "could", "would", "will", "may", "might",
    "must", "also", "more", "most", "very", "some", "such", "only", "over", "under",
    "during", "without", "within", "your", "our", "one", "two", "first", "last",
    "new", "old", "best", "good", "put", "take", "add", "tell", "give", "show",
    "here", "still", "same", "done", "doing", "go", "goes", "going", "me", "my",
}
TRANSLATION_WORDS = {
    "português", "portugues", "русский", "italiano", "magyar", "deutsch", "français",
    "español", "nederlands", "polski", "українська", "日本語", "中文", "한국어", "čeština",
    "türkçe", "svenska", "suomi", "dansk", "norsk", "ελληνικά", "עברית", "română",
    "lietuvių", "latviešu", "eesti", "slovenčina", "slovenščina", "hrvatski", "српски",
    "български", "македонски", "tiếng việt", "bahasa indonesia", "ไทย", "हिन्दी", "বাংলা",
}


# ---------------------------------------------------------------- archives ----
def load_archives():
    root = ElementTree.parse(LIBRARY).getroot()
    out = []
    for book in root.findall("book"):
        path = book.get("path", "")
        if not path or not os.path.exists(path):
            continue
        # kiwix-serve addresses a book by `<hash>-<stem>`, i.e. the ZIM's
        # basename — NOT library.xml's `name` or `id` attributes (both 404).
        out.append({
            "name": book.get("name", ""),
            "title": book.get("title", ""),
            "path": path,
            "book": os.path.basename(path)[: -len(".zim")] if path.endswith(".zim") else os.path.basename(path),
            "size": int(book.get("size", "0") or 0),
        })
    return out


# ------------------------------------------------------------ query anatomy ---
def terms_of(query):
    out = []
    for t in re.findall(r"[A-Za-z0-9_./+-]+", query):
        low = t.casefold()
        if low in STOP or len(low) < 2:
            continue
        out.append(low)
    seen, uniq = set(), []
    for t in out:
        if t not in seen:
            seen.add(t)
            uniq.append(t)
    return uniq


def term_weight(t):
    """Cheap rarity proxy: no corpus IDF available, so shape carries it."""
    w = 1.0
    if len(t) >= 6:
        w += 0.4
    if re.search(r"\d", t):
        w += 0.8
    if re.search(r"[A-Z]", t) and len(t) <= 6:
        w += 0.6
    if "/" in t or "=" in t or "_" in t:
        w += 0.4
    return w


def subqueries(query, terms, budget=5):
    """Long queries never match (AND semantics); relax until something does.

    Singles are chosen for specificity, not weight: `window` alone re-retrieves
    the same ten generic titles and crowds out the entity a question is about
    (`niri`, which `kiwix-search archlinux "niri"` ranks first).
    """
    qs = [(" ".join(terms), 1.0)]
    if len(terms) > 1:
        pairs = [" ".join(terms[i:i + 2]) for i in range(len(terms) - 1)]
        for p in pairs[:2]:
            qs.append((p, 0.85))
    singles = [t for t in terms if is_distinctive(t)]
    for t in sorted(singles, key=lambda t: -term_weight(t))[:2]:
        qs.append((t, 0.9))
    return qs[:budget]


def is_distinctive(t):
    return bool(re.search(r"\d", t)) or len(t) >= 4 or (t.isupper() and len(t) >= 3)


# ---------------------------------------------------------------- retrieval ---
def kiwix(*args, timeout=120):
    import subprocess

    try:
        r = subprocess.run(["kiwix-search", *args], capture_output=True, text=True, timeout=timeout)
    except Exception:
        return []
    return [l.strip() for l in r.stdout.splitlines() if l.strip()]


def gather(archives, query, max_streams, workers):
    terms = terms_of(query)
    jobs = []
    for a in archives:
        for sq, w in subqueries(query, terms, budget=max_streams):
            jobs.append((a, sq, w))

    # No suggest stream: `kiwix-search -s` costs 6-13 s on the 19M-article
    # Wikipedia (measured) and only walks title prefixes, which the article
    # titles already supply.
    def one(job):
        a, sq, w = job
        return (a["name"], w, sq, kiwix(a["path"], sq))

    streams = []
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for name, w, sq, titles in pool.map(one, jobs):
            if titles:
                streams.append({"archive": name, "query": sq, "weight": w, "titles": titles})
    return streams


def base_title(title):
    m = re.match(r"^(.*?)\s*\(([^)]+)\)\s*$", title.strip())
    if m and m.group(2).strip().casefold() in TRANSLATION_WORDS:
        return m.group(1).strip()
    return title.strip()


def title_key(title):
    return re.sub(r"[^a-z0-9]+", " ", base_title(title).casefold()).strip()


def in_title(term, title):
    toks = re.findall(r"[a-z0-9]+", base_title(title).casefold())
    return any(tok == term or (len(term) >= 5 and tok.startswith(term)) for tok in toks)


def title_coverage(title, terms, idf=None):
    """Weighted share of the query's terms the title itself names.

    Reciprocal-rank fusion alone let a fuzzy Xapian hit (`Steam Deck` for
    `code quantum`) outrank the article that literally holds the answer
    (`Surface code`). Terms are weighted by rarity *within the retrieved pool*,
    which is the only IDF available without an index: `window manager` matching
    two generic words must not beat `niri` matching the one word that names the
    subject.
    """
    toks = re.findall(r"[a-z0-9]+", base_title(title).casefold())
    if not terms or not toks:
        return 0.0
    idf = idf or {}
    num = den = 0.0
    for t in terms:
        w = term_weight(t) * idf.get(t, 1.0)
        den += w
        if any(tok == t or (len(t) >= 5 and (tok.startswith(t) or t.startswith(tok))) for tok in toks):
            num += w
    return num / den if den else 0.0


def fuse(streams, terms):
    score, info, order = {}, {}, []
    for s in streams:
        for rank, title in enumerate(s["titles"], start=1):
            k = title_key(title)
            if not k:
                continue
            if k not in score:
                score[k] = 0.0
                info[k] = {"title": base_title(title), "raw": title, "archives": [], "queries": []}
                order.append(k)
            score[k] += s["weight"] / (RRF_K + rank)
            if s["archive"] not in info[k]["archives"]:
                info[k]["archives"].append(s["archive"])
            if s["query"] not in info[k]["queries"]:
                info[k]["queries"].append(s["query"])

    # Pool IDF: a word in most retrieved titles says nothing about relevance.
    pool = len(order) or 1
    idf = {}
    for t in terms:
        df = sum(1 for k in order if t in re.findall(r"[a-z0-9]+", info[k]["title"].casefold()))
        idf[t] = 1.0 + math.log(1.0 + pool / (1.0 + df)) / 3.0

    qkey = title_key(" ".join(terms))
    for k in order:
        cov = title_coverage(info[k]["title"], terms, idf)
        mult = 1.0 + 2.5 * cov + (1.5 if k == qkey else 0.0)
        info[k]["coverage"] = round(cov, 2)
        info[k]["score"] = round(score[k] * mult, 5)
    return [{**info[k], "key": k} for k in sorted(order, key=lambda x: -info[x]["score"])], idf


# ------------------------------------------------------------ article text ----
class Sections(HTMLParser):
    """Article body as (heading, anchor, paragraph) triples."""

    def __init__(self):
        super().__init__()
        self.skip = 0
        self.heading = "Lead"
        self.anchor = ""
        self.buf = []
        self.rows = []
        self.pending_id = ""

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if tag in ("script", "style", "table", "nav"):
            self.skip += 1
        elif tag in ("h1", "h2", "h3", "h4"):
            self.flush()
            self.pending_id = d.get("id", "")
            self.buf = [f"\x00heading\x00"]
        elif tag in ("p", "li"):
            self.flush()

    def handle_endtag(self, tag):
        if tag in ("script", "style", "table", "nav") and self.skip:
            self.skip -= 1
        elif tag in ("h1", "h2", "h3", "h4"):
            text = re.sub(r"\s+", " ", "".join(self.buf).replace("\x00heading\x00", "")).strip()
            if text:
                self.heading, self.anchor = text, self.pending_id
            self.buf = []
        elif tag in ("p", "li"):
            self.flush()

    def handle_data(self, data):
        if not self.skip:
            self.buf.append(data)

    def flush(self):
        raw = "".join(self.buf).replace("\x00heading\x00", "")
        self.buf = []
        text = re.sub(r"\s+", " ", raw).strip()
        if len(text) > 40:
            self.rows.append((self.heading, self.anchor, text))


def article_sections(book, raw_title):
    url = f"{SERVE}/content/{book}/{urllib.parse.quote(raw_title.replace(' ', '_'))}"
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            html = r.read().decode("utf-8", "replace")
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        return []
    p = Sections()
    p.feed(html)
    p.flush()
    return p.rows


def strip_title_prefix(text, title):
    """Kiwix leads often repeat the article title before the first sentence."""
    pat = re.compile(re.escape(title.strip()), re.I)
    while True:
        m = pat.match(text.strip())
        if not m:
            return text.strip()
        text = text.strip()[m.end():].strip()


def best_passages(rows, terms, idf, limit_chars, top=2, require=None, title=""):
    """Score sections against the query; the heading counts double.

    `require` is the query's rarest term. A passage that never says the word the
    question is actually about is not evidence — it let a `niri window manager`
    question quote three paragraphs of generic window-manager prose.
    """
    if not rows:
        return []
    phrase = " ".join(terms)
    scored, seen = [], set()
    for heading, anchor, raw in rows:
        text = strip_title_prefix(raw, title)
        low, head = text.casefold(), heading.casefold()
        if len(text) < 60 or low == head or low in seen:
            continue
        if require and require not in low and require not in head:
            continue
        hit = sum(
            term_weight(t) * idf.get(t, 1.0) * (1.0 + (low.count(t) > 1))
            for t in terms
            if t in low
        )
        hit += 2.0 * sum(term_weight(t) * idf.get(t, 1.0) for t in terms if t in head)
        if phrase and phrase in low:
            hit += 3.0
        if hit <= 0:
            continue
        seen.add(low)
        scored.append((hit, heading, anchor, text))
    scored.sort(key=lambda r: -r[0])
    return [
        {"section": h, "anchor": a, "text": t[:limit_chars], "score": round(s, 2)}
        for s, h, a, t in scored[:top]
    ]


# -------------------------------------------------------------------- gate ----
def gate(cands, terms):
    if not cands:
        return 0.0, "abstain"
    top = cands[0]["score"]
    second = cands[1]["score"] if len(cands) > 1 else 0.0
    margin = (top - second) / top if top else 0.0
    agreement = min(len(cands[0]["archives"]), 2) / 2
    tset = set(re.findall(r"[a-z0-9]+", cands[0]["title"].casefold()))
    covered = len(set(terms) & tset) / max(len(terms), 1)
    p = 0.45 * margin + 0.30 * agreement + 0.25 * min(covered * 2, 1.0)
    p = max(0.0, min(1.0, p))
    verdict = "answer" if p >= ANSWER_P else ("expand" if p >= EXPAND_P else "abstain")
    return round(p, 3), verdict


def default_log():
    """Per-user state, not /var/lib: the tool runs unprivileged and a log that
    cannot be written is a log nobody keeps."""
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local/state")
    return os.path.join(base, "wiki-ask", "verdicts.jsonl")


def log_verdict(path, payload):
    if not path:
        return
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a") as fh:
            fh.write(json.dumps(payload) + "\n")
    except OSError:
        pass


def to_toon(obj):
    import subprocess

    try:
        r = subprocess.run(["toon", "-e"], input=json.dumps(obj), capture_output=True, text=True, timeout=30)
    except FileNotFoundError:
        print("wiki-ask: toon not on PATH; use --json", file=sys.stderr)
        return 1
    sys.stdout.write(r.stdout)
    return r.returncode


def main():
    ap = argparse.ArgumentParser(prog="wiki-ask", description="fan-out ZIM retrieval with a token gate")
    ap.add_argument("query", nargs="+")
    ap.add_argument("--budget", type=int, default=1200, help="token cap for quoted text (chars/4)")
    ap.add_argument("--candidates", type=int, default=8)
    ap.add_argument("--archive", action="append", default=[], help="only archives whose name contains this")
    ap.add_argument("--streams", type=int, default=5, help="sub-queries fan-out per archive")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--json", action="store_true", help="explicit JSON (default anyway)")
    ap.add_argument("--toon", action="store_true", help="convert the JSON through `toon -e`")
    ap.add_argument("--no-log", action="store_true")
    ap.add_argument("--log", default=os.environ.get("WIKI_ASK_LOG") or default_log())
    args = ap.parse_args()

    query = " ".join(args.query)
    started = time.time()
    archives = load_archives()
    if args.archive:
        archives = [a for a in archives if any(s in a["name"] for s in args.archive)]
    if not archives:
        print(f"wiki-ask: no archives resolved from {LIBRARY}", file=sys.stderr)
        return 2

    terms = terms_of(query)
    ranked, idf = fuse(gather(archives, query, args.streams, args.workers), terms)
    # Report only `--candidates`, but never truncate before the anchor step:
    # the entity page can sit at rank 10 behind generic pages that win on
    # stream count.
    cands = ranked[: args.candidates]
    p, verdict = gate(ranked, terms)
    # Whole-word title hits only: substring matching anchored `scrub` onto
    # "RAF Wormwood Scrubs". And `eio` appears in no title, so requiring it
    # would reject every passage on principle.
    df = {t: sum(1 for c in ranked if in_title(t, c["title"])) for t in terms}
    present = [t for t in terms if df[t] > 0]
    rare = max(present, key=lambda t: idf.get(t, 1.0)) if present else None

    # Fusion ranks; a genuinely rare term picks the evidence. The article that
    # names it is the article about it (`Niri` sits at rank 10 behind three
    # generic `window manager` pages that win on stream count), so it is quoted
    # first while the gate still reports the fused confidence. A term in more
    # than two titles is too generic to be an anchor.
    anchor_term = max(
        (t for t in terms if 0 < df[t] <= 2), key=lambda t: idf.get(t, 1.0), default=None
    )
    anchored = [c for c in ranked if anchor_term and in_title(anchor_term, c["title"])]
    quote_order = anchored + [c for c in ranked if c not in anchored]
    require = anchor_term or rare

    want = 2 if verdict == "answer" else (1 if verdict == "expand" else 0)
    per_chars = (220 if verdict == "answer" else 160) * 4
    by_name = {a["name"]: a for a in archives}
    quoted, spent = [], 0
    for c in quote_order[:4]:
        if len(quoted) >= want:
            break
        book = by_name.get(c["archives"][0], archives[0])["book"]
        rows = article_sections(book, c["raw"])
        # Fill `want` passages, not `want` candidates: a 276-byte stub article
        # must not consume a slot (`Ersatz capitalism (East Asia)` is one).
        for pg in best_passages(
            rows, terms, idf, per_chars, top=max(1, want - len(quoted)),
            require=require if verdict == "answer" else None, title=c["title"],
        ):
            cost = len(pg["text"]) // 4
            if spent + cost > args.budget:
                room = (args.budget - spent) * 4
                if room < 200:
                    break
                pg["text"] = pg["text"][:room]
                pg["tokens"] = len(pg["text"]) // 4
            else:
                pg["tokens"] = cost
            if not pg["text"]:
                continue
            quoted.append({"title": c["title"], "archive": c["archives"][0], **pg})
            spent += pg["tokens"]
            if spent >= args.budget:
                break

    # An `answer` whose own quotes never say the rarest term is an expand: the
    # ranking was confident, the evidence was not.
    evidence = bool(quoted)
    if verdict == "answer" and not evidence:
        verdict, p = "expand", round(min(p, ANSWER_P - 0.01), 3)

    result = {
        "query": query,
        "verdict": verdict,
        "p": p,
        "evidence": evidence,
        "anchor_term": anchor_term,
        "thresholds": {"answer": ANSWER_P, "expand": EXPAND_P},
        "ms": int((time.time() - started) * 1000),
        "tokens": spent,
        "budget": args.budget,
        "archives": [a["name"] for a in archives],
        "titles": [
            {"title": c["title"], "score": c["score"], "coverage": c["coverage"],
             "archives": c["archives"], "matched": c["queries"]}
            for c in cands
        ],
        "quoted": quoted,
    }

    if not args.no_log:
        log_verdict(args.log, {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "query": query, "verdict": verdict, "p": p, "ms": result["ms"],
            "tokens": spent, "top": result["titles"][0]["title"] if result["titles"] else None,
        })

    if args.toon:
        return to_toon(result)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
