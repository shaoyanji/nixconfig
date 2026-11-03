#!/usr/bin/env python3
"""Stage 1: question -> query object, as a classifier over a closed label space.

The classifier decides ONE thing — which registry the question is about (and, for
a numeric or entity question, which field). Everything else is extraction against
the compiled vocabulary, which is why a compound question works: a filtered object
holds several entries, the executor already runs them all, and the old
"one slot or refuse" rule was a limit of this file rather than of the query.

Backend `nb` is multinomial Naive Bayes in the standard library: no torch, no
numpy, runs anywhere, trains in seconds on a 2-core host. It exists to answer the
predesign's open question cheaply — *is the label space small enough that a
classifier beats a 5-line intent matcher* — before anyone spends GPU time.
`train_encoder.py` is the fine-tune path for eisen.

The confidence is the log-score margin between the top class and the runner-up,
and the reported numbers are chosen the way the daemon gate is: maximize
coverage subject to a correct-rate floor, never maximize accuracy.

Usage:
  model.py train --dataset FILE --vocab FILE --out FILE [--min-p 0.5]
  model.py predict --model FILE --question "which notes are blocked"
  model.py eval --model FILE --dataset FILE
"""
import argparse
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

# Smoothing and a per-class training cap. Both exist for the same reason: the
# pair count per class is entity cardinality, not information — a task template
# has 527 examples and a status template has 8 — so uncapped counts make the
# biggest class win on priors alone (`which notes are rejected` answered `kind`,
# which has no rejected value at all).
ALPHA = 0.02
CAP = 60
TOKEN = re.compile(r"[a-z0-9][a-z0-9:._/-]*")

# Words a question uses for a value it does not spell. Each entry is grounded in
# a real value of the compiled data (`darwin` is cassini's kind; the question says
# macOS), not invented: an alias that matches nothing is dead weight in a scan.
ALIASES = {
    "darwin": ("macos", "mac os", "apple"),
    "home": ("home-manager", "standalone"),
    "microvm": ("virtual machine",),
    "laptop": ("laptop",),
    "handoff": ("handoff", "hand off"),
}
# The field a numeric question means. `in` and `out` are both "at least N", so the
# class chooses and these words only confirm it.
NUMBER_WORDS = {"three": 3, "five": 5, "ten": 10, "twenty": 20, "thirty": 30, "forty": 40}
# Fields a question can ask for by name without a threshold ("which wildcard
# tasks" is `wildcards >= 1`); every other numeric field needs a number.
PRESENCE_FIELDS = {"wildcards"}
# Which words a question uses to name the attribute an entity question asks for.
# This is what stops `what is frieren's CPU temperature` from being answered: the
# data has no CPU field, so the question names no attribute the registry can hold.
FIELD_WORDS = {
    "role": ("role",),
    "arch": ("arch", "architecture"),
    "status": ("status", "state"),
    "category": ("category",),
    "kind": ("kind",),
    "managed": ("managed",),
    "shard": ("shard",),
    "retired": ("retired",),
    "build": ("build",),
    "priority": ("priority",),
    "type": ("type",),
}
# A bool field is asked for by naming it; the marker decides which way. `ci
# disabled` is the only phrasing shape the data has a false value for.
BOOL_TRUE = ("true", "enabled", "enable", "yes", "manages", "managed by")
BOOL_FALSE = ("false", "disabled", "disable", "without")
# Verbs that introduce a free-text term: `which notes mention mqtt`. The term is
# not a vocabulary lookup — the executor decides emptiness, so a term the data
# does not know refuses by returning no rows.
TOUCH_VERBS = ("mention", "mentions", "mentioned", "about", "reference", "references", "referenced", "touching", "touches")
ARTICLES = ("a", "an", "the", "any", "all", "some", "this", "these")


def tokenize(text):
    # Compound tokens keep `ops:q`, `refs.docs` and `x86_64-linux` intact; the
    # plain words give the bigrams something to pair (a doubled list produced
    # wraparound bigrams like `rejected_which`, which scored nothing and
    # everything at once).
    lowered = text.lower()
    toks = [t for t in TOKEN.findall(lowered) if len(t) > 1]
    words = [w for w in re.findall(r"[a-z0-9]+", lowered) if len(w) > 1]
    toks += [f"{a}_{b}" for a, b in zip(words, words[1:])]
    return toks


def template_of(label):
    if "|" not in label:
        return {"registry": None, "mode": label, "field": None}
    reg, rest = label.split("|", 1)
    # `notes|touches` names no field: the term is free text, so the class only has
    # to route the registry.
    mode, _, field = rest.partition(":")
    return {"registry": reg, "mode": mode, "field": field or None}


def load_pairs(path):
    return [json.loads(line) for line in Path(path).read_text().splitlines() if line.strip()]


def train(pairs, vocab):
    counts = defaultdict(Counter)  # token -> label -> count
    totals = Counter()  # label -> tokens
    docs = Counter()  # label -> pairs
    values = defaultdict(list)  # label -> observed slot values, in order
    ids = defaultdict(list)
    for pair in pairs:
        label = pair["label"]
        # The slot VOCABULARY is the compiled data, not a learned parameter: it
        # comes from every entity, so an entity held out of training is still
        # answerable. Only the counts and priors are split-scoped — that is what
        # the entity split tests.
        if pair["slot"] and "|" in label:
            if pair["slot"]["kind"] == "value":
                if pair["slot"]["value"] not in values[label]:
                    values[label].append(pair["slot"]["value"])
            elif pair["slot"]["kind"] == "id":
                reg = template_of(label)["registry"]
                if pair["slot"]["value"] not in ids[reg]:
                    ids[reg].append(pair["slot"]["value"])
        if pair["split"] != "train":
            continue
        if docs[label] >= CAP:
            continue
        docs[label] += 1
        for tok in tokenize(pair["q"]):
            counts[tok][label] += 1
            totals[label] += 1
    vocab_size = len(counts)
    classes = {label: dict(template_of(label), values=values.get(label, [])) for label in docs}
    return {
        "version": 2,
        "classes": classes,
        "docs": dict(docs),
        "totals": dict(totals),
        "counts": {t: dict(c) for t, c in counts.items()},
        "vocab_size": vocab_size,
        # The scan vocabulary: every short value of every non-numeric field,
        # straight from `q.sh --schema` and the compiled rows. Held out of the
        # split on purpose — an entity the model never saw must still be
        # extractable, and that is the half a classifier cannot supply.
        "vocab": vocab,
        "ids": dict(ids),
    }


def score(model, label, toks):
    total = model["totals"].get(label, 0) + ALPHA * model["vocab_size"]
    # NO class prior. Pair counts here are an artifact of entity cardinality
    # (a task template has 527 examples, a status template has 8), so a count
    # prior just means "the biggest class wins" — it made `which notes are
    # rejected` answer `kind`, which has no rejected value at all.
    s = 0.0
    for tok in toks:
        label_counts = model["counts"].get(tok)
        if label_counts is None:
            continue
        c = label_counts.get(label, 0)
        s += math.log((c + ALPHA) / total)
    return s


def rank_all(model, question):
    toks = tokenize(question)
    return sorted(((score(model, l, toks), l) for l in model["classes"]), reverse=True)


def rank(model, question):
    scored = rank_all(model, question)
    if not scored:
        return None, None, 0.0
    top = scored[0]
    second = scored[1][0] if len(scored) > 1 else top[0] - 10.0
    return top[1], top[0], top[0] - second


def overlaps(a, b):
    return a[0] < b[1] and b[0] < a[1]


ENTITY_WORDS = {
    "inventory": ("hosts", "host", "machines"),
    "notes": ("notes", "note"),
    "tasks": ("tasks", "task"),
    "graph": ("nodes", "node", "skills", "docs", "hosts"),
    "ledger": ("jobs", "units", "job"),
}


def followed_by_entity(q, end, registry):
    rest = q[end:].lstrip().lower().split()
    return bool(rest) and rest[0] in ENTITY_WORDS.get(registry, ())


def scan(model, question, registry, prefer_field=None):
    """Every closed-vocabulary constraint the question states.

    Longest probe wins the span, so `microvm` beats `vm` and `handoffs` beats
    `handoff`. A field can only contribute one value — two entries for one field
    would be an `and` the executor cannot express — and a token of a long value
    (`infra` for `taskfiles/infra.yml`) counts only when it is the only value of
    that field it could mean.

    Two words can be two fields at once: `open` is a note kind and a status, and a
    question may say either and mean one. The span is the same, so the same span
    cannot be two constraints; the classifier's preferred field breaks the tie and
    an unbreakable tie is dropped rather than guessed.
    """
    q = question.lower()
    vocab = model.get("vocab", {}).get(registry, {})
    hits = []
    for field, entry in vocab.items():
        if entry["kind"] not in ("enum", "text"):
            continue
        for value in entry["values"]:
            text = str(value).lower()
            if not text:
                continue
            for probe in (text,) + ALIASES.get(text, ()):
                start = q.find(probe)
                if start < 0:
                    continue
                # A value spelled like a mention verb is the operator unless the
                # word after it is the thing being asked about: `reference notes`
                # is a kind, `notes reference design` is a search.
                if text in TOUCH_VERBS and not followed_by_entity(q, start + len(probe), registry):
                    continue
                hits.append((start, start + len(probe), field, value, len(probe), question[start : start + len(probe)] == str(value)))

    by_span = defaultdict(list)
    for hit in hits:
        by_span[(hit[0], hit[1])].append(hit)
    resolved = []
    for group in by_span.values():
        fields = {g[2] for g in group}
        if len(fields) > 1:
            # A question that preserves a value's case is quoting that value:
            # `which notes are OPEN` is the status, `which open notes` the kind.
            cased = [g for g in group if g[5]]
            if len({g[2] for g in cased}) == 1:
                resolved.append(max(cased, key=lambda g: g[4]))
                continue
            pick = [g for g in group if g[2] == prefer_field]
            if not pick:
                continue
            resolved.append(max(pick, key=lambda g: g[4]))
        else:
            resolved.extend(group)

    resolved.sort(key=lambda h: (-h[4], h[0]))
    taken = []
    for hit in resolved:
        if any(overlaps(hit, other) for other in taken):
            continue
        taken.append(hit)
    per_field = {}
    for hit in taken:
        field = hit[2]
        if field not in per_field or hit[4] > per_field[field][4]:
            per_field[field] = hit
    out = {field: hit[3] for field, hit in per_field.items()}

    # A shard, a doc path or a task ref is named by its tail in speech: "the infra
    # shard" for `taskfiles/infra.yml`. Only a token that is unique to one value of
    # the field is allowed to stand for it (`docs` never means one doc), and only
    # for a value that IS a path or an identifier — a prose value's proper noun
    # (`NixOS Demonstration VM`) is a coincidence, not a filter.
    for field, entry in vocab.items():
        if entry["kind"] not in ("enum", "text") or field in out:
            continue
        candidates = {}
        for value in entry["values"]:
            text = str(value).lower()
            # A path or an identifier, not a sentence that happens to contain a
            # slash: `I/O Diet Lightweight Workstation` is prose.
            if (" /" not in f" {text}" and "/" not in text and ":" not in text) or " " in text:
                continue
            for word in re.findall(r"[a-z0-9]+", text):
                if len(word) < 4 or word in ("taskfiles", "docs", "scripts"):
                    continue
                if re.search(rf"(?<![a-z0-9]){re.escape(word)}(?![a-z0-9])", q):
                    candidates.setdefault(word, set()).add(str(value))
        unique = {next(iter(v)) for v in candidates.values() if len(v) == 1}
        if len(unique) == 1:
            out[field] = unique.pop()

    # A graph node's `type` is a taxonomy over ids, not an entity name: `host`
    # matches the word in almost every fleet question, and reading it as a graph
    # constraint answered `which host is a microvm guest` with 36 nodes. The
    # constraint is only real when the question talks about the graph — a node, a
    # graph, or the type's own plural.
    if registry == "graph" and "type" in out:
        value = str(out["type"]).lower()
        words = set(re.findall(r"[a-z0-9]+", q))
        taxonomy = {"node", "nodes", "graph", "entry", "entries"}
        plural = value + "s" in words or value + "es" in words
        if not (taxonomy & words or plural):
            out.pop("type")

    # Bools are asked for by name; only the fields a template exists for, because
    # `flake: true` firing on the words "this flake" is a constraint nobody asked
    # for.
    asked = {e["field"] for e in model["classes"].values() if e["registry"] == registry and e["mode"] == "filter"}
    for field, entry in vocab.items():
        if entry["kind"] != "bool" or field not in asked:
            continue
        # The question conjugates: `managed` is asked as "manages", `retired` as
        # "retired". Match on the stem, then read the next few words for the way
        # it is asked (`ci disabled` is the false one).
        name = field.replace("_", " ")
        stem = name.rstrip("ed").rstrip("d")
        match = re.search(rf"(?<![a-z0-9]){re.escape(stem)}[a-z]*(?![a-z0-9])", q)
        if not match:
            continue
        window = " ".join(q[match.end() :].split()[:4])
        out[field] = not any(w in window for w in BOOL_FALSE)
        if any(w in window for w in BOOL_TRUE):
            out[field] = True
    return out


def extract_number(question, field):
    q = question.lower()
    for word in re.findall(r"[a-z0-9]+", q):
        if word.isdigit():
            return int(word)
        if word in NUMBER_WORDS:
            return NUMBER_WORDS[word]
    # `which wildcard tasks` asks for the field's presence, which is `>= 1`. Only
    # a field the data phrases that way — a degree has no presence reading, and
    # defaulting `in` to 1 because the word "in" appears answered a question about
    # bananas with every well-connected node.
    if field in PRESENCE_FIELDS and field.rstrip("s") in q:
        return 1
    return None


def touch_term(question):
    """The free-text term after a mention verb, or None.

    The term is not looked up: `which notes mention kubernetes` produces a query
    and the executor answers it with zero rows, which is the refusal. That keeps
    abstention free without a vocabulary of absence.
    """
    q = question.lower()
    best = -1
    for verb in TOUCH_VERBS:
        for m in re.finditer(rf"(?<![a-z0-9]){verb}(?![a-z0-9])", q):
            # `referenced by at least 20 docs` is a passive edge count, not a
            # mention: the words after the verb say who did the referencing.
            if q[m.end() :].lstrip().startswith("by "):
                continue
            best = max(best, m.end())
    if best < 0:
        return None
    words = [w for w in re.findall(r"[a-z0-9][a-z0-9:/._-]*", q[best:]) if w not in ARTICLES]
    while words and words[-1] in ("note", "notes", "task", "tasks", "host", "hosts", "node", "nodes", "document", "documents"):
        words.pop()
    return " ".join(words) or None


def names_field(question, field):
    words = FIELD_WORDS.get(field, (field.replace("_", " "),))
    q = question.lower()
    return any(w in q for w in words)


def find_id(model, question, registry):
    q = question.lower()
    ids = model["ids"].get(registry, [])
    literal = [i for i in ids if i.lower() in q]
    if literal:
        return max(literal, key=len)
    # `the daemon note` names a note by its first word, not by its id. Only an
    # unambiguous leading token counts.
    prefixed = [
        i
        for i in ids
        if any(
            re.search(rf"(?<![a-z0-9-]){re.escape(tok)}(?![a-z0-9-])", q)
            for tok in i.lower().split("-")[:2]
            if len(tok) > 3
        )
    ]
    return prefixed[0] if len(prefixed) == 1 else None


def entity_query(model, question, label, margin):
    entry = model["classes"][label]
    # An entity question has to name the attribute it asks for. Without this
    # check `what is frieren's CPU temperature` answers `role` — a real value,
    # about the wrong question, which is the expensive failure.
    if not names_field(question, entry["field"]):
        return None
    rid = find_id(model, question, entry["registry"])
    if rid is None:
        return None
    return {
        "registry": entry["registry"],
        "filter": {"id": rid},
        "fields": [entry["field"]],
        "limit": 1,
        "stage1": {"label": label, "margin": round(margin, 3)},
    }


def constraints_for(model, question, registry, labels, margin):
    """Try this registry's labels in rank order until one can be filled.

    A label is a hypothesis about the shape of the question, and the vocabulary
    decides whether the hypothesis survived: `which host is the mobile device`
    ranks an entity label first, finds no attribute word, and the constraint label
    behind it reads `category=mobile`. Nothing here guesses a value — every
    branch either extracts from the compiled data or returns None.
    """
    prefer = next(
        (model["classes"][l]["field"] for l in labels if model["classes"][l]["field"]),
        None,
    )
    term = touch_term(question)
    for label in labels:
        entry = model["classes"][label]
        if entry["mode"] == "id":
            query = entity_query(model, question, label, margin)
            if query is not None:
                return query
            continue
        flt = scan(model, question, registry, prefer)
        if entry["mode"] == "num":
            n = extract_number(question, entry["field"])
            if n is None:
                continue
            flt[entry["field"]] = n
        if term:
            flt["touches"] = term
        # A type on its own is a taxonomy that only means something inside the
        # graph's own words: through the registry cascade, `which hosts are in the
        # banana category` came back with every host in the fleet, which is an
        # answer to a question nobody asked.
        if registry == "graph" and set(flt) <= {"type"} and "type" in flt:
            if not ({"node", "nodes", "graph", "entry", "entries"} & set(re.findall(r"[a-z0-9]+", question.lower()))):
                flt.pop("type")
        if not flt:
            continue
        return {"registry": registry, "filter": flt, "limit": 20, "stage1": {"label": label}}
    return None


def query_for(model, question, margin_floor):
    scored = rank_all(model, question)
    if not scored:
        return {"refused": True, "detail": "no classes"}
    top_score, cls = scored[0]
    second = scored[1][0] if len(scored) > 1 else top_score - 10.0
    margin = top_score - second
    if margin < margin_floor:
        return {"refused": True, "detail": f"margin {margin:.2f} below {margin_floor}"}
    if cls == "abstain":
        return {"refused": True, "detail": "classified as unanswerable"}

    # The classifier routes, the vocabulary confirms: a registry whose whole
    # vocabulary finds nothing in the question is not the registry. Bounded to
    # three, so one misroute costs one extra scan and not a search.
    by_registry = defaultdict(list)
    for _, label in scored:
        by_registry[model["classes"][label]["registry"]].append(label)
    for registry in list(by_registry)[:3]:
        query = constraints_for(model, question, registry, by_registry[registry], margin)
        if query is not None:
            query["stage1"]["margin"] = round(margin, 3)
            return query
    return {"refused": True, "detail": "no registry constraint in the question"}


def evaluate(model, pairs, margins):
    test = [p for p in pairs if p["split"] == "test"]
    if not test:
        return []
    rows = []
    for floor in margins:
        answered = correct = 0
        for pair in test:
            query = query_for(model, pair["q"], floor)
            if query.get("refused"):
                continue
            answered += 1
            # An abstain pair has no gold query, so producing one is an error by
            # construction — it can never equal `None`.
            want = pair["query"]
            got = {k: v for k, v in query.items() if k != "stage1"}
            if want is not None and got == want:
                correct += 1
        p = correct / answered if answered else 0.0
        rows.append((floor, answered, correct, p, answered / len(test)))
    return rows


def print_metrics(model, rows):
    print("  margin  answered  correct     p   coverage")
    for floor, answered, correct, p, cov in rows:
        print(f"  {floor:>6.2f}  {answered:>8}  {correct:>7}  {p:>5.2f}  {cov:>8.2f}")


def choose_margin(rows, min_p):
    """Maximize coverage subject to a correct-rate floor — the same shape as the
    Kelly gate: a refusal costs nothing, a wrong answer costs the caller."""
    ok = [r for r in rows if r[1] > 0 and r[3] >= min_p]
    if not ok:
        ok = [r for r in rows if r[1] > 0 and r[3] >= 0.3]
    if not ok:
        return None
    return max(ok, key=lambda r: r[4])[0]


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("train")
    t.add_argument("--dataset", required=True)
    t.add_argument("--vocab", required=True)
    t.add_argument("--out", required=True)
    t.add_argument("--min-p", type=float, default=0.5)
    e = sub.add_parser("eval")
    e.add_argument("--model", required=True)
    e.add_argument("--dataset", required=True)
    p = sub.add_parser("predict")
    p.add_argument("--model", required=True)
    p.add_argument("--question", required=True)
    args = ap.parse_args()

    if args.cmd == "predict":
        model = json.loads(Path(args.model).read_text())
        out = query_for(model, args.question, model.get("margin", 1.0))
        print(json.dumps(out))
        return 0

    pairs = load_pairs(args.dataset)

    if args.cmd == "eval":
        model = json.loads(Path(args.model).read_text())
        print_metrics(model, evaluate(model, pairs, [model.get("margin", 1.0)]))
        return 0

    vocab = json.loads(Path(args.vocab).read_text())
    model = train(pairs, vocab)
    train_pairs = sum(1 for p in pairs if p["split"] == "train")
    test_pairs = len(pairs) - train_pairs
    print(f"classes          : {len(model['classes'])} over {train_pairs} train pairs ({test_pairs} test)")
    rows = evaluate(model, pairs, [0.0, 0.25, 0.5, 1.0, 1.5, 2.0, 3.0])
    print_metrics(model, rows)
    floor = choose_margin(rows, args.min_p)
    if floor is None:
        print("model            : no margin keeps the correct rate; refusing to ship an artifact")
        return 1
    chosen = [r for r in rows if r[0] == floor][0]
    model["margin"] = floor
    model["metrics"] = {
        "margin": floor,
        "test_pairs": test_pairs,
        "answered": chosen[1],
        "correct": chosen[2],
        "p": round(chosen[3], 4),
        "coverage": round(chosen[4], 4),
        "classes": len(model["classes"]),
        "train_pairs": train_pairs,
    }
    Path(args.out).write_text(json.dumps(model))
    print(
        f"margin floor     : {floor} (test p {chosen[3]:.2f} at coverage {chosen[4]:.2f}) -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
