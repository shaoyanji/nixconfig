# ScorePlay — Senior Platform Engineer (SRE), Western Europe Remote

**Status: prepared, NOT submitted.** 2026-11-22. Nothing sent, no Ashby application started.

ScorePlay is AI-powered media infrastructure for sports — 350+ leagues, teams and
broadcasters, 15+ PB of media, 145M+ minutes of video ingested per month, 65 people,
$20M+ raised. The Platform team is one person today, the founding SRE (Maxime Renou);
this role is the second, reporting to the Head of Engineering and owning half the
roadmap end to end.

## Role

| Field | Value |
| :--- | :--- |
| Company | ScorePlay |
| Role | Senior Platform Engineer (SRE) |
| Ashby job id | `42f1911f-68d4-4a9f-8d9e-e3a7939ceb96` |
| Apply URL | https://jobs.ashbyhq.com/scoreplay/42f1911f-68d4-4a9f-8d9e-e3a7939ceb96 |
| Department / type | Engineering / FullTime |
| Location | Western Europe — Remote (Ashby `isRemote: true`, address country `European Union`) |
| Published | 2026-08-17 (Ashby posting API) |
| Compensation | €90,000–110,000 salary + €150,000 equity cash value, per year |
| Language | `en` |
| Pipeline record | `scoreplay-senior-platform-engineer-sre` (category `tech`, fit 3) |
| Folder | `submissions/scoreplay/` |

## Location and remote — what the posting settles

This is a **remote** role, not a hybrid one: Ashby reports `workplaceType: Remote`,
`isRemote: true`, and a postal address only at the country level (European Union).
The description adds "remote-first with regular team gatherings, an international
team spread across Europe and the US", and the role is explicitly Western Europe.

For this candidate that removes the hardest constraint of the other packets:

- **No relocation and no permit.** He is in Gutach im Breisgau, Germany, holds
  German permanent residence and works there without restriction. Germany is
  inside "Western Europe", so the location requirement is satisfied as-is.
- **CET is inside their spread.** The team spans Europe and the US; a shared
  on-call rotation across those timezones should be confirmed at first call,
  together with how pager hours are compensated.
- **Gatherings mean travel.** "Regular team gatherings" is the only travel
  commitment the posting names; ask for the cadence before accepting.

## Compensation — the band against the floor

The posting publishes one tier: €90,000–110,000 salary plus €150,000
`EquityCashValue` per year (Ashby's own classification — a paper value for equity,
not cash). The candidate's floor is €95,000, so **the published band overlaps the
floor only from €95,000 upward**; the bottom €5,000 of their range is below it.

Read that as: apply, target €103,000–110,000 on the strength of the builder brief
and 6+ years' equivalent, and do not volunteer a number first. The second-platform-hire
scope and a one-person team justify the top of the band, not a discount. Ask separately how the
€150,000 equity value is struck (instrument, vesting, refresh), because a
"cash value" figure is a valuation, not an offer of cash.

## Files in `submissions/scoreplay/`

- `packet/lebenslauf.pdf` — 2 pages, projected from the JD: 10/32 highlights, 4/10 projects
- `packet/anschreiben.pdf` — 1 page, English letter (`letter.json`)
- `packet/selection.json` — the projection audit, kept and dropped with scores
- `letter.json` — letter source, so the PDF is reproducible from this tree
- `job-description.txt` — full posting text from the Ashby API plus a provenance footer
- `submission-sheet.md` — this sheet

Built with `task agents:apps:packet ID=scoreplay-senior-platform-engineer-sre
LETTER=… JD=…`, which compiles in the Nix sandbox and runs `cv-ats-check.sh`
against the finished PDFs. Build passed at 2 / 1 pages with no budget violation.
Note the id trap: `ID=scoreplay` fails with `no application scoreplay` — the task
keys off the pipeline record, not the folder name.

## Projection audit

Twelve terms ranked from the description, strongest first: **event** (22.609),
**streaming** (20.676), **storage** (20.646), **security** (18.349), **aws**
(18.183), **event-driven** (18.183), **kubernetes** (18.183), then `next`.

That ranking explains the shape of this CV and why it differs from the MongoDB one:

- Highlights kept 10 of 32 — Bountystash 2/10, O3 Energy 2/8, Smart Energy 360 2/4,
  Fraunhofer ISE 2/4, Halliburton 2/6. Every employer kept exactly two, which is
  the budget's cap reached five times: the JD's storage and event vocabulary
  matched broadly rather than concentrating in one job.
- Projects kept 4 of 10 — `nixconfig`, `bountystash`, `kev-time`, `Vulnerability
  operations concept`. **`bountystash` survives here**, unlike the MongoDB packet,
  because storage and event terms reach the media archive and its services.
  Dropped: Risk Calculation Engine, fibtransponder, matt.bountystash.com,
  kelly-svg, Postgraduate Renewable Energy, Master's Thesis.

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
| Work authorization | Unrestricted in Germany; no permit needed for this role |
| Languages | German C1; English native |

## Alignment & Honest Gaps

Strengths, all built and inspectable in this repo:

- **On-call and observability ownership.** A sentinel writes job status, generation
  age, disk and PSI to a ledger every 15 minutes and pages when a state is not ok;
  failures leave a record instead of a shrug. That is the same thesis as the
  posting's on-call section — shared pager, postmortems with numbers attached,
  alert-noise reduction as roadmap work rather than between-tickets work.
- **Infrastructure as code, reviewed like product code.** One flake declares 13
  NixOS hosts with per-host module chains, an SSH CA, SOPS/age secrets and a task
  control plane as the only operator surface; a change counts only once a gate has
  read the built artifact back.
- **Security as continuous work.** No shared user keys, key rotation via a task,
  and a vulnerability programme built from CISA's KEV catalogue that orders patching
  by exposure and effort — the SOC 2 posture the posting describes keeping, not
  sprinting for. Not a compliance auditor's CV: the security is operated.
- **Platform as a product for engineers.** The task interface exists so other
  engineers (and agents) never need to ask for a host, which is the "Platform from
  bottleneck to enabler" section in practice.
- **Cost as an architectural problem.** Solar/grid economics and a €100M+ portfolio
  background, plus a self-hosted fleet where every byte of egress is visible.

Gaps, all named in the letter rather than left for the interview:

1. **No production Kubernetes.** The word appears once on the built CV, as a skills
   keyword. Hosts are single-tenant and role-separated; isolation is a CA and a
   module boundary, not namespaces, quotas and network policy. The scheduler is
   new ground.
2. **No Terraform, Terragrunt or Helm — at all.** Infrastructure-as-code is Nix,
   which reconciles a whole machine from declared state, so the model transfers but
   the tools do not. `Terraform`, `Terragrunt`, `Helm` each appear 0 times in the
   rendered PDF.
3. **No Kafka, no Temporal.** Event streaming is not in the fleet; the CV shows
   nothing here and the letter says so.
4. **Not 15 PB, not multi-region AWS.** Storage work is a NAS taxonomy, restic
   backups and media-tree isolation; AWS in the history is instances, not an
   architecture. Measured on the PDF: `storage` 1, `AWS` 1, `multi-region` 0,
   `event-driven` 0, `SLO` 0, `on-call` 0, `SOC 2` 0.
5. **Platform team of one.** The posting's bonus is "among the first platform hires
   somewhere" — this is the closest genuine match (a fleet built alone, from
   nothing), and it should be argued in the interview, not just asserted.

## What this CV does and does not say

The CV carries **Go five times**, `Kubernetes` once, `AWS` once, `PostgreSQL` once,
`storage` once — and zero for Linux, Terraform, Helm, Kafka, Temporal, OpenSearch,
SLO, on-call, SOC 2, multi-region and event-driven. The letter therefore carries the
on-call discipline, the isolation argument, the security-continuous posture and the
cost reasoning; the CV cannot. If this application goes forward, the fastest real
improvement to the corpus is a Kubernetes and Terraform line backed by something
actually run, not a keyword.

## Application (Ashby) and Next Action

The Ashby posting API publishes the job but not the application questions — the form
is rendered client-side, so the exact question set is unknown until the apply page is
opened. Expect at minimum name, email, résumé upload, LinkedIn, and almost certainly
a location/authorization question (answer: Germany, no sponsorship needed, remote
fine) and a compensation expectation (do not go below €95,000; aim €103,000–110,000).

**Next action:** review this packet, then submit on Ashby at the apply URL above.
Until then the record stays at stage `prep` and nothing is sent.
