#!/usr/bin/env python3
"""Generate the selector's training pairs from the compiled registries.

The label is the query TEMPLATE (registry + field + which slot fills it), never
the answer: the closed label space is `registry x field`, the value is extracted
from the question at predict time. That is what makes 1,800 pairs enough — a
label that baked the entity in would give every class exactly one example.

Every pair is derived from the compiled data, so the set regenerates whenever
`inventory.toml`, `AGENTS.nix` or a taskfile moves:

    {"q": ..., "label": "inventory|filter:status",
     "slot": {"kind": "value", "field": "status", "value": "active"},
     "query": {...}, "gold": ["aristotle", ...],
     "split": "train|test", "abstain": false}

Splits are by ENTITY, never by template: every pair whose slot is `frieren` is on
one side of the line, or the metric measures memorisation. 20 % of the pairs are
abstain cases — questions whose answer is not in the data — because a model that
cannot decline learns to answer something.

Usage: dataset.py --data DIR [--out FILE] [--vocab FILE] [--verify N]
  DIR holds <registry>.json, <registry>.schema and <registry>.searchable, dumped
  by build.sh through `q.sh --data`, `--schema` and `--searchable` (one eval per
  registry, the same cache the query surface uses and the same `touches`
  semantics the executor applies). --vocab writes the scan vocabulary the
  predictor reads back, so no value in it is invented here.
"""
import argparse
import hashlib
import json
import random
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
REGISTRIES = ("inventory", "notes", "tasks", "graph")

# Phrasings per registry+field. A phrasing without "{v}" is emitted once (there
# is one sensible value); with "{v}" it is emitted per observed value.
# Every {v} field also gets a phrasing that NAMES the field: the classifier has
# to be able to route `which notes are rejected` on structure when the value
# itself was held out of training, and a field word is the only token it can
# trust in that case.
SET_TEMPLATES = {
    "inventory": {
        "status": ["which hosts have status {v}", "which hosts are {v}", "list the {v} hosts"],
        "category": ["which hosts are in the {v} category", "which hosts have category {v}"],
        "kind": ["which {v} hosts are registered", "which hosts have kind {v}"],
        "arch": ["which hosts run {v}", "which hosts have arch {v}"],
        "managed": ["which hosts are managed by this flake"],
        "ci": ["which hosts have ci {v}", "which hosts have ci enabled"],
    },
    "notes": {
        "status": ["which notes have status {v}", "which notes are {v}", "list the {v} notes"],
        "kind": ["which notes have kind {v}", "which {v} notes exist"],
    },
    "tasks": {
        "shard": ["which tasks have shard {v}", "which tasks live in the {v} shard"],
        "retired": ["which tasks are retired"],
        "build": ["which tasks can build", "which tasks run a build"],
    },
    "graph": {
        "type": ["which graph nodes have type {v}", "which {v} nodes are in the graph"],
    },
}

# Numeric questions: the threshold is the slot, the class names the field because a
# bare number is ambiguous (`in 10` and `out 30` are both "at least N"). The
# executor compares `num` fields with `>=`, so the phrasing must be a floor.
NUM_TEMPLATES = {
    "graph": {
        # Every phrasing names the node type: a bare `which nodes link to at
        # least 30 nodes` has no type constraint, and "documents" would then be
        # read as `type=doc` — a constraint the gold set does not have.
        "in": [
            "which {t} nodes are named by at least {n} documents",
            "which {t}s are referenced by at least {n} docs",
            "which nodes of type {t} have at least {n} inbound edges",
        ],
        "out": [
            "which {t} nodes link to at least {n} nodes",
            "which {t}s point at more than {n} nodes",
            "which nodes of type {t} have at least {n} outbound edges",
        ],
    },
    "tasks": {
        "wildcards": [
            "which wildcard tasks live in the {t} shard",
            "which wildcard tasks are there",
        ],
    },
}
NUM_THRESHOLDS = (3, 5, 10, 20, 30)

# Words that appear in every refs value and mean nothing on their own.
STOPWORDS = {
    "with", "that", "this", "from", "into", "than", "then", "them", "they", "their",
    "when", "what", "which", "where", "while", "have", "only", "over", "also", "more",
    "must", "should", "would", "could", "does", "been", "being", "after", "before",
    "notes", "note", "task", "tasks", "host", "hosts", "docs", "docs.", "http", "https",
}

# Mention questions: the class carries the registry, the term comes from the
# question at predict time, and `touches` decides emptiness — so "which notes
# mention kubernetes" refuses because the search finds nothing, not because a
# template was missing.
TOUCH_TEMPLATES = {
    "notes": [
        ("which notes mention {t}", {}),
        ("which notes are about {t}", {}),
        ("which notes reference {t}", {}),
        ("which {k} notes are about {t}", {"kind": "{k}"}),
    ],
    "tasks": [("which tasks mention {t}", {})],
}

# Two constraints in one question. The label is still a single-field template —
# the registry is the routing decision — but the phrasing teaches the router the
# shape it would otherwise see only in the battery.
COMPOUND_TEMPLATES = {
    "inventory": [
        ("status", "category", "which {a} hosts are in the {b} category"),
        ("status", "kind", "which {a} {b} hosts are registered"),
    ],
    "notes": [("kind", "status", "which {a} notes are {b}")],
}

# Entity questions: the slot is the row id, the class carries what to project.
ENTITY_TEMPLATES = {
    "inventory": [
        ("what is {v}'s role", ["role"]),
        ("what architecture is {v}", ["arch"]),
        ("what is {v}'s status", ["status"]),
        ("which category is {v} in", ["category"]),
        ("is the host {v} managed", ["managed"]),
    ],
    "notes": [
        ("what is the status of the note {v}", ["status"]),
        ("what kind of note is {v}", ["kind"]),
    ],
    "tasks": [
        ("which shard does the task {v} live in", ["shard"]),
        ("is the task {v} retired", ["retired"]),
    ],
}

# Questions the data cannot answer. Their label is `abstain`; without them a
# classifier learns to answer something to everything.
ABSTAIN = [
    "what is {host}'s CPU temperature",
    "what is the closure size of {host}",
    "how much RAM does {host} have left",
    "which hosts failed their last backup",
    "which notes mention kubernetes",
    "which tasks failed last night",
    "which hosts have a serial number",
    "what is the banana category",
    "how many users are logged in on {host}",
]


def load_schema(path):
    kinds = {}
    for line in Path(path).read_text().splitlines():
        if ":" in line:
            field, kind = line.split(":", 1)
            kinds[field.strip()] = kind.strip()
    return kinds


def getf(row, field):
    cur = row
    for part in field.split("."):
        if isinstance(cur, dict):
            cur = cur.get(part)
        elif isinstance(cur, list) and part.isdigit():
            idx = int(part)
            cur = cur[idx] if idx < len(cur) else None
        else:
            return None
        if cur is None:
            return None
    return cur


def flatten(value):
    if isinstance(value, dict):
        return " ".join(f"{k} {flatten(v)}" for k, v in value.items())
    if isinstance(value, list):
        return " ".join(flatten(v) for v in value)
    if value is None:
        return ""
    return str(value)


def match(kind, actual, want):
    want_s = str(want).lower()
    if kind == "num":
        try:
            return float(actual) >= float(want_s)
        except (TypeError, ValueError):
            return False
    if kind == "bool":
        a = str(actual).lower()
        if want_s in ("1", "yes"):
            want_s = "true"
        elif want_s in ("0", "no"):
            want_s = "false"
        return a == want_s
    actual_s = flatten(actual).lower()
    if kind == "enum":
        return actual_s == want_s
    return want_s in actual_s


def load_rows(reg, payload):
    if reg in ("inventory", "notes"):
        return [dict(v, id=k) for k, v in payload.items()]
    if reg == "tasks":
        rows = []
        for entry in payload.get("parsed", []):
            row = dict(entry)
            row["id"] = entry.get("name")
            row["build"] = bool(
                any(
                    verb in (entry.get("body") or "")
                    for verb in ("nix build", "nix-build", "nixos-rebuild", "darwin-rebuild", "home-manager switch")
                )
            )
            rows.append(row)
        return rows
    if reg == "graph":
        nodes = payload.get("nodes", [])
        edges = payload.get("edges", [])
        inc = {}
        out = {}
        for e in edges:
            inc[e["to"]] = inc.get(e["to"], 0) + 1
            out[e["from"]] = out.get(e["from"], 0) + 1
        return [dict(n, **{"in": inc.get(n["id"], 0), "out": out.get(n["id"], 0)}) for n in nodes]
    return []


def select(rows, kinds, flt):
    out = []
    for row in rows:
        ok = True
        for field, want in flt.items():
            if not match(kinds.get(field, "text"), getf(row, field), want):
                ok = False
                break
        if ok:
            out.append(row)
    return out


# Free text, long prose and numeric fields are not scan vocabulary: a title
# sentence is never a constraint a question quotes, and a number is a threshold
# the class chooses rather than a value to find.
NO_SCAN = {"id", "body", "summary", "title", "desc", "label"}
SHORT_TEXT = 40


def build_vocab(rows, kinds):
    vocab = {}
    for field, kind in kinds.items():
        if field in NO_SCAN or kind == "num":
            continue
        values = distinct([getf(r, field) for r in rows], cap=60)
        if kind == "text":
            values = [v for v in values if len(v) <= SHORT_TEXT]
        if values:
            vocab[field] = {"kind": kind, "values": values}
    return vocab


def split_of(entity):
    h = hashlib.sha1(entity.encode()).hexdigest()
    return "test" if int(h[:8], 16) % 5 == 0 else "train"


def plurals(value):
    text = flatten(value).strip()
    if not text:
        return []
    return [text, text + "s", text + "es"]


def distinct(values, cap=30):
    seen = []
    for v in values:
        s = flatten(v).strip()
        if s and s.lower() not in ("", "null") and s not in seen:
            seen.append(s)
    return seen[:cap]


def numeric_contexts(reg, field, rows):
    """(subject word, threshold, filter) triples a numeric question can name."""
    out = []
    if reg == "graph":
        for node_type in distinct([getf(r, "type") for r in rows]):
            for threshold in NUM_THRESHOLDS:
                out.append((node_type, threshold, {field: threshold, "type": node_type}))
    else:
        # A wildcard question names a shard by its short name, not by its path:
        # `taskfiles/infra.yml` is "the infra shard".
        for shard in distinct([getf(r, "shard") for r in rows]):
            short = shard.split("/")[-1].rsplit(".", 1)[0]
            out.append((short, 1, {field: 1, "shard": shard}))
        out.append(("", 1, {field: 1}))
    return out


def touches_match(row, term, search):
    """Mirror the executor's `touched`: containment over the named fields only.

    `search` is the registry's own `--searchable` list, so a pair's gold set and
    the executor's answer cannot disagree about what "mentions" means.
    """
    hay = " ".join(flatten(getf(row, f)) for f in search).lower()
    return term.lower() in hay


def touches_gold(rows, term, search):
    return [r["id"] for r in rows if touches_match(r, term, search)]


def term_vocabulary(rows, search, cap=12):
    """Distinctive words the data actually names things by.

    Taken from the searchable fields' own values — a module basename, a task id's
    verb, a title's longest word — never invented. A term that matches everything
    is dropped: `which notes mention the` is not a question.
    """

    counts = {}
    for row in rows:
        seen = set()
        for field in search:
            for word in flatten(getf(row, field)).lower().replace("|", " ").split():
                word = word.strip("()[],'\".")
                # A term has to be something the data names a thing by: "which
                # notes are about with" is a phrasing accident, not a question.
                if len(word) < 4 or word in seen or word in STOPWORDS:
                    continue
                seen.add(word)
                counts[word] = counts.get(word, 0) + 1
    total = len(rows) or 1
    ranked = [w for w, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))]
    # Between 2 and 60 % of the registry: a term that selects nothing makes an
    # empty answer, and one that selects almost everything is a list question.
    picked = [w for w in ranked if 2 <= counts[w] <= max(2, int(total * 0.6))]
    return picked[:cap]


def pairs_for(reg, rows, kinds, search=()):
    pairs = []
    templates = SET_TEMPLATES.get(reg, {})
    for field, phrasings in templates.items():
        # The value vocabulary is the data's, not invented.
        values = distinct([getf(r, field) for r in rows]) if any("{v}" in p for p in phrasings) else ["true"]
        for value in values:
            gold = [r["id"] for r in select(rows, kinds, {field: value})]
            if not gold:
                continue
            for phrasing in phrasings:
                if "{v}" in phrasing:
                    question = phrasing.format(v=value)
                elif value not in ("true",) and len(values) > 1:
                    continue
                else:
                    question = phrasing
                query = {"registry": reg, "filter": {field: value}, "limit": 20}
                pairs.append(
                    {
                        "q": question,
                        "label": f"{reg}|filter:{field}",
                        "slot": {"kind": "value", "field": field, "value": value},
                        "query": query,
                        "gold": gold[:20],
                        "split": split_of(f"{reg}:{field}={value}"),
                        "abstain": False,
                    }
                )
    for phrasing, fields in ENTITY_TEMPLATES.get(reg, []):
        for row in rows:
            rid = row["id"]
            query = {"registry": reg, "filter": {"id": rid}, "fields": fields, "limit": 1}
            pairs.append(
                {
                    "q": phrasing.format(v=rid),
                    "label": f"{reg}|id:{fields[0]}",
                    "slot": {"kind": "id", "field": "id", "value": rid},
                    "query": query,
                    "gold": [rid],
                    "split": split_of(f"{reg}:{rid}"),
                    "abstain": False,
                }
            )

    # Numeric floors: `>=`, one class per field, thresholds taken from the data.
    # A bare number is ambiguous between `in` and `out`, so the class — not the
    # extractor — decides which one the question meant.
    for field, phrasings in NUM_TEMPLATES.get(reg, {}).items():
        for subject, threshold, filt in numeric_contexts(reg, field, rows):
            gold = [r["id"] for r in select(rows, kinds, filt)]
            if not gold:
                continue
            for phrasing in phrasings:
                # A phrasing without a number asks for the field's presence, which
                # the executor reads as `>= 1` — "which wildcard tasks".
                n = threshold if "{n}" in phrasing else 1
                pairs.append(
                    {
                        "q": phrasing.format(n=n, t=subject),
                        "label": f"{reg}|num:{field}",
                        "slot": {"kind": "num", "field": field, "value": n},
                        "query": {"registry": reg, "filter": dict(filt), "limit": 20},
                        "gold": gold[:20],
                        "split": split_of(f"{reg}:{field}>{threshold}:{subject}"),
                        "abstain": False,
                    }
                )

    # Mention questions: the term is free text, so the class only has to know the
    # registry. One phrasing is emitted per term the data names things by, plus
    # the compound shape where a kind narrows the search.
    for phrasing, extra in TOUCH_TEMPLATES.get(reg, []):
        kinds_seen = distinct([getf(r, "kind") for r in rows]) if "{k}" in phrasing else [None]
        for term in term_vocabulary(rows, search):
            for kind_value in kinds_seen:
                flt = {k: kind_value for k, v in extra.items()} if extra else {}
                flt["touches"] = term
                gold = touches_gold(rows, term, search)
                if extra:
                    gold = [
                        r["id"]
                        for r in rows
                        if touches_match(r, term, search) and match(kinds.get("kind", "enum"), r.get("kind"), kind_value)
                    ]
                if not gold:
                    continue
                pairs.append(
                    {
                        "q": phrasing.format(t=term, k=kind_value),
                        "label": f"{reg}|touches",
                        "slot": {"kind": "touches", "value": term},
                        "query": {"registry": reg, "filter": dict(flt), "limit": 20},
                        "gold": gold[:20],
                        "split": split_of(f"{reg}:touches={term}"),
                        "abstain": False,
                    }
                )

    # Compound questions: two enum constraints on one registry. The same shape the
    # battery asks for and the predictor composes — this only teaches the router.
    for first, second, phrasing in COMPOUND_TEMPLATES.get(reg, []):
        first_values = distinct([getf(r, first) for r in rows])
        second_values = distinct([getf(r, second) for r in rows])
        emitted = 0
        for a in first_values:
            for b in second_values:
                gold = [r["id"] for r in select(rows, kinds, {first: a, second: b})]
                if not gold or emitted >= 6:
                    continue
                pairs.append(
                    {
                        "q": phrasing.format(a=a, b=b),
                        "label": f"{reg}|filter:{first}",
                        "slot": {"kind": "value", "field": first, "value": a},
                        "query": {"registry": reg, "filter": {first: a, second: b}, "limit": 20},
                        "gold": gold[:20],
                        "split": split_of(f"{reg}:{first}={a}:{second}={b}"),
                        "abstain": False,
                    }
                )
                emitted += 1
    return pairs


def abstain_pairs(hosts, count, rng):
    out = []
    for i in range(count):
        template = rng.choice(ABSTAIN)
        host = rng.choice(hosts)
        question = template.format(host=host)
        out.append(
            {
                "q": question,
                "label": "abstain",
                "slot": None,
                "query": None,
                "gold": [],
                "split": split_of(f"abstain:{question}"),
                "abstain": True,
            }
        )
    return out


def verify(pairs, sample, seed=7):
    """Cross-check the Python labeler against the executor on a sample."""
    rng = random.Random(seed)
    bad = 0
    for pair in rng.sample([p for p in pairs if not p["abstain"]], min(sample, len([p for p in pairs if not p["abstain"]]))):
        proc = subprocess.run(
            ["bash", str(REPO / "scripts/task/q.sh"), "--json", json.dumps(pair["query"])],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            print(f"  MISMATCH (rc={proc.returncode}) {pair['q']}", file=sys.stderr)
            bad += 1
            continue
        got = sorted(r["id"] for r in json.loads(proc.stdout)["rows"])
        if got != sorted(pair["gold"]):
            bad += 1
            print(f"  MISMATCH {pair['q']}\n    labeler: {pair['gold']}\n    q.sh:    {got}", file=sys.stderr)
    print(f"verify: {sample} sampled, {bad} mismatch(es)")
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True, help="directory with <registry>.json / .schema / .searchable")
    ap.add_argument("--out", default="-")
    ap.add_argument("--vocab", default="", help="write the scan vocabulary here (model.py --vocab)")
    ap.add_argument("--verify", type=int, default=0, help="cross-check N pairs against q.sh")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()

    data_dir = Path(args.data)
    pairs = []
    hosts = []
    vocab = {}
    for reg in REGISTRIES:
        payload_path = data_dir / f"{reg}.json"
        schema_path = data_dir / f"{reg}.schema"
        search_path = data_dir / f"{reg}.searchable"
        if not payload_path.exists() or not schema_path.exists():
            print(f"dataset: missing {payload_path} or {schema_path}", file=sys.stderr)
            return 2
        payload = json.loads(payload_path.read_text())
        kinds = load_schema(schema_path)
        # `touches` semantics come from the executor, not from a second copy here.
        search = [w for w in search_path.read_text().split()] if search_path.exists() else []
        rows = load_rows(reg, payload)
        if reg == "inventory":
            hosts = [r["id"] for r in rows]
        vocab[reg] = build_vocab(rows, kinds)
        pairs.extend(pairs_for(reg, rows, kinds, search))

    rng = random.Random(args.seed)
    abstain_count = max(1, int(round(0.2 * len(pairs) / 0.8)))
    pairs.extend(abstain_pairs(hosts, abstain_count, rng))

    # A class that lost every pair to the test split would simply not exist in the
    # model, and a set question with one phrasing has exactly one pair — so keep at
    # least one training example per label. The protocol (hold entities out) is
    # unchanged; this only stops the split from deleting a class.
    seen_train = {p["label"] for p in pairs if p["split"] == "train"}
    rescued = 0
    for pair in pairs:
        if pair["label"] not in seen_train and not pair["abstain"]:
            pair["split"] = "train"
            seen_train.add(pair["label"])
            rescued += 1

    rng.shuffle(pairs)

    if args.verify:
        if verify(pairs, args.verify, args.seed) != 0:
            return 1

    if args.vocab:
        Path(args.vocab).write_text(json.dumps(vocab, sort_keys=True))

    lines = "\n".join(json.dumps(p, sort_keys=True) for p in pairs) + "\n"
    if args.out == "-":
        sys.stdout.write(lines)
    else:
        Path(args.out).write_text(lines)
        train = sum(1 for p in pairs if p["split"] == "train")
        print(
            f"dataset: {len(pairs)} pairs -> {args.out} "
            f"({train} train / {len(pairs) - train} test, {abstain_count} abstain, "
            f"{rescued} class(es) rescued from an empty train split)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
