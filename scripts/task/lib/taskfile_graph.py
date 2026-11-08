#!/usr/bin/env python3
"""taskfile_graph.py — the Taskfile plane as data: one YAML parser, one rule set.

Nix used to re-parse `Taskfile.yml` and its included shards with a hand-written
line grammar (`lib/taskfile.nix`, 662 lines) because `checks.<system>` had to
assert rules over the graph at eval time. That made a SECOND YAML parser for a
tree go-task already parses, and it paid an eval (0.7 s) for every graph read.

So the parser here is yq — a real YAML implementation, already required by
`check.sh` — and the rules are this file. `task --list-all --json` stays the
oracle for the name set: yq cannot know which names go-task actually loads.

Modes
  report     the gate's whole input, one JSON leaf (names, files, violations…)
  by-name    `{name: {name, shard, desc, summary, cmds, body, …}}` — the read the
             dispatcher (`toolcall.sh`), the registry (`q.sh tasks`) and the edge
             checker use
  names      one name per line, for the parity diff against go-task
  citations  backticked `task <name>` citations in docs/agent-contract.md that name
             nothing; exit 1 when there are any

Exit: 0 the graph was read · 1 yq could not parse a file (or a dangling citation)
      · 2 usage.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))

GATE_BUCKETS = [
    "duplicate",
    "orphanShard",
    "missingInclude",
    "includeCycle",
    "unflattened",
    "internal",
    "wildcardArity",
    "danglingRef",
    "retiredRef",
    "sourcesWithoutWatch",
    "longSummary",
    "longDesc",
    "noDesc",
    "exitDrift",
]

DESC_BUDGET = 240
SUMMARY_BUDGET = 600

# A reference is only real in a COMMAND position: line start, or after `$(`, `&&`,
# `||`, `;`, `|`. Matching `task <word>` anywhere counts prose, and prose is a
# different (advisory) bucket — a first version that did not separate them
# reported 34 "dangling" refs, ~30 of them English.
REF_RE = re.compile(r"(.*[;&|(]\s*)?task ([A-Za-z0-9:._*-]+).*")
PROSE_BACKTICKED_RE = re.compile(r"`task ([A-Za-z0-9:._*-]+)`")
# At least one character after the separator, and no `.` in the tail: without
# that, "confirmed against go-task itself." yields the reference `itself.`.
PROSE_NAMESPACED_RE = re.compile(r"task ([a-z0-9-]+[:.][A-Za-z0-9:_*-]+)")
MATCH_INDEX_RE = re.compile(r"\{\{index \.MATCH ([0-9]+)\}\}")
NAME_OK_RE = re.compile(r"[a-z0-9][a-z0-9-]*([:.][a-z0-9*][a-z0-9.*-]*)*")
ARG_LIKE_RE = re.compile(r"([A-Z][A-Z0-9_]*|<[^>]*>)")
SCRIPT_REF_RE = re.compile(r"(scripts/task/[A-Za-z0-9._/-]+\.sh)")
RETIRED_RE = re.compile(r"\[(removed|deprecated)\]")
INCLUDE_RE = re.compile(r"^\s*includes:\s*$")


def die(msg: str, code: int = 2):
    print(f"taskfile_graph: {msg}", file=sys.stderr)
    raise SystemExit(code)


# --- parsing ------------------------------------------------------------------


class Obj(dict):
    """A JSON object that remembers keys it was given twice.

    YAML keeps the last of a duplicate key silently, and go-task inherits that —
    so the only place a duplicate task name is visible at all is the pair stream
    (`yq` emits both), which is what the `duplicate` bucket reads.
    """

    def __init__(self, pairs):
        super().__init__(pairs)
        seen, dups = set(), []
        for key, _ in pairs:
            if key in seen and key not in dups:
                dups.append(key)
            seen.add(key)
        self.dups = dups


def yq(path: str) -> dict:
    """One file through yq. Comments are dropped here, so the few rules that need
    them (`[removed]`, `{{index .MATCH n}}`) read the raw text instead
    (`task_blocks`)."""
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        die(f"cannot read {path}: {exc}")
    proc = subprocess.run(
        ["yq", "-o=json", "-I0", "."],
        input=text,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        die(f"yq cannot parse {path}: {proc.stderr.strip()}", 1)
    return json.loads(proc.stdout or "{}", object_pairs_hook=Obj)


def dir_of(path: str) -> str:
    return path.rsplit("/", 1)[0] if "/" in path else ""


def normalize(directory: str, path: str) -> str:
    joined = path if directory == "" else f"{directory}/{path}"
    out: list[str] = []
    for segment in joined.split("/"):
        if segment in ("", "."):
            continue
        if segment == "..":
            if out:
                out.pop()
            continue
        out.append(segment)
    return "/".join(out)


def include_edges(rel: str, doc: dict) -> list[dict]:
    edges = []
    for alias, spec in (doc.get("includes") or {}).items():
        spec = spec or {}
        target = spec.get("taskfile")
        edges.append(
            {
                "alias": alias,
                "from": rel,
                "taskfile": target,
                "path": None if target is None else normalize(dir_of(rel), str(target)),
                "flatten": spec.get("flatten") is True,
            }
        )
    return edges


def walk(rel: str, ancestors: list[str], cache: dict) -> dict:
    doc = cache.get(rel) or yq(os.path.join(ROOT, rel))
    cache[rel] = doc
    edges = include_edges(rel, doc)
    order, all_edges, cycles, missing = [rel], [], [], []
    for edge in edges:
        target = edge["path"]
        exists = target is not None and os.path.exists(os.path.join(ROOT, target))
        if target is not None and target in ancestors:
            cycles.append(edge)
        if not exists:
            missing.append(edge)
            continue
        if target in ancestors:
            continue
        sub = walk(target, ancestors + [target], cache)
        order += sub["order"]
        all_edges += sub["edges"]
        cycles += sub["cycles"]
        missing += sub["missing"]
    return {
        "order": order,
        "edges": edges + all_edges,
        "cycles": cycles,
        "missing": missing,
    }


def task_blocks(text: str) -> dict[str, str]:
    """`{name: block text}` from the raw shard.

    Two rules need what yq drops: the `[removed]` / `[deprecated]` comment and
    `{{index .MATCH n}}`, which lives in `vars:` as often as in `cmds:`. So the
    block runs from a task's name line to the next line at the same indent.
    """
    blocks: dict[str, str] = {}
    indent = None
    current = None
    lines: list[str] = []
    in_tasks = False
    for line in text.split("\n"):
        if line.rstrip() == "tasks:" and not line.startswith((" ", "\t")):
            in_tasks = True
            continue
        if not in_tasks:
            continue
        if not line.strip():
            if current is not None:
                lines.append(line)
            continue
        ind = len(line) - len(line.lstrip(" "))
        if ind == 0:
            break
        if indent is None:
            indent = ind
        if ind == indent:
            if current is not None:
                blocks[current] = "\n".join(lines)
            current = line.strip().rstrip(":").strip("'\"")
            lines = [line]
        elif current is not None:
            lines.append(line)
    if current is not None:
        blocks[current] = "\n".join(lines)
    return blocks


def as_cmds(task: dict) -> list[str]:
    out = []
    for cmd in task.get("cmds") or []:
        if isinstance(cmd, str):
            out.append(cmd)
        elif isinstance(cmd, dict):
            if "cmd" in cmd:
                out.append(str(cmd["cmd"]))
            elif "task" in cmd:
                out.append(f"task: {cmd['task']}")
    return out


def declared_vars(task: dict):
    """`vars:` verbatim: a mapping is the env var surface (`SYSTEM: {sh: …}`)."""
    return task.get("vars")


def declared_params(task: dict) -> list[str]:
    """The parameter surface: `requires.vars: [Q]`.

    This is what makes a task a call target — a tool with no arguments cannot fill
    anything. It is a separate field from `vars:` on purpose: a computed `SYSTEM`
    var is not a parameter a caller supplies.
    """
    requires = task.get("requires") or {}
    vars_ = requires.get("vars") if isinstance(requires, dict) else None
    if isinstance(vars_, list):
        return [str(v) for v in vars_]
    return []


# --- references ---------------------------------------------------------------


def refs_in_line(line: str) -> list[str]:
    if line.lstrip().startswith("#"):
        return []
    match = REF_RE.fullmatch(line)
    if match is None:
        return []
    name = match.group(2)
    if name.startswith("-"):
        return []
    return [name]


def prose_refs(text: str | None) -> list[str]:
    if not text:
        return []
    found = PROSE_BACKTICKED_RE.findall(text) + PROSE_NAMESPACED_RE.findall(text)
    seen, out = set(), []
    for name in found:
        if name.startswith("-") or name in seen:
            continue
        seen.add(name)
        out.append(name)
    return out


def segments(name: str) -> list[str]:
    return name.split(":")


def wild_match(pattern: str, ref: str) -> bool:
    pat, got = segments(pattern), segments(ref)
    if len(pat) != len(got):
        return False
    return all(p == "*" or p == g for p, g in zip(pat, got))


class Resolver:
    def __init__(self, names: list[str], aliases: list[str]):
        self.names = set(names)
        self.aliases = set(aliases)
        self.wild = [n for n in names if "*" in n]

    def resolves(self, ref: str) -> bool:
        return (
            ref in self.names
            or ref in self.aliases
            or any(wild_match(w, ref) for w in self.wild)
        )

    def ref_name(self, ref: str) -> str | None:
        cleaned = ref.split("=", 1)[0]
        parts = segments(cleaned)
        while parts:
            candidate = ":".join(parts)
            if self.resolves(candidate):
                return candidate
            if ARG_LIKE_RE.fullmatch(parts[-1]):
                parts = parts[:-1]
                continue
            return None
        return None

    def family_like(self, ref: str) -> bool:
        return ref.endswith(":*") and any(
            n.startswith(ref[:-1]) for n in self.names
        )


# --- exit codes: the promise vs the shell that keeps it -----------------------


def claim_text(claim: tuple[int, int]) -> str:
    lo, hi = claim
    return str(lo) if lo == hi else f"{lo}-{hi}"


def claim_holds(claim: tuple[int, int], code: int) -> bool:
    return claim[0] <= code <= claim[1]


def code_in(text: str) -> list[int]:
    codes = [int(n) for n in re.findall(r"(?:exit)\s+([0-9]+)", text)]
    if 'exit "$' in text:
        codes += [int(n) for n in re.findall(r"(?:fail|rc|status|code)=([0-9]+)", text)]
    return sorted(set(codes))


def claims_in(summary: str | None) -> list[tuple[int, int]]:
    if not summary:
        return []
    bands = [
        (int(lo), int(hi))
        for lo, hi in re.findall(
            r"[Ee]xits?\s*\(?([0-9]+)\s*[-–]\s*([0-9]+)", summary
        )
    ]
    singles = [(int(n), int(n)) for n in re.findall(r"[Ee]xits?\s*\(?([0-9]+)", summary)]
    listed_bands: list[tuple[int, int]] = []
    listed_singles: list[tuple[int, int]] = []
    if bands or singles:
        listed_bands = [
            (int(lo), int(hi))
            for lo, hi in re.findall(r"([0-9]+)\s*[-–]\s*([0-9]+)\s*=", summary)
        ]
        listed_singles = [
            (int(n), int(n)) for n in re.findall(r"([0-9]+)\s*=", summary)
        ]
    # `130-137 = …` also matches the single-number pattern on its right edge.
    all_singles = [
        s
        for s in singles + listed_singles
        if not any(b[0] <= s[0] and s[1] <= b[1] for b in bands + listed_bands)
    ]
    out, seen = [], set()
    for claim in bands + listed_bands + all_singles:
        if claim == (0, 0) or claim in seen:
            continue
        seen.add(claim)
        out.append(claim)
    return out


# --- the graph ----------------------------------------------------------------


def build() -> dict:
    cache: dict[str, dict] = {}
    graph = walk("Taskfile.yml", ["Taskfile.yml"], cache)
    files = list(dict.fromkeys(graph["order"]))
    includes = graph["edges"]
    reachable = {e["path"] for e in includes if e["path"]}

    parsed: list[dict] = []
    intra_file_dups: list[str] = []
    for rel in files:
        doc = cache.get(rel) or yq(os.path.join(ROOT, rel))
        cache[rel] = doc
        try:
            with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
                blocks = task_blocks(fh.read())
        except OSError:
            blocks = {}
        tasks = doc.get("tasks") or {}
        for dup in getattr(tasks, "dups", []):
            if dup not in intra_file_dups:
                intra_file_dups.append(dup)
        for name, task in tasks.items():
            task = task or {}
            desc = task.get("desc")
            summary = task.get("summary")
            # A `>` block scalar carries a trailing newline; it is not part of what
            # `task --list` prints or what an agent reads, so it is not part of the
            # budget either.
            if isinstance(desc, str):
                desc = desc.strip()
            if isinstance(summary, str):
                summary = summary.strip()
            cmds = as_cmds(task)
            body = "\n".join(cmds)
            block = blocks.get(name, body)
            parsed.append(
                {
                    "name": name,
                    "shard": rel,
                    "desc": desc if isinstance(desc, str) else None,
                    "summary": summary if isinstance(summary, str) else None,
                    "body": body,
                    "cmds": cmds,
                    "vars": declared_vars(task),
                    "params": declared_params(task),
                    "aliases": [str(a) for a in (task.get("aliases") or [])],
                    "wildcards": name.count("*"),
                    "matchIndices": [int(n) for n in MATCH_INDEX_RE.findall(block)],
                    "refs": [r for cmd in cmds for r in refs_in_line(cmd)],
                    "proseRefs": prose_refs(
                        (desc or "") + " " + (summary or "")
                    ),
                    "retired": RETIRED_RE.search(block) is not None,
                    "internal": task.get("internal") is True,
                    "declaresSources": "sources" in task or "generates" in task,
                    "declaresWatch": task.get("watch") is True,
                }
            )

    names = [t["name"] for t in parsed]
    resolver = Resolver(names, [a for t in parsed for a in t["aliases"]])
    by_name = {t["name"]: t for t in parsed}
    counts: dict[str, int] = {}
    for name in names:
        counts[name] = counts.get(name, 0) + 1

    violations: dict[str, list[str]] = {
        "orphanShard": [
            f
            for f in sorted(
                os.path.basename(p)
                for p in _shard_files()
            )
            if f"taskfiles/{f}" not in reachable
        ],
        "missingInclude": [
            f"{e['from']}: {e['alias']} -> {e['path']}" for e in graph["missing"]
        ],
        "includeCycle": [
            f"{e['from']}: {e['alias']} -> {e['path']}" for e in graph["cycles"]
        ],
        "unflattened": [
            f"{e['from']}: {e['alias']} -> {e['path']}"
            for e in includes
            if not e["flatten"]
        ],
        "duplicate": list(
            dict.fromkeys(intra_file_dups + [n for n in counts if counts[n] > 1])
        ),
        "nameGrammar": [
            f"{t['shard']}:{t['name']}"
            for t in parsed
            if NAME_OK_RE.fullmatch(t["name"]) is None
        ],
        "wildcardArity": [
            f"{t['shard']}:{t['name']} has {t['wildcards']} '*' but "
            f"{len(t['matchIndices'])} MATCH refs "
            f"[{','.join(str(i) for i in t['matchIndices'])}]"
            for t in parsed
            if len(t["matchIndices"]) != t["wildcards"]
        ],
        "internal": [f"{t['shard']}:{t['name']}" for t in parsed if t["internal"]],
        "noDesc": [
            f"{t['shard']}:{t['name']}"
            for t in parsed
            if t["desc"] is None and t["summary"] is None
        ],
        "longDesc": [
            f"{t['shard']}:{t['name']} ({len(t['desc'])})"
            for t in parsed
            if t["desc"] is not None and len(t["desc"]) > DESC_BUDGET
        ],
        "longSummary": [
            f"{t['shard']}:{t['name']} ({len(t['summary'])})"
            for t in parsed
            if t["summary"] is not None and len(t["summary"]) > SUMMARY_BUDGET
        ],
        "sourcesWithoutWatch": [
            f"{t['shard']}:{t['name']}"
            for t in parsed
            if t["declaresSources"] and not t["declaresWatch"]
        ],
        "danglingRef": [],
        "proseRef": [],
        "exitDrift": [],
        "exitUnverified": [],
        "retiredRef": [],
    }

    for task in parsed:
        for ref in task["refs"]:
            if resolver.ref_name(ref) is None:
                violations["danglingRef"].append(
                    f"{task['shard']}:{task['name']} -> {ref}"
                )
        for ref in task["proseRefs"]:
            if resolver.ref_name(ref) is None and not resolver.family_like(ref):
                violations["proseRef"].append(
                    f"{task['shard']}:{task['name']} -> {ref}"
                )
        for ref in task["refs"]:
            name = resolver.ref_name(ref)
            if name is None or name == task["name"]:
                continue
            target = by_name.get(name)
            if target is not None and target["retired"]:
                violations["retiredRef"].append(
                    f"{task['shard']}:{task['name']} -> {ref}"
                )

        claims = claims_in(task["summary"])
        if not claims:
            continue
        script_refs: list[str] = []
        for cmd in task["cmds"]:
            for ref in SCRIPT_REF_RE.findall(cmd):
                if ref not in script_refs:
                    script_refs.append(ref)
        inline = code_in("\n".join(task["cmds"]))
        known = [r for r in script_refs if os.path.exists(os.path.join(ROOT, r))]
        emitted: list[int] = []
        for code in inline:
            if code not in emitted:
                emitted.append(code)
        for ref in known:
            try:
                with open(os.path.join(ROOT, ref), encoding="utf-8") as fh:
                    codes = code_in(fh.read())
            except OSError:
                codes = []
            for code in codes:
                if code not in emitted:
                    emitted.append(code)
        if known != script_refs:
            violations["exitUnverified"].append(
                f"{task['shard']}:{task['name']} claims exit "
                f"{', '.join(claim_text(c) for c in claims)} but "
                f"{', '.join(r for r in script_refs if r not in known)} is not in the tree"
            )
        # A task that only runs a tool inherits that tool's status, so there is
        # nothing to compare: a claim it cannot emit itself is unjudgeable, not
        # drift. Failing those failed correct summaries (`docs:site` claims 1 from
        # `nix build`).
        elif not inline and not known:
            continue
        elif [c for c in claims if not any(claim_holds(c, e) for e in emitted)]:
            violations["exitDrift"].append(
                f"{task['shard']}:{task['name']} claims exit "
                f"{', '.join(claim_text(c) for c in claims)}; emits "
                f"[{' '.join(str(e) for e in emitted)}]"
            )

    gate_failures = [f"{k}: {v}" for k in GATE_BUCKETS for v in violations[k]]
    return {
        "names": names,
        "files": files,
        "violations": violations,
        "gateBuckets": GATE_BUCKETS,
        "gateFailures": gate_failures,
        "includes": [
            {
                "alias": e["alias"],
                "from": e["from"],
                "path": e["path"],
                "flatten": e["flatten"],
            }
            for e in includes
        ],
        "count": len(parsed),
        "parsed": parsed,
        "byName": by_name,
    }


CONTRACT_PAGE = "docs/agent-contract.md"


def citations(graph: dict) -> list[str]:
    """Backticked `task <name>` citations on the contract page that name nothing.

    This was the policy `contract-tasks-resolve` in `flake/policies.nix`, which
    read the name set out of `lib/taskfile.nix` at eval time. A citation to a task
    nobody can run is worse than no citation — it makes the door look closed — so
    the rule stays, with the graph that can answer it.

    A wildcard shard resolves by its static prefix (`find:<word>` -> `find:*`).
    """
    try:
        with open(os.path.join(ROOT, CONTRACT_PAGE), encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return []
    names = set(graph["names"])
    wildcards = [n for n in graph["names"] if "*" in n]

    def resolves(name: str) -> bool:
        if name in names:
            return True
        return any(w.split("*")[0] in name for w in wildcards)

    unknown = []
    for segment in text.split("`"):
        if not segment.startswith("task "):
            continue
        name = segment[len("task ") :].split(" ", 1)[0]
        # A flag (`task --list-all`) and a placeholder (`task <name>`, `task X`)
        # are not citations of a task; only a name that claims to be one is.
        if not name or name.startswith("-") or name.startswith("<"):
            continue
        if name in ("X", "NAME") or "…" in name:
            continue
        if not resolves(name) and name not in unknown:
            unknown.append(name)
    return unknown


def _shard_files() -> list[str]:
    directory = os.path.join(ROOT, "taskfiles")
    try:
        return [
            os.path.join("taskfiles", n)
            for n in sorted(os.listdir(directory))
            if n.endswith(".yml")
        ]
    except OSError:
        return []


def main() -> int:
    global ROOT
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument(
        "mode",
        choices=["report", "by-name", "names", "citations"],
        nargs="?",
        default="report",
    )
    # `--root` is the fixture's door in (tests/taskfile-graph): a bucket that has
    # only ever been run against a clean tree is a bucket nobody knows the shape of.
    parser.add_argument("--root", default=ROOT)
    args = parser.parse_args()
    ROOT = os.path.abspath(args.root)
    graph = build()
    if args.mode == "citations":
        unknown = citations(graph)
        if unknown:
            print("citations that name no task: " + ", ".join(unknown))
            return 1
        return 0
    if args.mode == "names":
        print("\n".join(graph["names"]))
    elif args.mode == "by-name":
        print(json.dumps(graph["byName"], sort_keys=True, separators=(",", ":")))
    else:
        report = {k: graph[k] for k in ("names", "files", "violations", "gateBuckets", "gateFailures", "includes", "count")}
        print(json.dumps(report, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
