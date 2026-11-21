#!/usr/bin/env python3
"""Parse a job description with jq, phrase it in Python, project the resume onto it.

`select.py` turns the resume corpus into the one-page projection an application
needs. The corpus may hold far more than a page: every role keeps all its
highlights, every project stays in the file, and this narrows them for one job
description. Nothing is invented, and nothing is dropped that a CV must carry —
roles, education and languages are structure, not material.

    select.py --resume corpus.json --jd jd.txt --out resume.json --audit audit.json

No JD, no filtering: the corpus is copied through and the audit says so, which is
what keeps `agents:apps:packet` behaving exactly as it did before this existed.

The score is word overlap weighted by how rare a term is across the corpus. That
is a relevance rank, not evidence: it orders material for a reader, and it can
be wrong. The audit records every score so a wrong order is visible instead of
silent.
"""

import argparse
import json
import math
import os
import re
import sys
from collections import Counter

# Two-letter words carry no signal in a job ad ("in", "zu", "of", "at") and
# "and"/"und" appear in every sentence.
#
# The second block is verbs and filler that both a CV and a job ad own: "built",
# "managed", "experience". They rank nothing — every bullet in the corpus says
# some of them, so a match on one of them is noise that drowns the terms which
# actually distinguish a role. Word frequency cannot find them, because in one
# person's corpus "build" is rare; a list can.
STOPWORDS = frozenset(
    """
    a an and are as at be been both but by can could did do does for from had has
    have how if in into is it its may not of on once only or other our out over
    own same should so some such than that the their them then there these they
    this those to too under until up very was we were what when where which while
    who why will with would you your
    aber als auch auf aus bei bin bis da das dem den der des die dies eine einen
    einer eines er es für hat hier ich im in ist ja kann mit nach nicht noch nur
    oder sehr sich sie sind so über um und uns von vor war was wie wir wird wo zu
    zum zur
    build built builds building run runs running work works working manage managed
    managing management develop developed developing development support supported
    create created creating lead led leading own owned owning drive driving
    coordinate coordinating ensure ensuring deliver delivered delivery implement
    implemented implementing implementation maintain maintained maintainance design
    designed designing provide provided help helped use used using document documents
    documentation project projects team teams client clients company companies
    experience role roles position positions responsibility responsibilities task
    tasks environment environments requirement requirements skill skills knowledge
    ability plus strong good excellent great ideal candidate candidates apply
    aufgaben aufgabenbereich kenntnisse erfahrung team teams bereich stellen mitarbeit
    unterstützung verantwortung umsetzung entwicklung betreuung sicherstellung
    mitwirkung anforderungen profil aufgabengebiet
    """.split()
)

# A term from the resume's own vocabulary — a skill keyword, a project keyword,
# a role keyword — is a term the operator already uses for their work. It outranks
# a word that merely happens to be rare in this one file.
# A role the description says nothing about keeps its lead lines — two, not four.
# Enough to show what the job was, not enough to push out a role that matched.
FALLBACK_HIGHLIGHTS = 2

# A term from the resume's own vocabulary — a skill keyword, a project keyword,
# a role keyword — is a term the operator already uses for their work. It outranks
# a word that merely happens to be rare in this one file.
VOCAB_BOOST = 2.5

TOKEN = re.compile(r"[0-9a-z\u00e4\u00f6\u00fc\u00df][0-9a-z\u00e4\u00f6\u00fc\u00df+#._/-]*")


def tokens(text):
    """Lowercase word tokens, no stopwords, no bare numbers.

    A compound keeps both forms: `SOPS-encrypted` yields itself and `encrypted`,
    which is the word a German description asks for when it says `Verschlüsselung`.
    Keeping only the compound scores that as a term the corpus never carries.
    """
    if not text:
        return []
    out = []
    for token in (t.strip("._-/") for t in TOKEN.findall(text.lower())):
        for part in (token, *(token.replace("/", "-").split("-") if ("-" in token or "/" in token) else ())):
            if len(part) > 1 and part not in STOPWORDS and not part.isdigit():
                out.append(part)
    return out


def matches(a, b):
    """One token matches another when they are the same word to a reader.

    Prefix rather than stemming: `engineer`/`engineering` and `develop`/`developer`
    are the same word, while `s`-stripping turns `kubernetes` into a term that
    matches nothing.

    Two cases a prefix rule misses and a glossary cannot paper over: an inflection
    that changes the ending (`encryption`/`encrypted`, `operator`/`operations`) and
    a bare plural (`key`/`keys`). Both used to score zero, so a glossary entry that
    looked right silently selected nothing.
    """
    if a == b:
        return True
    short, long = (a, b) if len(a) <= len(b) else (b, a)
    if len(short) >= 3 and long in (short + "s", short + "es"):
        return True
    if len(short) >= 4 and long.startswith(short):
        return True
    return len(short) >= 5 and long[:5] == short[:5]


def load_glossary(path=None):
    """German job-ad words mapped onto the English ones the corpus uses.

    The corpus is one language; the job market is not. Without this, a German
    description scores zero against an English CV and every role falls back to
    its lead lines — the filter would silently stop filtering.
    """
    path = path or os.path.join(os.path.dirname(os.path.abspath(__file__)), "glossary.json")
    try:
        with open(path, encoding="utf-8") as handle:
            table = json.load(handle)
    except (OSError, ValueError):
        return {}
    return {key.lower(): value for key, value in table.items() if not key.startswith("$")}


def expand(jd_tokens, glossary):
    """Add the English counterpart of every German term the description uses."""
    if not glossary:
        return jd_tokens
    out = list(jd_tokens)
    for token in jd_tokens:
        for german, english in glossary.items():
            if token == german or (len(token) >= 4 and german.startswith(token)) or (
                len(german) >= 4 and token.startswith(german)
            ):
                out.extend(tokens(english))
    return out


def text_of(entry, fields):
    return " ".join(str(entry.get(f) or "") for f in fields)


def collect_corpus(resume):
    """Every string the ranking may look at, in a stable order, as documents."""
    docs = []
    for job in resume.get("work") or []:
        for item in job.get("highlights") or []:
            docs.append(tokens(item))
        docs.append(tokens(text_of(job, ("position", "summary", "description"))) + tokens(
            " ".join(job.get("keywords") or [])))
    for project in resume.get("projects") or []:
        docs.append(tokens(text_of(project, ("name", "description", "entity"))) + tokens(
            " ".join(project.get("keywords") or [])))
        for item in project.get("highlights") or []:
            docs.append(tokens(item))
    for group in resume.get("skills") or []:
        docs.append(tokens(group.get("name")) + tokens(" ".join(group.get("keywords") or [])))
    return docs


class Ranker:
    def __init__(self, corpus, vocabulary=()):
        df = Counter()
        for doc in corpus:
            for token in set(doc):
                df[token] += 1
        self.docs = max(1, len(corpus))
        self.df = df
        self.vocabulary = frozenset(tokens(" ".join(vocabulary)))

    def in_vocabulary(self, term):
        return any(matches(term, word) for word in self.vocabulary)

    def idf(self, token):
        """Weight a JD term by how rare it is in the corpus.

        A term the corpus never carries weighs nothing: it cannot select anything,
        and scoring it would let an absent buzzword win a ranking by accident. A
        term every entry carries weighs least, because it separates nobody.
        """
        best = self.df.get(token, 0)
        if best == 0:
            for known, count in self.df.items():
                if matches(token, known):
                    best = max(best, count)
        if best == 0:
            return 0.0
        return math.log(1.0 + self.docs / (1.0 + best))

    def weights(self, jd_tokens):
        tf = Counter(jd_tokens)
        weighted = (
            (t, (1.0 + math.log(c)) * self.idf(t) * (VOCAB_BOOST if self.in_vocabulary(t) else 1.0))
            for t, c in tf.items()
        )
        return {t: w for t, w in weighted if w > 0.0}

    def score(self, text, weights):
        """Sum the weight of every JD term this text contains, per word of text.

        Dividing by the length stops one long paragraph from outranking a precise
        line: a bullet that says one relevant thing should beat a résumé summary
        that mentions seven.
        """
        mine = tokens(text)
        if not mine:
            return 0.0
        total = 0.0
        for term, weight in weights.items():
            if any(matches(term, token) for token in mine):
                total += weight
        return round(total / math.sqrt(len(mine)), 4)


def rank(items, score_of):
    """Best first, ties by position so the output is a function of the input."""
    scored = [(score_of(item), index, item) for index, item in enumerate(items)]
    scored.sort(key=lambda row: (-row[0], row[1]))
    return scored


def vocabulary_of(resume):
    """The operator's own technology and domain words."""
    words = []
    for job in resume.get("work") or []:
        words.extend(job.get("keywords") or [])
    for project in resume.get("projects") or []:
        words.extend(project.get("keywords") or [])
    for group in resume.get("skills") or []:
        words.extend(group.get("keywords") or [])
    return words


def select(resume, jd_text, budget, glossary=None):
    """Return (projected resume, audit). Pure: same inputs, same bytes."""
    resume = json.loads(json.dumps(resume))
    audit = {
        "mode": "passthrough",
        "budget": budget,
        "jd": {"chars": 0, "terms": []},
        "work": [],
        "projects": {"kept": [], "dropped": []},
        "skills": [],
    }
    jd_tokens = expand(tokens(jd_text), glossary)
    if not jd_tokens:
        audit["reason"] = "no job description: the corpus is the CV"
        return resume, audit

    audit["mode"] = "jd"
    ranker = Ranker(collect_corpus(resume), vocabulary_of(resume))
    weights = ranker.weights(jd_tokens)
    audit["jd"] = {
        "chars": len(jd_text),
        "terms": [
            {"term": term, "weight": round(weight, 3)}
            for term, weight in sorted(weights.items(), key=lambda kv: (-kv[1], kv[0]))[:12]
        ],
    }

    # --- work: every role stays, highlights are chosen ----------------------
    for job in resume.get("work") or []:
        highlights = job.get("highlights") or []
        if not highlights:
            continue
        ranked = rank(highlights, lambda h: ranker.score(h, weights))
        best = ranked[0][0] if ranked else 0.0
        # A role with no line about this job keeps its lead lines. That is a
        # visible fallback, not a guess: the audit records `matched: false` and
        # the reader can see the role carried nothing the description asked for.
        if best <= 0.0:
            chosen = list(range(min(FALLBACK_HIGHLIGHTS, budget["maxHighlights"], len(highlights))))
            matched = False
        else:
            floor = best * 0.5
            strong = [index for score, index, _ in ranked if score > 0.0 and score >= floor]
            chosen = sorted(strong[: budget["maxHighlights"]])
            while len(chosen) < budget["minHighlights"]:
                for _, index, _ in ranked:
                    if index not in chosen:
                        chosen.append(index)
                        break
            chosen = sorted(chosen)
            matched = True
        job["highlights"] = [highlights[i] for i in chosen]
        audit["work"].append(
            {
                "name": job.get("name"),
                "matched": matched,
                "kept": len(chosen),
                "of": len(highlights),
                "dropped": [
                    {"score": score, "text": highlights[index][:120]}
                    for score, index, _ in ranked
                    if index not in chosen
                ],
            }
        )

    # --- projects: the tail is the archive, not the CV ---------------------
    projects = resume.get("projects") or []
    if projects:
        ranked = rank(
            projects,
            lambda p: ranker.score(
                text_of(p, ("name", "description")) + " " + " ".join(p.get("keywords") or []), weights
            ),
        )
        chosen = [index for score, index, _ in ranked if score > 0][: budget["maxProjects"]]
        if len(chosen) < budget["minProjects"]:
            for _, index, _ in ranked:
                if index not in chosen:
                    chosen.append(index)
                if len(chosen) >= budget["minProjects"]:
                    break
        resume["projects"] = [projects[i] for i in sorted(chosen)]
        audit["projects"] = {
            "kept": [p.get("name") for p in resume["projects"]],
            "dropped": [
                {"score": score, "name": projects[index].get("name")}
                for score, index, _ in ranked
                if index not in chosen
            ],
        }

    # --- skills: a group survives, its keywords are trimmed ---------------
    for group in resume.get("skills") or []:
        keywords = group.get("keywords") or []
        if not keywords:
            continue
        ranked = rank(keywords, lambda k: ranker.score(k, weights))
        chosen = sorted(index for _, index, _ in ranked[: budget["maxKeywords"]])
        group["keywords"] = [keywords[i] for i in chosen]
        audit["skills"].append(
            {
                "name": group.get("name"),
                "kept": len(chosen),
                "of": len(keywords),
                "dropped": [
                    {"score": score, "text": keywords[index]}
                    for score, index, _ in ranked
                    if index not in chosen
                ],
            }
        )

    # The projection says what it is, so a reader of the JSON is never misled
    # into thinking the corpus is one page.
    resume.setdefault("meta", {})
    if isinstance(resume["meta"], dict):
        resume["meta"]["appflow"] = {
            "selected": True,
            "budget": budget,
            "kept": {
                "highlights": sum(job["kept"] for job in audit["work"]),
                "highlights_of": sum(job["of"] for job in audit["work"]),
                "projects": len(resume.get("projects") or []),
                "projects_of": len(projects),
            },
        }
    return resume, audit


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--resume", required=True, help="the corpus (JSON Resume)")
    parser.add_argument("--jd", help="job description text file")
    parser.add_argument("--application", help="application record; its jobDescription is used when --jd is absent")
    parser.add_argument("--out", required=True, help="where the projection is written")
    parser.add_argument("--audit", help="where the selection report is written (JSON)")
    parser.add_argument("--max-highlights", type=int, default=4)
    parser.add_argument("--min-highlights", type=int, default=1)
    parser.add_argument("--max-projects", type=int, default=4)
    parser.add_argument("--min-projects", type=int, default=1)
    parser.add_argument("--max-keywords", type=int, default=6)
    parser.add_argument("--glossary", help="German-to-English term map (default: glossary.json beside this file)")
    args = parser.parse_args(argv)

    budget = {
        "maxHighlights": args.max_highlights,
        "minHighlights": args.min_highlights,
        "maxProjects": args.max_projects,
        "minProjects": args.min_projects,
        "maxKeywords": args.max_keywords,
    }
    if budget["minHighlights"] > budget["maxHighlights"]:
        parser.error("--min-highlights cannot exceed --max-highlights")
    if budget["minProjects"] > budget["maxProjects"]:
        parser.error("--min-projects cannot exceed --max-projects")

    try:
        with open(args.resume, encoding="utf-8") as handle:
            resume = json.load(handle)
    except (OSError, ValueError) as error:
        print(f"select: cannot read {args.resume}: {error}", file=sys.stderr)
        return 2

    jd_text = ""
    if args.jd:
        try:
            with open(args.jd, encoding="utf-8") as handle:
                jd_text = handle.read()
        except OSError as error:
            print(f"select: cannot read {args.jd}: {error}", file=sys.stderr)
            return 2
    elif args.application:
        try:
            with open(args.application, encoding="utf-8") as handle:
                jd_text = json.load(handle).get("jobDescription") or ""
        except (OSError, ValueError) as error:
            print(f"select: cannot read {args.application}: {error}", file=sys.stderr)
            return 2

    projection, audit = select(resume, jd_text, budget, load_glossary(args.glossary))

    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(projection, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    if args.audit:
        with open(args.audit, "w", encoding="utf-8") as handle:
            json.dump(audit, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")

    if audit["mode"] == "passthrough":
        print("select: no job description, the corpus is the CV")
    else:
        meta = projection.get("meta", {}).get("appflow", {}) or {}
        counts = meta.get("kept", {}) if isinstance(meta, dict) else {}
        print(
            "select: {} highlights of {}, {} projects of {}"
            .format(
                counts.get("highlights", "?"),
                counts.get("highlights_of", "?"),
                counts.get("projects", "?"),
                counts.get("projects_of", "?"),
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
