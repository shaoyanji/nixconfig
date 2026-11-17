---
name: ontology
description: "Pick me before adding a node or edge type to the knowledge graph: identity, domain and range, and the evidence a relation earns — a name match is a candidate, a resolved id is a proof."
version: 0.1.0
author: Shaoyan Ji (shaoyanji)
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [ontology, graph, schema, kg, types, evidence]
    related_skills: [knowledge-base, master-toon, agents-notes]
---

# ontology — what may exist in the graph, and what an edge proves

`flake/ontology.nix` is the schema `.#knowledgeGraph` is an instance of: eight
entity types and eight relations. It answers what `flake/epistemics.nix` cannot.
Epistemics says which **source** may settle a claim; ontology says which
**thing** a claim can be filed on, and how strong an edge between two things is.

Truth: `flake/ontology.nix`, read as `.#ontology`, proven against the graph by
`checks:ontology`.

## 1. Three questions before a new type

A type is a claim about the world, not a label for a list. Answer all three or
leave the type out.

| Question | Field | A wrong answer looks like |
| :--- | :--- | :--- |
| What makes two of these the same thing? | `identity` | a path when the file moves, a title when the title is copy |
| What enumerates membership, compiled? | `member` | a hand-kept list that disagrees with the tree |
| Which claim kinds can be filed on one? | `claims` | a kind with no home, so it is researched forever |

`claims` names ids from `.#epistemics.kindIds`, and a stable kind with no entity
home must name a `sinks` entry instead (the vault, an `AGENTS.nix` note). A
moving kind (`current-release`) has no durable home by design: the answer carries
its date.

## 2. The relation contract

Every relation declares domain, range, multiplicity, and **what its evidence
is**. The evidence tier is the part that keeps an answer honest:

| Tier | Means | Example here |
| :--- | :--- | :--- |
| `asserted` | a person wrote it in frontmatter | `tagged`, `about` |
| `resolved` | the target was looked up and exists | `references`, `cites` |
| `extracted` | a token or import path matched the text | `mentions`, `imports` |

`mentions` and `imports` are candidates. A page can name a host without depending
on it, and an import can sit on a branch no host enables. Treat a tier-2 edge as
"look here", never as "this is why".

The design record is a type too. `note` is an `AGENTS.nix` entry, and `derives`
and `supersedes` link note to note. Both are `resolved` because the note schema
gates the target, and `supersedes` must land on a note marked `SUPERSEDED`. The
arrow records what the author said; it does not prove the later note is right.

Every relation also carries `cannot`: the inference a reader must not make from
it. If you cannot write that sentence, the relation is not yet understood.

## 3. Procedure for a change

```bash
nix eval --json .#ontology.entities | toon -e     # declared types, identity, fields, claims
nix eval --json .#ontology.relations | toon -e    # domain, range, evidence, tier
nix eval --json .#ontology.all | toon -e          # three sample edges; the third is refused
nix eval --json .#ontology.unhomed | toon -e      # stable kinds with nowhere to land
```

1. **Read the declaration before the code.** `.#ontology` is the contract; the
   extractor in `lib/knowledge-graph.nix` is one implementation of it.
2. **Decide whether the thing is a new type or a field on an existing one.** A
   field costs one line in `fields`; a type costs identity, membership,
   relations, a canvas colour and every query that enumerates types.
3. **Ask `admit` for the edge you intend to emit.** If the pair is refused, the
   domain or range is wrong, not the data.
4. **Emit the edge only with evidence a reader can re-run**: a frontmatter list,
   a link, a citation, an import path. A name in a sentence is the weakest of the
   four, so it is the last tier.
5. **Prove the declaration against the compiled graph**, then read the failure
   text literally — it names the type, the field or the edge:

```bash
task check:leaf NAME=checks:ontology
```

## 4. What the gate proves, and what it does not

`checks:ontology` evaluates `.#knowledgeGraph` and fails when:

- the graph emits a node or edge type the declaration does not name;
- a declared entity type or relation has become empty (a dead type is a lie
  about the shape of the repo);
- a node carries a field its entity type does not declare, or a relation's
  endpoint is outside its domain and range;
- an entity or relation has empty `identity`, `member`, `evidence` or `cannot`;
- a stable claim kind has no home, or a `sinks` key names no kind.

It does **not** prove that an edge is true. `references` proves a link resolves,
not that the linked page is right; `cites` proves a policy id exists, not that
the citing page obeys it. Those stay with the reader.

Cost: one graph evaluation (~10 s cold, no build). It runs in the pre-commit
hook when the type contract or the emitter is staged, and nightly on `frieren` as
`kg-ontology-check.service`, which the fleet sentinel watches — so drift on a
branch nobody committed still pages.

## 5. Counterexamples to carry

Each of these was a real silent failure in this tree, and each is why a rule
above exists.

- `hasInfix "dev"` counted `devji` as a mention of the `dev` skill, and the
  headline `ops:kg` output was wrong. Token matching, not substring matching.
- A path in prose that is not a document is not a `references` edge. Only a doc
  in the doc set becomes a node, and `checks:docs:links` gates the rest.
- An `about:` entry with a typo used to shrink the graph quietly. Now the edge is
  only emitted for an id that exists, and the gate fails instead.
- A successful `nix eval` proves the graph compiles, not that its types mean what
  a reader assumes. That is the gap this file exists to name.

## 6. Fail closed on a model gap

If a relation you need cannot be extracted with evidence, declare the gap rather
than widening a tier. Two honest outcomes:

- the relation exists in the declaration with `tier = "extracted"` and a
  `cannot` that says what it misses; or
- it is not added, and the question is answered by `ops:kg:*` plus a read.

Adding a token scan and calling it a dependency is the failure mode.

## 7. Where the contract came from

The modelling discipline is NVIDIA's `auto-ontology` skill (Apache-2.0,
reviewed 2026-11-17, not installed): identity and population before attributes, a
relationship contract with direction, cardinality and join evidence, tested
counterexamples, and "a successful execution does not certify correctness".
What did not transfer: MCP, SQL validation, publication receipts and rollback —
there is no service here, so the compiled graph is the readback and this gate is
the publication step.
