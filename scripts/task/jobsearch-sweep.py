#!/usr/bin/env python3
"""Sweep five boards for in-lane leads, dedupe against the record, rank, emit JSON.

Reads nothing from the repo and writes nothing to the archive: it is the fetch,
filter and rank half of `apps:sweep:pipeline`, and the only network it touches is
the five boards plus `gh api` when --gh is passed. The held list is an argument
because the record lives in Postgres on delphi, not here.

Two rules are why this exists rather than an ad-hoc script per sweep:

  * a held employer is not a lead — the name normaliser strips legal suffixes,
    feed mojibake and the city Stepstone glues onto the employer, because a
    duplicate row is the failure `apps:add` exists to refuse;
  * an unverifiable employer name is not a lead either — a truncated name is
    reported under `rejected` with its reason instead of being filed, since a
    guessed name never matches the next sweep.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from collections import Counter
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131 Safari/537.36"
)

LANE = re.compile(
    r"(devops|dev[ -]ops|\bsre\b|site[ -]reliab|platform[ -]?(engineer|infra|operations)"
    r"|infrastructure[ -]?(engineer|operations|specialist|architect)"
    r"|cloud[ -]?(platform|engineer|infrastructure|operations|native)"
    r"|kubernetes|\bk8s\b|linux[ -](engineer|administrator|systems)|openshift)",
    re.I,
)
OUT = re.compile(
    r"(duales studium|studium|hochschule|embedded|softwareentwickler|software developer"
    r"|backend|frontend|fullstack|support|kundensupport|sales|vertrieb|\berp\b|\bsap\b"
    r"|datev|windows|m365|sharepoint|citrix|helpdesk|first[ -]level|werkstudent"
    r"|praktik|ausbildung|trainee|elektro|maschinenbau|mechanical|bauwesen|junior)",
    re.I,
)
AGENCY = re.compile(
    r"(consult|beratung|recruit|personalberatung|staffing|systemhaus"
    r"|managed services|outsourcing|dienstleist)",
    re.I,
)
BAD_LOC = re.compile(
    r"(us only|usa only|united states only|americas|asia|india|philippines"
    r"|canada only|latam|africa|australia|new zealand|japan|china)",
    re.I,
)
GOOD_LOC = re.compile(
    r"(germany|deutschland|berlin|munich|münchen|hamburg|stuttgart|köln|koeln"
    r"|frankfurt|düsseldorf|duesseldorf|leipzig|dresden|nürnberg|nuernberg"
    r"|karlsruhe|bremen|essen|hannover|bonn|mannheim|augsburg|wien|vienna|graz"
    r"|linz|zürich|zurich|basel|bern|europe|emea|anywhere|worldwide|remote)",
    re.I,
)
# A name the card markup truncated: a bare legal suffix, a leading city token, or
# a fragment that starts mid-word. Filing one poisons the dedupe forever.
TRUNCATED = re.compile(
    r"^(und|main|neuss|ismaning|center|development center|infrastructure|technology"
    r"|international services|migration|reliability)\b",
    re.I,
)
FEED_MOJIBAKE = {"Wrttemberg": "Württemberg", "Allgaeuer": "Allgäuer", "Muenchingen": "Münchingen"}

# Stepstone prints the city beside the employer ("Berlin Upvest GmbH") and its
# slug repeats the pair (…-Berlin-Upvest-GmbH--123-inline). A city word is not
# part of a company name: left in, it folds to a key the record does not hold, and
# sweep 2026-11-26c filed `Berlin Upvest GmbH`, `Porz plusserver gmbh` and
# `Lohne Rosenxt Group` as leads for three employers that were already tracked.
# Folded spellings only (umlauts expanded, no punctuation), because the token
# arrives as the board spelled it.
PLACES = frozenset(
    """
    berlin hamburg muenchen munich koeln cologne frankfurt stuttgart duesseldorf
    leipzig dresden nuernberg nurnberg hannover bremen essen dortmund bonn
    mannheim augsburg karlsruhe wiesbaden muenster kiel freiburg mainz erfurt
    potsdam rostock kassel saarbruecken ludwigshafen oldenburg osnabrueck
    leverkusen darmstadt heidelberg regensburg wuerzburg ingolstadt ulm aachen
    moenchengladbach krefeld duisburg bochum wuppertal bielefeld gelsenkirchen
    porz lohne ismaning neuss neubiberg garching unterschleissheim
    wien vienna graz linz salzburg innsbruck zuerich zurich basel bern genf
    geneva lausanne luzern
    """.split()
)


def fold_place(text: str) -> str:
    """The spelling PLACES uses, so `München`, `Muenchen` and `muenchen` are one token."""
    folded = (text or "").lower()
    for bad, good in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        folded = folded.replace(bad, good)
    return re.sub(r"[^a-z0-9]+", "", folded)


def tokens_of(text: str) -> list[str]:
    """The word tokens of a name, keeping internal capitals the board supplied."""
    return [token for token in re.split(r"[^0-9A-Za-zÄÖÜäöüß&]+", text or "") if token]


def strip_place_prefix(company: str) -> str:
    """`Berlin Upvest GmbH` -> `Upvest GmbH`: a leading city token belongs to the
    board, not the employer. A two-token name is left alone, because `Berlin
    Upvest` is as likely the employer's own wording as the board's prefix."""
    parts = tokens_of(company)
    if len(parts) > 2 and fold_place(parts[0]) in PLACES:
        return " ".join(parts[1:])
    return company


def company_from_slug(slug: str) -> str:
    """The employer words after the last city token of a Stepstone slug, or "" when
    the slug names no city: then it carries role words only and cannot name an
    employer, so the row is reported instead of being filed under an invented one
    (`split("-")[-3:]` turned …-DevOps-Engineer-Berlin-Upvest-GmbH into `Berlin
    Upvest GmbH`, gluing the city onto the name)."""
    parts = [part for part in slug.split("-") if part]
    boundary = None
    for index, part in enumerate(parts):
        if fold_place(part) in PLACES:
            boundary = index
    if boundary is None or boundary >= len(parts) - 1:
        return ""
    return " ".join(parts[boundary + 1:])


def held_match(company: str, held: set[str]) -> bool:
    """True when the record already holds this employer whatever prefix the board
    glued on: the full name, the brand token alone, or any trailing run of its
    tokens — `plusserver gmbh` inside `Porz plusserver gmbh`."""
    parts = tokens_of(company)
    if not parts:
        return False
    if norm(company) in held or norm(parts[0]) in held:
        return True
    return any(norm(" ".join(parts[index:])) in held for index in range(1, len(parts)))


def fetch(url: str, referer: str | None = None, timeout: int = 60) -> bytes:
    headers = {"User-Agent": UA}
    if referer:
        headers["Referer"] = referer
        headers["Accept-Language"] = "de-DE,de;q=0.9"
    req = urllib.request.Request(url, headers=headers)
    return urllib.request.urlopen(req, timeout=timeout).read()


def load_xml(raw: bytes) -> ET.Element:
    text = raw.decode("utf-8", "replace")
    for bad, good in (
        ("&nbsp;", "&#160;"), ("&mdash;", "&#8212;"), ("&ndash;", "&#8211;"),
        ("&rsquo;", "&#8217;"), ("&lsquo;", "&#8216;"), ("&ldquo;", "&#8220;"),
        ("&rdquo;", "&#8221;"), ("&hellip;", "&#8230;"), ("&uuml;", "&#252;"),
        ("&auml;", "&#228;"), ("&ouml;", "&#246;"), ("&szlig;", "&#223;"),
    ):
        text = text.replace(bad, good)
    text = re.sub(r"&(?!(?:amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)[a-zA-Z]+;", "", text)
    return ET.fromstring(text)


def fix_mojibake(text: str) -> str:
    for bad, good in FEED_MOJIBAKE.items():
        text = text.replace(bad, good)
    return text


def fold_umlauts(text: str) -> str:
    """`für` and `fuer` must fold to one key.

    Dropping the umlaut gives `fr`, which no board ever spells, so a record and
    an advert for the same employer could never match — Bundesamt für Migration
    und Flüchtlinge came back as a new lead on 2026-11-26 for exactly this.
    """
    if not text:
        return ""
    for bad, good in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss"),
                      ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue")):
        text = text.replace(bad, good)
    return text
def norm(text: str) -> str:
    """Fold a company name to the token a duplicate check compares."""
    text = fix_mojibake(html.unescape(text or "")).lower()
    text = re.sub(r"\(?\b[mwfdx]{1,2}(?:/[mwdx]{1,2}){1,3}\)?", " ", text)
    text = re.sub(
        r"\b(gmbh|ag|se|mbh|kg|ug|ohg|ev|inc|ltd|llc|group|holding|deutschland"
        r"|germany|gemeinnuetzige|gemeinnützige|co)\b\.?",
        " ",
        text,
    )
    text = fold_umlauts(text)
    return re.sub(r"[^a-z0-9]+", "", text)


def clean(text: str) -> str:
    text = html.unescape(re.sub(r"<[^>]+>", " ", text or ""))
    text = re.sub(r"\((?:m/w/d|w/m/d|m/f/d|all genders|gn|d/m/f|d/f/m|\*)\)", "", text, flags=re.I)
    return re.sub(r"\s+", " ", text).strip(" -–@|*")


def recency(value: str) -> int | None:
    if not value:
        return None
    if re.match(r"^\d{4}-\d\d-\d\d", value):
        try:
            stamp = datetime.strptime(value[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc)
            return (datetime.now(timezone.utc) - stamp).days
        except ValueError:
            return None
    if re.match(r"^(today|heute)\b", value, re.I):
        return 0
    if re.match(r"^(gestern|yesterday)\b", value, re.I):
        return 1
    match = re.match(
        r"(?:vor\s+)?(\d+)\s*(minute|minuten|hour|stunde|stunden|tag|tagen|day|days"
        r"|woche|wochen|week|weeks)",
        value,
        re.I,
    )
    if match:
        count, unit = int(match.group(1)), match.group(2).lower()
        if unit.startswith(("minute", "hour", "stunde")):
            return 0
        if unit.startswith(("woche", "week")):
            return count * 7
        return count
    try:
        return (datetime.now(timezone.utc) - parsedate_to_datetime(value)).days
    except (TypeError, ValueError):
        return None


def parse_boards(
    boards: set[str], stepstone_pages: list[tuple[str, str]]
) -> tuple[list[dict], list[dict]]:
    rows: list[dict] = []
    unnameable: list[dict] = []

    def add(board, company, title, loc, url, date):
        title, company = clean(title), fix_mojibake(clean(company))
        if company and title and "{" not in title and "box-sizing" not in title:
            rows.append(
                dict(board=board, company=company, title=title, loc=clean(loc),
                     url=url or "", date=date or "")
            )
        elif board == "stepstone" and not company and title and "{" not in title:
            unnameable.append(
                dict(company="", title=clean(title)[:80], board=board, url=url or "",
                     reason="employer missing from the card markup and not derivable from the slug")
            )

    if "germantechjobs" in boards:
        root = load_xml(fetch("https://germantechjobs.de/rss", timeout=120))
        for item in root.find("channel").findall("item"):
            match = re.match(r"(.*?)\s*@\s*(.+?)(?:\s*\[([^\]]*)\])?$", item.findtext("title") or "")
            if match:
                add("germantechjobs", match.group(2), match.group(1), "",
                    (item.findtext("link") or "").split("?")[0], item.findtext("pubDate"))
    if "weworkremotely" in boards:
        root = load_xml(fetch("https://weworkremotely.com/categories/remote-devops-sysadmin-jobs.rss"))
        for item in root.find("channel").findall("item"):
            raw = item.findtext("title") or ""
            if ":" in raw:
                company, title = raw.split(":", 1)
                add("weworkremotely", company, title, item.findtext("region"),
                    item.findtext("link"), item.findtext("pubDate"))
    if "remoteok" in boards:
        for entry in json.loads(fetch("https://remoteok.com/api")):
            if "position" in entry:
                add("remoteok", entry.get("company", ""), entry.get("position", ""),
                    entry.get("location", ""), entry.get("url", ""), entry.get("date", ""))
    if "berlinstartupjobs" in boards:
        try:
            root = load_xml(fetch("https://berlinstartupjobs.com/feed/", referer="https://berlinstartupjobs.com/"))
            for item in root.find("channel").findall("item"):
                match = re.match(r"(.*?)\s+(?:at|@)\s+(.+)$", item.findtext("title") or "")
                if match:
                    add("berlinstartupjobs", match.group(2), match.group(1), "Berlin",
                        item.findtext("link"), item.findtext("pubDate"))
        except Exception as exc:  # a board that refuses is unfetched, not empty
            print(f"jobsearch-sweep: bsj unavailable: {exc}", file=sys.stderr)
    if "stepstone" in boards:
        seen: set[str] = set()
        for query, city in stepstone_pages:
            try:
                page = fetch(
                    f"https://www.stepstone.de/jobs/{query}?radius=30&where={city}",
                    referer="https://www.stepstone.de/",
                ).decode("utf-8", "replace")
            except Exception as exc:
                print(f"jobsearch-sweep: stepstone {query}/{city}: {exc}", file=sys.stderr)
                continue
            for block in page.split('data-at="job-item"')[1:]:
                block = block[:24000]
                link = re.search(
                    r'data-at="job-item-title"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', block, re.S
                )
                if not link or link.group(1) in seen:
                    continue
                seen.add(link.group(1))
                loc = re.search(r'data-at="job-item-location"[^>]*>(.*?)</', block, re.S)
                when = re.search(r'data-at="job-item-timeago"[^>]*>(.*?)</', block, re.S)
                company = ""
                for pattern in (
                    r'data-at="company-logo"[^>]*alt="([^"]+)"',
                    r'data-at="company-logo"[^>]*title="([^"]+)"',
                ):
                    found = re.search(pattern, block)
                    if found:
                        company = clean(found.group(1))
                        break
                if not company:
                    found = re.search(
                        r'data-at="job-item-company-name"[^>]*>(.*?)</(?:span|div|p|a)>', block, re.S
                    )
                    if found:
                        company = clean(found.group(1))
                if not company:
                    slug = re.search(r"stellenangebote--(.+?)--\d+-inline", link.group(1))
                    company = company_from_slug(slug.group(1)) if slug else ""
                company = strip_place_prefix(company)
                add("stepstone", company, link.group(2),
                    clean(loc.group(1)) if loc else "", link.group(1),
                    clean(when.group(1)) if when else "")
            time.sleep(0.8)
    return rows, unnameable


def gh_activity(company: str) -> dict | None:
    """Best-effort org lookup: a company's public repo cadence, when it has one."""
    tokens = sorted(
        {t for t in re.split(r"[^a-z0-9]+", company.lower()) if len(t) >= 4},
        key=len,
        reverse=True,
    )[:2]
    for slug in dict.fromkeys(tokens + [re.sub(r"[^a-z0-9]+", "", company.lower())]):
        if len(slug) < 4:
            continue
        proc = subprocess.run(["gh", "api", f"/orgs/{slug}"], capture_output=True, text=True)
        if proc.returncode != 0 or not proc.stdout.strip():
            continue
        org = json.loads(proc.stdout)
        if org.get("type") not in ("Organization", "User"):
            continue
        ident = [org.get("login", "").lower().replace("-", ""),
                 (org.get("name") or "").lower().replace(" ", "").replace("-", "")]
        folded = norm(company)
        if not any(i and len(i) >= 4 and i in folded for i in ident):
            continue
        repos = subprocess.run(
            ["gh", "api", f"/orgs/{slug}/repos?sort=pushed&per_page=20"],
            capture_output=True, text=True,
        )
        if repos.returncode != 0:
            return None
        try:
            listing = json.loads(repos.stdout)
        except json.JSONDecodeError:
            return None
        stamps = [r.get("pushed_at") or "" for r in listing if isinstance(r, dict)]
        newest = max(stamps) if stamps else ""
        days = recency(newest) if newest else None
        return dict(slug=slug, last=newest[:10], days=days)
    return None


def self_test() -> int:
    """Offline proof of the two name rules, over the shapes sweep 2026-11-26c
    produced and the slug spellings Stepstone emits. No board is fetched."""
    failures = 0
    total = 0

    def check(label: str, got, want) -> None:
        nonlocal failures, total
        total += 1
        if got != want:
            print(f"FAIL  {label}: got {got!r}, want {want!r}")
            failures += 1
        else:
            print(f"ok    {label}")

    check("city prefix: Berlin Upvest GmbH", strip_place_prefix("Berlin Upvest GmbH"), "Upvest GmbH")
    check("city prefix: Porz plusserver gmbh", strip_place_prefix("Porz plusserver gmbh"), "plusserver gmbh")
    check("city prefix: Lohne Rosenxt Group", strip_place_prefix("Lohne Rosenxt Group"), "Rosenxt Group")
    check("city prefix: Muenchen Acme AG", strip_place_prefix("Muenchen Acme AG"), "Acme AG")
    check("city prefix: München Acme AG folds too", strip_place_prefix("München Acme AG"), "Acme AG")
    check("clean name untouched", strip_place_prefix("Rosenxt Group"), "Rosenxt Group")
    check("two-token name untouched", strip_place_prefix("Berlin Upvest"), "Berlin Upvest")
    check("non-place first token untouched", strip_place_prefix("Zalando SE"), "Zalando SE")
    check("slug: role, city, employer", company_from_slug("DevOps-Engineer-Berlin-Upvest-GmbH"), "Upvest GmbH")
    check("slug: SRE Muenchen", company_from_slug("Senior-SRE-Muenchen-Acme-AG"), "Acme AG")
    check("slug: no city is not a name", company_from_slug("DevOps-Engineer"), "")
    check("slug: city alone is not a name", company_from_slug("Berlin"), "")
    held = {norm("Upvest GmbH"), norm("plusserver gmbh"), norm("Rosenxt Group")}
    check("held: city-prefixed name matches", held_match(strip_place_prefix("Berlin Upvest GmbH"), held), True)
    check("held: prefixed name matches by suffix", held_match("Porz plusserver gmbh", held), True)
    check("held: brand token alone matches", held_match("plusserver", held), True)
    check("held: a new employer does not", held_match("Zalando SE", held), False)
    check("key: prefixed and clean names fold alike", norm(strip_place_prefix("Berlin Upvest GmbH")), norm("Upvest GmbH"))
    check(
        "key: the three sweep 2026-11-26c duplicates fold onto their held rows",
        [norm(strip_place_prefix(n)) for n in ("Berlin Upvest GmbH", "Porz plusserver gmbh", "Lohne Rosenxt Group")],
        [norm(n) for n in ("Upvest GmbH", "plusserver gmbh", "Rosenxt Group")],
    )
    check("umlauts: Kältemaschinen folds onto Kaeltemaschinen",
          norm("Kältemaschinen"), norm("Kaeltemaschinen"))
    check("umlauts: für and fuer agree", norm("für"), norm("fuer"))
    print(f"{total - failures}/{total} passed")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--held", help="file of employer names the record already holds (needed unless --self-test)")
    ap.add_argument("--self-test", action="store_true", help="prove the name rules offline and exit")
    ap.add_argument("--out", help="write the ranked JSON here instead of stdout")
    ap.add_argument("--max-age", type=int, default=7, help="days a posting may be old")
    ap.add_argument("--limit", type=int, default=25, help="employers to report")
    ap.add_argument("--boards", default="germantechjobs,weworkremotely,remoteok,berlinstartupjobs,stepstone")
    ap.add_argument("--stepstone-queries", default="devops,platform,sre,cloud,infrastructure,kubernetes")
    ap.add_argument("--stepstone-cities", default="Berlin,Muenchen,Hamburg,Koeln")
    ap.add_argument("--gh", action="store_true", help="attribute GitHub activity (bounded gh api calls)")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if not args.held:
        ap.error("--held is required outside --self-test")

    boards = {b.strip() for b in args.boards.split(",") if b.strip()}
    pages = [
        (q.strip(), c.strip())
        for q in args.stepstone_queries.split(",")
        for c in args.stepstone_cities.split(",")
    ] if "stepstone" in boards else []

    rows, unnameable = parse_boards(boards, pages)
    held = {norm(line.strip()) for line in open(args.held, encoding="utf-8") if line.strip()}

    def in_lane(row: dict) -> bool:
        if not LANE.search(row["title"]) or OUT.search(row["title"]):
            return False
        if row["loc"] and BAD_LOC.search(row["loc"]) and not GOOD_LOC.search(row["loc"]):
            return False
        if row["board"] in ("remoteok", "weworkremotely") and row["loc"] and not GOOD_LOC.search(row["loc"]):
            return False
        return True

    fresh = [
        row for row in rows
        if in_lane(row) and (recency(row["date"]) is None or recency(row["date"]) <= args.max_age)
    ]

    candidates: dict[str, list[dict]] = {}
    rejected: list[dict] = list(unnameable)
    for row in fresh:
        company = row["company"]
        if held_match(company, held):
            continue
        if not company or len(company) < 4 or TRUNCATED.search(company):
            rejected.append(dict(company=company, title=row["title"], board=row["board"],
                                 url=row["url"], reason="unverifiable name (truncated by card markup)"))
            continue
        if AGENCY.search(company):
            rejected.append(dict(company=company, title=row["title"], board=row["board"],
                                 url=row["url"], reason="agency or consultancy"))
            continue
        folded = norm(strip_place_prefix(company))
        candidates.setdefault(folded, []).append(row)

    ranked = []
    for rows_for in candidates.values():
        rows_for.sort(key=lambda r: recency(r["date"]) if recency(r["date"]) is not None else 999)
        ages = [recency(r["date"]) for r in rows_for if recency(r["date"]) is not None]
        activity = gh_activity(rows_for[0]["company"]) if args.gh else None
        gh_weight = 0
        if activity and activity["days"] is not None:
            gh_weight = 3 if activity["days"] <= 30 else 2 if activity["days"] <= 90 else 1 if activity["days"] <= 365 else 0
        newest = min(ages) if ages else None
        ranked.append(
            dict(
                company=rows_for[0]["company"],
                postings=rows_for,
                fresh=newest,
                gh=activity,
                agency=bool(AGENCY.search(rows_for[0]["company"])),
                score=round(len(rows_for) * 2 + gh_weight * 2, 1),
            )
        )
    ranked.sort(key=lambda o: (-o["score"], -len(o["postings"]), o["company"]))

    payload = dict(
        parsed=len(rows),
        fresh_in_lane=len(fresh),
        held=len(held),
        new=sum(len(v) for v in candidates.values()),
        boards=dict(Counter(r["board"] for v in candidates.values() for r in v)),
        ranked=ranked[: args.limit],
        rejected=rejected[:40],
    )
    text = json.dumps(payload, indent=1, ensure_ascii=False)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        print(
            f"jobsearch-sweep: parsed {payload['parsed']} | fresh {payload['fresh_in_lane']}"
            f" | new {payload['new']} | rejected {len(rejected)} -> {args.out}"
        )
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
