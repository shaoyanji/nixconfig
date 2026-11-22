# Elastic — Principal Software Engineer I, CI/CD (Platform Engineering Productivity)

Greenhouse **8267186** · https://jobs.elastic.co/jobs?gh_jid=8267186 · Poland (band in PLN; sibling reqs for IE, PT, ES, none for
Germany). Base **369,400–584,300 PLN**, no variable component.

**Submitted 22.11.2026** per the apps DB. Packet is retrospective — do not resubmit under this id.

Native English Typst rebuild, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1205 | 0 | `bb00f5cfc66c04ff` |
| `anschreiben.pdf` | 1 | 518 | 0 | `4269d38e40e0fda5` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, `lead.md`, this sheet. Retired in this rebuild: the `packet/` directory
(Nix-projected PDFs plus `selection.json`) and `letter.json` — the letter now has one source, `anschreiben.typ`.

## What changed

The submitted CV was the leanest projection of the database: 547 words over two pages, eleven kept lines across five employers, with
the pipeline mechanics living only in the letter. On a role whose screening is CI/CD and supply-chain, a CV with no gates, no pinned
inputs and no provenance reads as a generic systems profile. The native CV opens on the exact rule that matters — *a change is not
finished until a gate has read the built artefact back* — then states the hermetic construction (pinned inputs, Nix sandbox, gates
with builders off, OOM-guarded sweeps one host per process, single-writer deploys, dry plan before apply), then the supply-chain work
(sops per host with an age key cut from the SSH key, own certificate authority, submodule pins per host path, KEV-driven patching by
exposure, content-addressed store paths as provenance).

It also carried the standard unsupported stack; that is gone. Submitted bytes: `packet/lebenslauf.pdf` `dd1fadca9b12cf61…` (2 pages,
547 words), `packet/anschreiben.pdf` `2a0c46b6f5aa1f85…` (1 page, 530 words). The letter substance survived the rebuild almost intact —
it was already honest, and only the address block, the date and the closing ask were tightened.

## Where the stack words sit

Buildkite, Argo CD and Kubernetes appear in the CV **not at all**, and in the letter only inside the sentence saying they are not part of
my history. Nothing is claimed.

## The two questions this packet cannot answer

1. **Country.** The req is Poland. The candidate is in Germany with permanent residence and needs no German permit — but a Polish
   contract is a different entity, and if the role is office-based it is a relocation. No German sibling req exists. The letter asks
   whether a Germany contract exists rather than assuming; the answer is the operator's.
2. **Level.** Principal I is org-wide scope: multi-quarter cross-org ownership and directing engineers. The packet does not inflate a
   thirteen-host fleet into a team — it says standards and design review were adopted voluntarily, and that managing engineers with
   quarterly goals is not in the history. Expect the level conversation to be the real interview.

## Fit

**4 of 5** on substance, **2 of 5** on the org-scale scope the level implies. Strong: release gates that read artefacts back, hermetic
builds, supply-chain hygiene, incident discipline that ends in structural change, AI as an operating layer rather than a talking point.
Gaps: no org-wide policy layer, no people management, no Buildkite/Argo CD/production Kubernetes, no Elasticsearch or observability-vendor
work, no cloud depth (owned hardware).

## Compensation

Band published in PLN and denominated there, so the euro equivalent moves with FX. Guidance: do not open with a number; if a field
demands one, answer in PLN in the upper half of the band — the candidate's floor of EUR 95,000 sits above the band's midpoint — and say
a Germany contract would be priced against the German market rather than converted.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| Unsupported claims | 0 outside the negation paragraph |
| `task checks:prose` | exit 0 |
| Commit | native rebuild; `packet/` and `letter.json` removed in the same commit |
