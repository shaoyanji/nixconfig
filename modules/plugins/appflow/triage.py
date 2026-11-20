#!/usr/bin/env python3
"""Triage the job pipeline: ingest postings, score them against the corpus, rank.

`select.py` orders the corpus for one description; `triage.py` walks the other
direction — every posting that is waiting, one fit score each — so an operator
reads a ranked queue instead of an inbox. It writes what it decided back to the
archive (`triage-analysis` document, `fit` on the row) and drafts the packet
input (`packet-brief`) for the jobs it says to apply to now.

    triage.py                        # rank the attention queue, dry run
    triage.py --create 3             # upsert rows for the top three matches
    triage.py --source discovered    # only applications the hub discovered
    triage.py --json                 # the analysis, not the table

The wire is the archive API on delphi (see content_api.py); nothing here opens
psql. A re-run is a no-op at the row level: application ids are derived from
company and role, and the analysis document upserts on (application, kind), so
idempotency is the store's job, not this script's.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import sys
import urllib.parse
from datetime import date, datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import content_api  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_API = content_api.DEFAULT_API

# `select.py` shares its name with a stdlib module that urllib needs, so it is
# loaded under a private name: importing it as `select` would poison every
# selector the HTTP stack creates after us.
_spec = importlib.util.spec_from_file_location("appflow_select", os.path.join(HERE, "select.py"))
sel = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sel)

GLOSSARY = sel.load_glossary(os.path.join(HERE, "glossary.json"))

# Tiers. The workflow's `fit` column is 1-5; the pipeline thinks in 0-100.
APPLY_NOW, HOLD = 80, 60
FIT_MAP = ((85, 5), (70, 4), (55, 3), (40, 2), (0, 1))

# Words that say a person, not a technology: they earn +1 where a tool earns +3.
SOFT_SKILLS = frozenset(
    """communication leadership teamwork teamfaehigkeit agile scrum kanban mentoring
    stakeholder presentation documentation analytical collaboration ownership
    proactive eigeninitiative kommunikation problem-solving interpersonal
    self-driven cross-functional facilitation prioritization""".split()
)

# A requirement section is where must-haves live; a term absent from the corpus
# there costs points where the same term in boilerplate costs nothing.
REQUIREMENT_HEAD = re.compile(
    r"(requirements|qualifications|must[- ]haves?|you (have|bring|offer)|"
    r"what (you|we).{0,20}(need|expect|bring)|profil|anforderungen|"
    r"was (sie|du) (mitbringst|bringen)|voraussetzungen)",
    re.IGNORECASE,
)
SECTION_HEAD = re.compile(r"^[a-zA-ZäöüÄÖÜ ]{3,40}:?\s*$")

YEARS_RE = re.compile(r"(\d{1,2})\s*\+?\s*(?:years?|yrs?|jahre)", re.IGNORECASE)
REMOTE_RE = re.compile(r"\b(remote|fully remote|remote-first|home ?office|wfh|telearbeit)\b", re.IGNORECASE)
HYBRID_RE = re.compile(r"\bhybrid\b", re.IGNORECASE)
ONSITE_RE = re.compile(r"\bonsite\b|\bon-site\b|vor ort\b|\boffice[- ]only\b", re.IGNORECASE)
SALARY_RE = re.compile(
    r"([€$£]\s?\d[\d.,]*\s?[kK]?\s*(?:[-–—]|\bto\b)\s*[€$£]?\s?\d[\d.,]*\s?[kK]?|\d{2,3}\s?[kK]\s*(?:[-–—]|\bto\b)\s*\d{2,3}\s?[kK])"
)
DEADLINE_RE = re.compile(
    r"(?:deadline|apply by|application by|bewerbungsfrist|closing date)[:\s,]*"
    r"(\d{1,2}[./-]\d{1,2}[./-]\d{2,4}|\w+ \d{1,2},? \d{4}|\d{4}-\d{2}-\d{2})",
    re.IGNORECASE,
)
URL_RE = re.compile(r"https?://[^\s)<>\"']+")
APPLY_HOST_HINT = re.compile(
    r"apply|career|jobs?|stellen|greenhouse|lever\.co|workday|ashby|personio|"
    r"smartrecruiters|concludis|bamboohr|workable| recruitee|join\.com|softgarden",
    re.IGNORECASE,
)


# --- corpus -----------------------------------------------------------------


def _lines(text):
    return [ln for ln in (text or "").split("\n") if ln.strip()]


def _tags(text):
    return [t.strip() for t in (text or "").split(",") if t.strip()]


def corpus(api, language="en"):
    """JSON-Resume-shaped corpus from the content tables, one language."""
    roles = [r for r in content_api.get(api, "/api/career-roles") or [] if r.get("language") == language]
    projects = [p for p in content_api.get(api, "/api/career-projects") or [] if p.get("language") == language]
    work = [
        {
            "name": r.get("employer"),
            "position": r.get("position"),
            "location": r.get("location"),
            "startDate": r.get("startDate"),
            "endDate": r.get("endDate"),
            "summary": r.get("summary"),
            "description": r.get("description"),
            "highlights": _lines(r.get("highlights")),
            "keywords": _tags(r.get("keywords")),
        }
        for r in roles
    ]
    projects = [
        {
            "name": p.get("name"),
            "entity": p.get("entity"),
            "description": p.get("description"),
            "highlights": _lines(p.get("highlights")),
            "keywords": _tags(p.get("keywords")),
        }
        for p in projects
    ]
    return {"work": work, "projects": projects, "skills": []}


def resume_years(resume):
    """Years since the earliest role started; the corpus carries the dates."""
    starts = [str(j.get("startDate") or "")[:7] for j in resume.get("work") or []]
    starts = [s for s in starts if re.match(r"\d{4}-\d{2}", s)]
    if not starts:
        return 0.0
    year, month = (int(x) for x in min(starts).split("-")[:2])
    now = date.today()
    return round((now.year - year) + (now.month - month) / 12.0, 1)


# --- ingest -----------------------------------------------------------------


def queue(api, source, lim):
    """Postings waiting for a decision, newest first, as candidate records."""
    out = []
    if source in ("all", "discovered"):
        for row in content_api.get(api, f"/api/applications-discovered?lim={lim}") or []:
            out.append({"id": row.get("id"), "company": row.get("company"), "role": row.get("role"),
                        "source": "discovered", "status": row.get("status"), "stage": row.get("stage")})
    if source in ("all", "attention"):
        for row in content_api.get(api, f"/api/application-attention?lim={lim}") or []:
            out.append({"id": row.get("id"), "company": row.get("company"), "role": row.get("role"),
                        "source": "attention", "status": row.get("status"), "stage": row.get("stage")})
    if source in ("all", "queue"):
        for row in content_api.get(api, f"/api/agent-queue?owner=agent:apps&lim={lim}") or []:
            out.append({"message_id": row.get("messageId"), "source": "queue",
                        "subject": row.get("subject"), "sender": row.get("sender")})
    seen, dedup = set(), []
    for item in out:
        key = item.get("id") or item.get("message_id")
        if key and key not in seen:
            seen.add(key)
            dedup.append(item)
    return dedup


def message_body(api, message_id):
    if not message_id:
        return ""
    rows = content_api.get(api, "/api/message-body?messageId=" + urllib.parse.quote(message_id, safe="")) or []
    return (rows[0] or {}).get("bodyPlain") or "" if rows else ""


def jd_for(api, cand):
    """The description text behind one candidate, in trust order."""
    app = {}
    if cand.get("id"):
        app = (content_api.get(api, "/api/application-get?id=" + urllib.parse.quote(cand["id"], safe="")) or [{}])[0]
        docs = content_api.get(api, "/api/application-document?applicationId="
                               + urllib.parse.quote(cand["id"], safe="")) or []
        for doc in docs:
            if doc.get("kind") == "jd" and doc.get("body"):
                return app, doc["body"], "document:jd"
        for link in content_api.get(api, "/api/application-mail?applicationId="
                                    + urllib.parse.quote(cand["id"], safe="") + "&lim=3") or []:
            body = message_body(api, link.get("messageId"))
            if len(body) > 200:
                return app, body, "mail:" + (link.get("messageId") or "")[:40]
        body = message_body(api, app.get("messageId"))
        if len(body) > 200:
            return app, body, "mail:" + (app.get("messageId") or "")[:40]
        return app, "\n".join(x for x in [app.get("role"), app.get("notes"), app.get("status")] if x), "row"
    body = message_body(api, cand.get("message_id"))
    if body:
        return app, body, "mail:" + (cand.get("message_id") or "")[:40]
    return app, cand.get("subject") or "", "subject"


# --- analyze ----------------------------------------------------------------


def requirement_terms(text):
    """Tokens from the requirements section, and whether such a section existed.

    No section, no penalty basis: a reply mail has no requirements block, so
    treating its absent vocabulary as must-haves would charge -2 for "thank".
    """
    lines = (text or "").split("\n")
    section, collecting, found = [], False, False
    for line in lines:
        if REQUIREMENT_HEAD.search(line):
            collecting, found = True, True
            continue
        if collecting and SECTION_HEAD.match(line) and len(line.strip()) < 60:
            collecting = False
        if collecting:
            section.append(line)
    return sel.expand(sel.tokens("\n".join(section)), GLOSSARY), found


def analyze(text):
    """The structured half of a description: what it asks, where it is."""
    return {
        "chars": len(text or ""),
        "yearsRequired": max((int(m) for m in YEARS_RE.findall(text or "")), default=0),
        "remote": bool(REMOTE_RE.search(text or "")),
        "workMode": ("remote" if REMOTE_RE.search(text or "")
                     else "hybrid" if HYBRID_RE.search(text or "")
                     else "onsite" if ONSITE_RE.search(text or "") else "unknown"),
        "salary": (SALARY_RE.search(text or "") or [None])[0],
        "deadline": (DEADLINE_RE.search(text or "") or [None, None])[1],
        "urls": URL_RE.findall(text or ""),
    }


def apply_url(text_urls, app):
    for url in [app.get("applyUrl") or ""]:
        if url:
            return url
    for url in text_urls:
        if APPLY_HOST_HINT.search(url):
            return url.rstrip(".,);")
    return ""


# --- match ------------------------------------------------------------------


def term_match(a, b):
    """select.matches, minus the five-letter trap.

    A first-five-chars fallback calls `interferometry` and `interview` the same
    word because `inter` is a common stem, not an inflection. Six letters still
    joins `encrypted` to `encryption` and `operator` to `operations`, which is
    the case the fallback exists for.
    """
    if a == b:
        return True
    short, long = (a, b) if len(a) <= len(b) else (b, a)
    if len(short) >= 3 and long in (short + "s", short + "es"):
        return True
    if len(short) >= 4 and long.startswith(short):
        return True
    return len(short) >= 6 and long[:6] == short[:6]


# The corpus spans trading, energy, web and field work; no one description can
# ask for all of it. A posting that names ~15 of the operator's own keywords is
# a strong match, so 60 points is the bar the score normalizes against — past it
# the scale saturates, and that is what 100 means.
FIT_TARGET = 60
RELATED_CAP, SOFT_CAP = 10, 5


def match(resume, jd_text, ranker, vocab):
    """Score one description against the corpus, 0-100, per the spec's weights.

    The direction is keyword coverage: each of the resume's own keyword terms is
    checked against the description, +3 when the description carries it. A term
    the description carries and the corpus knows outside the keyword lists is
    related, +2, capped so prose cannot inflate it. A soft skill is +1. +2 when
    experience meets the stated years, +2 when the work mode is not strictly
    onsite. -2 per must-have the corpus does not carry — but only when the text
    has a requirements section to take must-haves from, capped at five.
    """
    jd_terms = sel.expand(sel.tokens(jd_text), GLOSSARY)
    corpus_terms = set(ranker.df)
    exact = [word for word in sorted(vocab) if any(term_match(word, term) for term in jd_terms)]
    exact_set = set(exact)
    related, soft = [], []
    for term in dict.fromkeys(jd_terms):
        if term in SOFT_SKILLS:
            if len(soft) < SOFT_CAP:
                soft.append(term)
        # A related term only counts when the corpus finds it rare: "manager" and
        # "application" are in every mail body and every highlight, so letting
        # them match ranks a barista ad beside an engineering one.
        elif ranker.idf(term) >= 1.0 and any(term_match(term, word) for word in corpus_terms) and not any(
            term_match(term, word) for word in exact_set
        ):
            if len(related) < RELATED_CAP:
                related.append(term)

    req_terms, req_found = requirement_terms(jd_text)
    must_have_missing = [] if not req_found else [
        t for t in dict.fromkeys(req_terms)
        if len(t) > 3 and t not in SOFT_SKILLS
        and not any(sel.matches(t, word) for word in corpus_terms)
    ][:5]

    facts = analyze(jd_text)
    years_bonus = 2 if not facts["yearsRequired"] or resume_years(resume) >= facts["yearsRequired"] else 0
    remote_bonus = 0 if facts["workMode"] == "onsite" else 2
    points = 3 * len(exact) + 2 * len(related) + len(soft) + years_bonus + remote_bonus
    penalty = 2 * len(must_have_missing)
    fit = max(0, min(100, round((points - penalty) * 100 / FIT_TARGET)))

    tier = "apply-now" if fit >= APPLY_NOW else "hold" if fit >= HOLD else "skip"
    return {
        "fit": fit,
        "tier": tier,
        "jdTerms": len(set(jd_terms)),
        "matched": {"exact": exact, "related": related, "soft": soft},
        "mustHaveMissing": must_have_missing,
        "points": points, "penalty": penalty,
        "analysis": facts,
    }


# --- action -----------------------------------------------------------------


def fit_small(fit):
    for floor, value in FIT_MAP:
        if fit >= floor:
            return value
    return 1


def upsert_application(api, app, cand, scored, dry):
    """Create or refresh the row; an existing row keeps every field but `fit`."""
    app_id = cand.get("id") or "-".join(
        x for x in [content_api.slug(cand.get("company")), content_api.slug(cand.get("role"))] if x != "unknown"
    ) or "triage-" + hashlib.sha256((cand.get("subject") or cand["id"]).encode()).hexdigest()[:12]
    base = app if app.get("id") else {}
    new = not base
    status = base.get("status") or f"Triaged {scored['tier']} (fit {scored['fit']})"
    if new:
        stage = "prep" if scored["tier"] == "apply-now" else "other"
    else:
        stage = base.get("stage") or "other"
    body = {
        "id": app_id,
        "company": base.get("company") or cand.get("company") or "unknown",
        "role": base.get("role") or cand.get("role") or "",
        "category": base.get("category") or "",
        "language": base.get("language") or "en",
        "fit": fit_small(scored["fit"]),
        "status": status,
        "stage": stage,
        "nextAction": base.get("nextAction") or (
            "Apply: " + scored.get("applyUrl") if scored["tier"] == "apply-now" and scored.get("applyUrl") else "Triage decided: " + scored["tier"]),
        "applyUrl": base.get("applyUrl") or scored.get("applyUrl") or "",
        "coverLetterUrl": base.get("coverLetterUrl") or "",
        "resumeUrl": base.get("resumeUrl") or "",
        "gmail": base.get("gmail") or "",
        "reviewFlag": base.get("reviewFlag") or "triaged",
        "notes": base.get("notes") or "",
        "folderPath": base.get("folderPath") or "",
        "messageId": base.get("messageId") or cand.get("message_id") or "",
        "recruiterEmail": base.get("recruiterEmail") or "",
        "createdAt": base.get("createdAt") or "",
        "updatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "origin": base.get("origin") or "discovered",
    }
    if dry:
        return {"id": app_id, "dry": True}
    return content_api.post(api, "/api/application-upsert", body) or [{"id": app_id}]


def write_document(api, app_id, kind, body, source, sha, dry):
    if dry or not app_id:
        return None
    return content_api.post(api, "/api/application-document-upsert", {
        "applicationId": app_id, "kind": kind, "body": body, "source": source, "sha256": sha,
    })


# --- main -------------------------------------------------------------------


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--api", default=DEFAULT_API, help="archive API base (default: %(default)s)")
    parser.add_argument("--source", default="all", choices=["all", "discovered", "attention", "queue"],
                        help="which queue feeds the triage (default: all)")
    parser.add_argument("--lim", type=int, default=25, help="queue read limit per source")
    parser.add_argument("--create", type=int, default=0, metavar="N",
                        help="upsert application rows for the top N matches (0 = dry)")
    parser.add_argument("--language", default="en", help="corpus language (default: en)")
    parser.add_argument("--json", action="store_true", help="print the full analysis as JSON")
    args = parser.parse_args(argv)
    api = args.api.rstrip("/")

    resume = corpus(api, args.language)
    ranker = sel.Ranker(sel.collect_corpus(resume), sel.vocabulary_of(resume))
    vocab = set()
    for word in sel.vocabulary_of(resume):
        vocab.update(sel.tokens(word))

    candidates = queue(api, args.source, args.lim)
    results = []
    for cand in candidates:
        app, jd_text, jd_source = jd_for(api, cand)
        scored = match(resume, jd_text, ranker, vocab)
        scored["applyUrl"] = apply_url(scored["analysis"]["urls"], app)
        row = {
            "id": cand.get("id"),
            "company": (app.get("company") or cand.get("company")),
            "role": (app.get("role") or cand.get("role") or cand.get("subject")),
            "source": cand.get("source"),
            "jdSource": jd_source,
            **scored,
        }
        results.append((row, cand, app, jd_text))

    results.sort(key=lambda r: (-r[0]["fit"], r[0]["id"] or ""))

    created = []
    for rank, (row, cand, app, jd_text) in enumerate(results, 1):
        if rank <= args.create:
            up = upsert_application(api, app, cand, row, dry=False)
            app_id = (up[0] or {}).get("id") or row.get("id")
            row["id"] = app_id
            created.append(app_id)
        else:
            app_id = row.get("id")
        if app_id:
            analysis_body = json.dumps(
                {k: row[k] for k in ("fit", "tier", "jdTerms", "matched",
                                     "mustHaveMissing", "points", "penalty", "analysis",
                                     "applyUrl", "jdSource", "source")},
                ensure_ascii=False, indent=2, sort_keys=True)
            write_document(api, app_id, "triage-analysis", analysis_body,
                           "triage.py", hashlib.sha256(analysis_body.encode()).hexdigest(),
                           dry=False)
            if row["tier"] == "apply-now" and rank <= args.create and jd_text:
                projection, _audit = sel.select(
                    resume, jd_text,
                    {"maxHighlights": 4, "minHighlights": 1, "maxProjects": 4,
                     "minProjects": 1, "maxKeywords": 6},
                    GLOSSARY)
                brief = json.dumps(projection, ensure_ascii=False, indent=2, sort_keys=True)
                write_document(api, app_id, "packet-brief", brief,
                               "triage.py", hashlib.sha256(brief.encode()).hexdigest(), dry=False)

    if args.json:
        print(json.dumps([r[0] for r in results], ensure_ascii=False, indent=2))
    else:
        print(f"{'#':>2}  {'fit':>3}  {'tier':<9}  {'source':<10}  company / role")
        for rank, (row, _c, _a, _jd) in enumerate(results, 1):
            name = f"{row.get('company') or '?'} — {row.get('role') or '?'}"
            print(f"{rank:>2}  {row['fit']:>3}  {row['tier']:<9}  {row['source']:<10}  {name[:72]}")
        counts = {}
        for row, *_ in results:
            counts[row["tier"]] = counts.get(row["tier"], 0) + 1
        print(f"\n{len(results)} candidates: " +
              ", ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "none")
        if created:
            print("rows upserted: " + ", ".join(created))
        if args.create == 0:
            print("dry run: pass --create N to upsert the top N")
    return 0


if __name__ == "__main__":
    sys.exit(main())
