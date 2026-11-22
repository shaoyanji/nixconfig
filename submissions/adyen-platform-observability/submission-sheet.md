# Adyen — Senior Platform Engineer - Observability (Amsterdam)

**Status: prepared, NOT submitted.** 2026-11-22. Nothing sent, no account created.

Adyen's Platform Engineering organisation runs the logging, metrics and tracing
pillars that hundreds of product teams monitor their services on: petabytes of
telemetry, 1,500+ servers across bare metal and Kubernetes, on-prem and in the
cloud. The role is a builder's role inside a platform transformation — automate
operations, make self-service safe, and engineer alerts out of existence rather
than answering them.

## Role

| Field | Value |
| :--- | :--- |
| Company | Adyen |
| Role | Senior Platform Engineer - Observability |
| Greenhouse req | `7607691` |
| Apply URL | https://job-boards.greenhouse.io/adyen/jobs/7607691 |
| Board | `adyen` (Greenhouse) |
| Location | Amsterdam — office-first, explicitly **no remote-only** |
| Language | `en` |
| Compensation | not published in the posting |
| Pipeline record | `adyen-platform-observability` (stage `other`, fit unset) |
| Folder | `submissions/adyen-platform-observability/` |

## Location — office-first Amsterdam, and what it costs

The posting closes with the constraint that decides this application: *"This role
is based out of our Amsterdam office. We are an office-first company and value
in-person collaboration; we do not offer remote-only roles."* There is no hybrid
allowance stated and no remote variant, so Amsterdam is a move, not a commute.

- **Relocation is required.** The candidate is in Gutach im Breisgau, Germany —
  roughly 700 km from Amsterdam. This is not a weekly-commute situation dressed up
  as hybrid; it is a relocation, and the letter says so in its own paragraph.
- **Permit needed.** He is a US citizen with German permanent residence, and that
  residence does not transfer to the Netherlands. The Dutch route is a
  highly-skilled-migrant (*kennismigrant*) permit, which requires a recognised
  sponsor; Adyen's sponsor status should be confirmed at first call rather than
  assumed. Salary thresholds for that route also apply — worth confirming the band
  clears the 30+ threshold.
- **What makes it feasible:** Adyen sponsors and relocates for platform roles
  routinely, the language of the office is English, and the candidate's German C1
  makes the move socially easy. The honest risk is timing, not willingness.
- **No published band.** Unlike ScorePlay, Adyen publishes nothing here, so there
  is no floor comparison to make in advance. Do not volunteer a number first; the
  candidate's floor is €95,000.

## Files in `submissions/adyen-platform-observability/`

- `packet/lebenslauf.pdf` — 2 pages, projected from the JD: **13/32** highlights, 4/10 projects
- `packet/anschreiben.pdf` — 1 page, English letter (`letter.json`)
- `packet/selection.json` — the projection audit, kept and dropped with scores
- `letter.json` — letter source, so the PDF is reproducible from this tree
- `job-description.txt` — the posting, as scraped
- `lead.md` — the original lead record
- `submission-sheet.md` — this sheet

Built with `task agents:apps:packet ID=adyen-platform-observability LETTER=…
JD=…`, which compiles in the Nix sandbox and runs `cv-ats-check.sh` against the
finished PDFs. Build passed at 2 / 1 pages with no budget violation.

## Projection audit

Twelve terms ranked from the description, strongest first: **kubernetes** (22.609),
**systems** (20.676), **engineering** (16.724), **data** (15.97), then `next` and
`system`. Notably absent from the top: any of the telemetry product names — the
scorer reads the prose, and the prose talks about "systems" and "data" more than
about Elasticsearch.

- **Highlights: 13 of 32** — the most of any packet in this tree (MongoDB 10,
  ScorePlay 10). Bountystash 4/10, O3 Energy 2/8, Smart Energy 360 2/4,
  Fraunhofer ISE 3/4, Halliburton 2/6. Four highlights at Bountystash means the
  platform and systems lines genuinely match, not just the generic engineering prose.
- **Projects: 4 of 10** — `Risk Calculation Engine (Swirl Engine)`, `nixconfig`,
  `bountystash`, `Vulnerability operations concept`. Dropped: `kev-time`,
  `fibtransponder`, `Master's Thesis`, `matt.bountystash.com`, `kelly-svg`,
  `Postgraduate Renewable Energy`. Swirl Engine displacing `kev-time` is the
  scorer preferring "systems/engineering/data" over security vocabulary.

## Candidate Facts — Grounded Truth

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Baden-Württemberg, Germany |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| LinkedIn | https://linkedin.com/in/mattji |
| GitHub | https://github.com/shaoyanji |
| Website | https://www.bountystash.com |
| Citizenship | United States |
| Residence | German permanent residence (*unbefristete Niederlassungserlaubnis*) |
| Work authorization | Unrestricted in Germany. Netherlands: sponsored permit required |
| Languages | German C1; English native |

## Alignment & Honest Gaps

Strengths that map onto this JD more directly than onto either previous packet:

- **The observability loop, run for real.** A sentinel writes job status, generation
  age, disk and pressure-stall figures to a ledger every 15 minutes and pages only
  when a state is not ok. That is the JD's "primary focus will be engineering
  solutions that stop alerts from firing in the first place", at 13 hosts instead of
  1,500 — the same feedback loop, smaller blast radius.
- **PSI as a first-class signal.** Pressure stall information is a kernel-level
  saturation signal, not an application metric; using it to page means the alerting
  is built on the resource contention that actually precedes failure. This is the
  closest thing in the corpus to the JD's "understand the operating system at a
  kernel level".
- **Change safety through gates.** A change counts only once a gate has read the
  built artifact back, which is the "CI pipelines that make cluster changes safe
  and predictable" requirement expressed as a platform invariant.
- **Go and Python tooling, not scripts.** Go appears **9 times** on the rendered CV,
  Python twice — the strongest language showing of any packet here.
- **Isolation without a cluster.** An SSH certificate authority, per-host keys, no
  shared user credentials and a module boundary between roles: the same tenant-noise
  problem the JD calls out, solved with different primitives.

Gaps, all conceded in the letter:

1. **No production Kubernetes.** `Kubernetes` appears once on the CV, as a skill
   keyword; `kubectl`, StatefulSets, Ingress and quota guardrails are reading, not
   operating. This is the JD's explicit "proven hands-on experience" requirement.
2. **No telemetry stores operated.** Measured on the rendered PDF: Elasticsearch 0,
   OpenSearch 0, Prometheus 0, VictoriaMetrics 0, Grafana 0, Tempo 0,
   OpenTelemetry 0. The metrics store he knows is one he wrote himself.
3. **Scale.** 13 hosts on owned hardware, not 1,500 across bare metal and cloud
   regions; no petabyte telemetry, no multi-region data-isolation work.
4. **Ten years, but not ten years of observability.** The JD asks for 10+ years in
   the domain or a relevant platform domain; the CV shows ten years across energy
   and software, which is defensible under "relevant platform" but should not be
   stretched into "a decade of observability".
5. **Formal on-call rotation.** The pager exists and is answered, but there is no
   team rotation to point at — one operator, self-paged.

## What this CV does and does not say

`Go` 9, `Python` 2, `Kubernetes` 1, `AWS` 1 — and zero for Linux, kubectl,
Elasticsearch, Prometheus, VictoriaMetrics, Grafana, Tempo, OpenTelemetry,
Terraform, Helm, PSI, on-call and SLO. The CV cannot carry this role's stack, and
the sheet will not pretend otherwise; the letter carries the closed-loop reasoning,
the kernel-signal alerting and the gate discipline, which are the transferable half.

## Next Action

The Greenhouse form's question set was not fetched for this packet (Ashby-style
client-rendered questions are not the issue here — Adyen's board form is simple),
so read the fields at submit time and expect at minimum name, email, CV upload,
cover letter and a work-authorization question. Answer the authorization question
as **sponsorship required (Netherlands)**; do not imply existing EU-wide rights.

**Next action:** review this packet, confirm Adyen's recognised-sponsor status and the
kennismigrant salary threshold during the first call, then submit on Greenhouse.
Until then the record stays at stage `prep` and nothing is sent.
