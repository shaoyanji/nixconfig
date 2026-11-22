# Elastic — Principal Software Engineer I, CI/CD (Platform Engineering Productivity)

**Status: packet built 2026-11-22, NOT submitted.** No browser opened, no form read, no
account created. The record is `prep` and stays there until someone decides to send it.

The role sits in Elastic's Platform Engineering Productivity team, which owns CI, CD and
release infrastructure for the company. The posting is explicit that the influence runs
through other engineers: roadmap ownership, release gates, supply-chain integrity,
incident command on release incidents, and standards adopted by teams that do not report
to the role. Elastic is the search and search-AI company; the platform team's problem is
scale plus supply chain, not search relevance.

## Role

| Field | Value |
| :--- | :--- |
| Company | Elastic (distributed, ~3,000 people) |
| Role | Principal Software Engineer I, CI/CD |
| Team | Platform Engineering Productivity |
| Greenhouse req | `8267186` |
| Apply URL | https://jobs.elastic.co/jobs?gh_jid=8267186 |
| Board | `elastic` |
| Location | Poland (posted band in PLN; sibling reqs for IE, PT, ES — none for Germany) |
| Language | English |
| Compensation | 369,400–584,300 PLN base, no variable component |
| Pipeline record | `elastic-principal-cicd-platform`, stage `prep`, fit unset |
| Folder | `submissions/elastic-principal-cicd-platform/` |

## The two questions this packet does not answer

Both are operator decisions, so the letter asks instead of assuming, and the sheet
records them rather than resolving them:

1. **Country.** The req is for Poland. The candidate is in Germany, holds German
   permanent residence and needs no permit to work there — but a Polish contract is a
   different legal entity and, if the role is hybrid or office-based, a relocation. The
   lead note says sibling reqs exist for Ireland, Portugal and Spain and none for
   Germany, so a Germany-based hire is a question for the recruiter, not a fact. The
   letter says exactly that: *"the posting is for Poland and I am in Germany; I would
   rather ask whether a Germany contract exists than assume a relocation nobody has
   agreed to."* If the answer is relocation to Poland, that is the candidate's call, not
   the packet's.
2. **Level.** Principal I at Elastic is an org-wide scope role, and the JD asks for a
   track record of cross-org ownership plus directing other engineers. The letter does
   not inflate the fleet into a team: it says standards and design review were adopted
   voluntarily, and that managing engineers with quarterly goals is not something done
   here. Expect the level conversation to be the hard part, not the technical one.

## Files in `submissions/elastic-principal-cicd-platform/`

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | 2 pages, sha256 `dd1fadca9b12cf614a8173421bf2181d49a323d93e7fb431692519615ed630cf` |
| `packet/anschreiben.pdf` | 1 page English, sha256 `2a0c46b6f5aa1f8562a33aa1c0e9283d9d456b9e1d3482cc9a06e5aa1570c4a6` |
| `packet/selection.json` | Projection audit, kept and dropped lines with scores |
| `letter.json` | Letter source, so the PDF is reproducible from this tree |
| `job-description.txt` | Posting text as given (no header block; company/req data lives here and in `lead.md`) |
| `lead.md` | The originating lead |
| `submission-sheet.md` | This sheet |

Built with:

```
task agents:apps:packet ID=elastic-principal-cicd-platform \
  JD=submissions/elastic-principal-cicd-platform/job-description.txt \
  LETTER=submissions/elastic-principal-cicd-platform/letter.json \
  OUT=/tmp/elastic-packet
```

Compiled in the Nix sandbox on `eu.nixbuild.net`; the store artifact is
`/nix/store/h0dgksn7bpmi7bazvhpz5qim64mbac8i-appflow-packet-elastic-principal-cicd-platform`.
The copies in `packet/` are `cp -L` of those bytes, read-only, so the hashes above are
the ones to compare after any rebuild.

## Projection audit

Twelve terms ranked from the description, strongest first: **security** (18.349),
**engineering** (16.724), **artifact** (14.67), **systems** (14.67), **securing**
(13.019), **engineers** (11.866).

The scorer read this posting as a security-and-build-artifact role, which is what the
description emphasises: supply-chain integrity, artifact provenance, release gates,
securing the pipeline. That is a better fit than the raw highlight count suggests.

- **Highlights: 11 of 32** — Bountystash 3/10, O3 Energy 3/8, Smart Energy 360 1/4,
  Fraunhofer ISE 2/4, Halliburton 2/6.
- **Projects: 4 of 10** — `Risk Calculation Engine (Swirl Engine)`, `Master's Thesis`,
  `nixconfig`, `kev-time`. `nixconfig` surviving is what this packet needs: it is the
  CI/CD and supply-chain evidence, and `kev-time` is the vulnerability pipeline that
  supports the "security as continuous work" argument.
- **Skills:** Security 6/6, DevOps 5/5, Backend & Database 6/6, Web 6/7, Energy & Risk
  6/8, Programming Languages 6/10 (C, C++, Bash and Nim dropped).

The CV is lean — 11 kept lines across five employers — so the letter carries the
pipeline mechanics the rows cannot: pinned inputs, hermetic builds, gates with builders
off, the OOM-guarded sweep, single-writer deploys.

Measured on the rendered PDFs, not the source:

| Term | CV | Letter |
| :--- | :--- | :--- |
| Buildkite | 0 | 1 (named gap) |
| Argo CD | 0 | 1 (named gap) |
| Kubernetes | 1 | 1 (named gap) |
| Nix | 5 | 1 |
| provenance | 0 | 1 |
| supply chain | 0 | 2 |

## Alignment and honest gaps

Matches, all inspectable in this repo:

- **Gates that read the artifact back.** A change counts only once a check has inspected
  the built output; gates shell out with `--builders ""` so a check cannot spend the
  build budget it protects. That is the "release gates without becoming a tax on
  velocity" thesis, at fleet scale rather than org scale.
- **Hermetic, pinned builds.** Every input pinned, the flake lock is the supply-chain
  boundary, self-hosted submodules are pinned per host path so a path cannot refetch
  different code.
- **Supply-chain hygiene.** SOPS/age secrets per host from the host's SSH key, an SSH
  certificate authority instead of shared user keys, default-deny nftables, KEV-driven
  patching ordered by exposure and effort.
- **Single-writer release discipline.** One host per process, no fleet-wide default,
  plan before apply, rollback documented per host.
- **Incident response that produces structural change.** Sentinel ledger every fifteen
  minutes, gatus paging on `state != ok`, and each incident turned into a check, a note
  or a policy rather than a story.
- **AI as an operating layer**, not a talking point: coding agents run the change loop,
  the gates and the coordination log on this fleet.

Gaps, all named in the letter:

1. **No Buildkite, no Argo CD, no production Kubernetes.** GitOps here is a flake and a
   task interface, not a controller watching a cluster; isolation is a CA and a module
   boundary, not namespaces and quotas.
2. **No org-wide policy layer.** The guarantees exist on thirteen hosts, not across
   hundreds of engineers who never read them. This is the gap between senior and
   principal scope, and the letter concedes it.
3. **No people management.** Instruction and design review, yes; directing a team
   through multi-quarter goals, no.
4. **Poland req, Germany residence** — see the country question above.
5. **No AWS, GCP or Azure depth** in the corpus; the fleet is owned hardware.
6. **No Elasticsearch, Kibana or observability-vendor experience.** Elastic runs its own
   stack; the observability story here is self-built.

## Compensation

The band is published in PLN: **369,400–584,300**, base only. At roughly 4.3 PLN/EUR
that is about **EUR 86,000–136,000**, but the band is denominated in złoty, so the euro
equivalent moves with FX and with the Polish entity's own benchmarking.

Guidance for submit time: do not open with a number; if a field requires one, answer in
PLN at the **upper half of the band** (the candidate's own floor is EUR 95,000, and the
band's midpoint clears it), and say that a Germany contract would need to be priced
against the German market rather than converted.

## Submit-time checklist

- Form fields are **unknown**: no browser form was opened for this packet, by
  instruction. Read them live before answering anything.
- If a work-authorization question appears, the answer is German permanent residence,
  unrestricted in Germany; a Polish contract would need its own permit check, so do not
  answer "EU work authorization" loosely.
- Salary answers in PLN, not converted euros.
- Attach `packet/lebenslauf.pdf`; the letter has no dedicated upload field on most
  Greenhouse forms, so its content would go to a free-text field if one exists.

## Next action

Review the packet. Then decide the country question — apply to the Poland req from
Germany, wait for a Germany sibling req, or ask the recruiter first — and only then
submit. Nothing has been sent and no form has been opened.
