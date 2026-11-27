#!/usr/bin/env bash
# cv-evidence-check.sh — a skills line is a claim, and a claim needs a source.
#
# Two kinds of JSON feed a CV. The site's profile corpora
# (`lib/matt/profile{,.de}.json`, `lib/matt/cv-{energy,software}*.json`) carry
# `stack`, which the template prints into every PDF. The two JSON Resume
# corpora (`lib/matt/resume.cv.json`, `lib/matt/lebenslauf.json`) carry `skills`
# groups that feed packets and the public gist, and a `skills` array renders
# nothing by itself: measured 2026-11-27, nothing reads
# `resume.cv.json.skills`, so a technology can sit at "Master" there for months
# with no artifact and no reader. This gate closes that gap from three sides:
#
#   render  every stack item must appear in a built CV's text, so a claim the
#           template drops — or an artifact older than the corpus — fails.
#   align   every DevOps keyword in the JSON Resume corpora must name a
#           rendered stack item, so an unrendered array cannot drift away from
#           the CV a reader actually gets.
#   back    a provider-grade claim — AWS, Azure, Google Cloud, Lambda,
#           Prometheus, Grafana, Kubernetes — must name an artifact that exists
#           in this tree (a path plus a pattern), because these are the terms
#           that were claimed and never built. A provider with no registered
#           artifact always fails. Add the real artifact and then its probe,
#           never the probe alone.
#
# The provider table is data at the top of the Python block: a new technology
# that should not be claimed without proof is a row there, and a claim that
# outgrows its evidence is how the row changes.
#
# Env: ARTIFACT (default /tmp/matt-site — the output of `task matt:build`).
# Builds nothing, writes nothing.
#
# EXIT
#   0  every claim renders, every DevOps keyword is in the stack, every
#      provider claim has an artifact
#   1  a claim is unbacked
#   2  cannot tell: no artifact, no pdftotext, or a corpus that will not parse
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ARTIFACT="${ARTIFACT:-/tmp/matt-site}"

exec python3 - "$root" "$ARTIFACT" <<'PY'
import json
import os
import re
import subprocess
import sys

root, artifact = sys.argv[1:3]

CORPORA = [
    "lib/matt/profile.json",
    "lib/matt/profile.de.json",
    "lib/matt/cv-energy.json",
    "lib/matt/cv-energy.de.json",
    "lib/matt/cv-software.json",
    "lib/matt/cv-software.de.json",
]
# `lib/matt/resume.json` is a projection of the canonical resume and is owned by
# `matt:gist:drift`; its `skills` array still renders nothing, so a claim there
# gets the same treatment rather than an exemption.
RESUMES = [
    "lib/matt/resume.cv.json",
    "lib/matt/resume.json",
    "lib/matt/lebenslauf.json",
]

# A provider claim is a technology nobody here runs on a laptop: it needs an
# operational artifact, not a mention. `probes` is a list of (path, pattern),
# any one of which resolves the claim; an empty list is a deliberate "nothing
# in this tree backs it", so the claim fails until the artifact lands.
PROVIDERS = {
    "AWS": {
        "pattern": r"\baws\b|amazon web services",
        "probes": [],
        "why": "no AWS deployment, Terraform or client code exists; only SOPS "
        "credential placeholders, which are a surface, not a skill",
    },
    "Azure": {
        "pattern": r"\bazure\b",
        "probes": [],
        "why": "no Azure resource, pipeline or code; `azure-foundry` is one "
        "entry in an LLM provider list",
    },
    "Google Cloud": {
        "pattern": r"google cloud|\bgcp\b|\bgke\b",
        "probes": [],
        "why": "no Google Cloud resource or client code exists",
    },
    "Lambda": {
        "pattern": r"\blambda\b",
        "probes": [],
        "why": "no handler, SAM/CDK stack or deployment exists",
    },
    "Prometheus": {
        "pattern": r"\bprometheus\b",
        "probes": [],
        "why": "the fleet exports node_exporter metrics but runs no Prometheus "
        "server or Grafana",
    },
    "Grafana": {
        "pattern": r"\bgrafana\b",
        "probes": [],
        "why": "no Grafana service or dashboard exists",
    },
    "Kubernetes": {
        "pattern": r"\bkubernetes\b|\bk3s\b|\bk8s\b",
        "probes": [
            ("modules/profiles/impermanence.nix", r"rancher/k3s"),
            ("modules/secrets/fullsecrets.yaml", r"\bk3s\b"),
        ],
        "why": "",
    },
}

# Terms whose rendered wording differs from the packet's keyword. A key is the
# compacted keyword; the values are needles any rendered item may contain.
ALIASES = {
    "monitoringalerting": ("gatus", "alertbridge", "sentinel"),
}


def compact(text):
    """A rendered token: parentheses dropped, punctuation and 'and' dropped."""
    text = re.sub(r"\([^)]*\)", " ", text.lower()).replace("&", "and")
    return re.sub(r"[^a-z0-9]+", "", text).replace("and", "")


def flat(text):
    """A PDF token: parentheses kept, because the item keeps them too."""
    text = text.lower().replace("&", "and")
    return re.sub(r"[^a-z0-9]+", "", text).replace("and", "")


def load(rel):
    try:
        with open(os.path.join(root, rel), encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError) as err:
        print(f"cv-evidence-check: cannot read {rel}: {err}", file=sys.stderr)
        sys.exit(2)


def digest(tree, rel):
    path = os.path.join(tree, rel)
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


problems = []

stack = []  # (source, item)
for rel in CORPORA:
    for group in load(rel).get("stack", []):
        for item in group.get("items", []):
            stack.append((rel, item))

claims = [(rel, item, False) for rel, item in stack]  # (source, text, is_devops)
for rel in RESUMES:
    for group in load(rel).get("skills", []):
        is_devops = "devops" in compact(group.get("name", ""))
        for keyword in group.get("keywords", []):
            claims.append((rel, keyword, is_devops))

# render — a claim only reaches a reader if it is in a PDF that was built after
# the corpus was edited.
if not os.path.isdir(artifact):
    print(
        f"cv-evidence-check: no artifact at {artifact} — run task matt:build first",
        file=sys.stderr,
    )
    sys.exit(2)
pdfs = sorted(name for name in os.listdir(artifact) if name.lower().endswith(".pdf"))
if not pdfs:
    print(f"cv-evidence-check: {artifact} holds no PDF", file=sys.stderr)
    sys.exit(2)

pages = {}
for name in pdfs:
    run = subprocess.run(
        ["pdftotext", os.path.join(artifact, name), "-"],
        capture_output=True,
        text=True,
    )
    if run.returncode != 0:
        print(
            f"cv-evidence-check: pdftotext failed on {name}: {run.stderr.strip()}",
            file=sys.stderr,
        )
        sys.exit(2)
    pages[name] = flat(run.stdout)

for rel, item in stack:
    needle = flat(item)
    if not any(needle and needle in text for text in pages.values()):
        problems.append(
            f'{rel}: "{item}" is in the stack but no built CV prints it '
            f"(rebuild with task matt:build, or drop the claim)"
        )

# align — the corpus that renders nothing may not claim more than the one that
# does.
for rel, keyword, is_devops in claims:
    if not is_devops:
        continue
    needle = compact(keyword)
    # One direction only: a short rendered item (`Go`) would otherwise satisfy
    # any keyword that contains it (`Google Cloud`), which is the bug this leg
    # exists to catch.
    matched = [item for _, item in stack if needle and needle in compact(item)]
    if not matched:
        matched = [
            item
            for _, item in stack
            if any(alias in compact(item) for alias in ALIASES.get(needle, ()))
        ]
    if not matched:
        problems.append(
            f'{rel}: DevOps keyword "{keyword}" is not in the rendered stack '
            f"(add it to lib/matt/profile.json and profile.de.json, or drop it)"
        )

# back — a provider claim needs an artifact, not a mention.
for rel, keyword, _ in claims:
    for provider, spec in PROVIDERS.items():
        if not re.search(spec["pattern"], keyword, re.I):
            continue
        if not spec["probes"]:
            problems.append(
                f'{rel}: "{keyword}" claims {provider}, but nothing in this tree '
                f"backs it — {spec['why']}"
            )
            continue
        if not any(
            (digest(root, path) or "") and re.search(pattern, digest(root, path))
            for path, pattern in spec["probes"]
        ):
            probes = ", ".join(f"{path} ~ /{pattern}/" for path, pattern in spec["probes"])
            problems.append(
                f'{rel}: "{keyword}" claims {provider}, but no probe resolves '
                f"({probes})"
            )

if problems:
    for line in problems:
        print(f"FAIL {line}")
    print(f"cv-evidence-check: {len(problems)} unbacked claim(s)")
    sys.exit(1)

devops = sum(1 for _, _, is_devops in claims if is_devops)
print(
    f"cv-evidence-check: {len(stack)} stack item(s) render in {len(pdfs)} built CV(s), "
    f"{devops} DevOps keyword(s) align with the stack, "
    f"{len(PROVIDERS)} provider class(es) backed by an artifact or unclaimed"
)
PY
