# GoCardless (a Mollie company) — Senior Site Reliability Engineer (Database Focus)

**Status: packet built 2026-11-22, NOT submitted.** No browser opened, no form read, no
account created. The record stays at stage `prep`.

GoCardless is a bank-payments company (Direct Debit, real-time payments, open banking),
now part of Mollie, processing US$130bn+ a year across 30+ countries. The Platform
Engineering team is distributed across London, Riga and Lisbon and this role owns the
database estate: self-managed Stolon clusters plus a GCP Cloud SQL fleet, with a
consolidation and re-platforming job in progress.

## Role

| Field | Value |
| :--- | :--- |
| Company | GoCardless (a Mollie company) |
| Role | Senior Site Reliability Engineer (Database Focus) |
| Greenhouse req | `8385160` |
| Apply URL | https://job-boards.greenhouse.io/gocardless/jobs/8385160 |
| Board | `gocardless` |
| Team | Platform Engineering — London, Riga, Lisbon |
| Location | Hybrid/office in those cities; no remote-from-Germany variant stated |
| Compensation | EUR 76,000–114,000 base (band set in EUR) |
| Language | English |
| Pipeline record | `gocardless-senior-sre-database`, stage `prep`, fit unset |
| Folder | `submissions/gocardless-senior-sre-database/` |

## Location — and why this one is more serious than the last two

The team is in London, Riga and Lisbon. The candidate is in Germany, US citizen with
German permanent residence.

- **Germany is not one of the three locations**, so remote from Germany is a question for
  the recruiter, not an assumption. The letter asks it.
- **A UK-based contract is not available to this candidate.** UK right to work requires a
  visa he does not hold; German permanent residence does not extend to the UK. Do not let
  any form answer imply otherwise.
- **Lisbon would need a Portuguese permit**, a relocation, and a new residence
  arrangement — the German permanent residence is the asset worth keeping.
- The only clean version of this role is remote-from-Germany on a German or EU entity, or
  a Lisbon relocation the candidate has not agreed to. That decision is the operator's.

## Compensation — the band is a trap, not a gift

Published: **EUR 76,000–114,000**. The posting then states the policy plainly: *"our
approach is to pay between the minimum and the mid-point of the pay range until
performance can be assessed in role."* The midpoint is **EUR 95,000**, which is exactly
the candidate's own floor and well below what the other packets target.

So the realistic offer sits at or under EUR 95,000, and a strong interview may not move it
because the policy caps it. If this application proceeds, ask for the midpoint plus a
written review date, and treat the top of the band as unavailable at hire rather than as
negotiating room.

## Files in `submissions/gocardless-senior-sre-database/`

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | 2 pages, sha256 `52b7a1a54e4ee44c8812577f9e95436c790dfdc59da92e59e195d5ba57d6ba30` |
| `packet/anschreiben.pdf` | 1 page English, sha256 `9eae0526a88d8b4e2b9d2fb7fe41ae3138171f02dc35d732312a2a2d7376b258` |
| `packet/selection.json` | Projection audit, kept and dropped lines with scores |
| `letter.json` | Letter source, so the PDF reproduces from this tree |
| `job-description.txt` | Posting text as given (no header block) |
| `lead.md` | The originating lead |
| `submission-sheet.md` | This sheet |

Built with:

```
task agents:apps:packet ID=gocardless-senior-sre-database \
  JD=submissions/gocardless-senior-sre-database/job-description.txt \
  LETTER=submissions/gocardless-senior-sre-database/letter.json \
  OUT=/tmp/gocardless-packet
```

Compiled in the Nix sandbox on `eu.nixbuild.net`; the artifact is
`/nix/store/kd2rq5jvc97yh5jf20pm48l1yy8yy94r-appflow-packet-gocardless-senior-sre-database`.
The copies in `packet/` are `cp -L` of those bytes, read-only.

## Projection audit

Twelve terms ranked from the description, strongest first: **cloud** (22.609),
**database** (22.609), **postgresql** (18.183), **engineering** (16.724), **postgres**
(16.137), **databases** (15.97).

The scorer read this posting as a cloud-database role, which is right, but it produced the
leanest CV of the packets so far.

- **Highlights: 10 of 32** — Bountystash 2/10, O3 Energy 2/8, Smart Energy 360 1/4,
  Fraunhofer ISE 3/4, Halliburton 2/6.
- **Projects: 4 of 10** — `Postgraduate Renewable Energy`, `nixconfig`, `kev-time`,
  `Vulnerability operations concept`.
- **The projection dropped the one project that matters most for this JD**: `bountystash`,
  the mail archive built on PostgreSQL, is not in the kept four. The Postgres evidence
  therefore survives only in the letter and in whatever work highlight the scorer kept at
  Bountystash. That is a selection artefact, exactly like the flix packet, and worth fixing
  in the corpus rather than in this packet: a project descriptor that names PostgreSQL,
  migrations and restores would score.
- **Skills:** Backend & Database 6/6, DevOps 5/5, Security 6/6, Web 6/7, Energy & Risk 6/8,
  Programming Languages 6/10.

Measured on the rendered PDFs, not the source:

| Term | CV | Letter |
| :--- | :--- | :--- |
| PostgreSQL | 1 | 2 |
| Stolon | 0 | 1 |
| PgBouncer | 0 | 0 |
| Cloud SQL | 0 | 1 |
| Terraform | 0 | 1 |
| Kubernetes | 1 | 0 |
| Grafana | 0 | 1 |
| Nix | 4 | 1 |
| failover | 0 | 1 |
| replication | 0 | 1 |

## Alignment and honest gaps

Matches, all inspectable in this repo:

- **A production PostgreSQL instance with a recovery path.** The mail archive runs on
  Postgres with versioned migrations, a rehearsed restore, statement timeouts and
  disk-pressure alerting. One instance, owned end to end, which is the smallest honest
  version of "keep the database healthy".
- **Query and capacity habits.** Plans read before indexes are added, idle-in-transaction
  sessions chased, autovacuum lag watched, connection limits reasoned about rather than
  guessed.
- **On-call that had to be honest.** A sentinel writes job status, generation age, disk and
  pressure-stall figures every fifteen minutes; gatus pages on any state that is not ok.
  Solo on-call with no noise budget is the closest thing here to a payments on-call.
- **Infrastructure as code and change discipline.** Pinned inputs, hermetic builds, gates
  that read the artifact back, single-writer deploys, plan before apply — the habit that
  transfers to Terraform even though the tool does not.
- **Security and audit-adjacent work.** SOPS/age secrets per host, an SSH certificate
  authority, default-deny nftables, KEV-driven patching ordered by exposure.
- **Go and Python services** in production; Ruby is not in the corpus.

Gaps, all named in the letter:

1. **The specialty bar is not met.** Five-plus years running production PostgreSQL with
   HA, replication, failover and major-version upgrades: the corpus has one production
   instance, no replication topology, and no upgrade led. This is the central miss and no
   framing hides it.
2. **No Stolon, no Cloud SQL, no PgBouncer in production.** Pooling and HA are concepts
   here, not operated systems.
3. **No Terraform, Atlantis, GKE or Argo CD.** Nix is the infrastructure language; GitOps
   is a flake and a task interface.
4. **No Grafana, Prometheus or Datadog.** Observability is a self-built ledger plus gatus.
5. **Scale is not payments scale.** Thirteen hosts and a mail archive, not a fleet of
   payment databases under 130bn a year.
6. **Location and right to work** — see above; the UK is not open without a visa.

## Submit-time checklist

- Form fields unknown: no browser form was opened, by instruction.
- Never answer a UK right-to-work question positively. The truthful answer is German
  permanent residence, no UK visa.
- If a location field forces a choice among London, Riga and Lisbon, stop: that is the
  operator's decision, not a form-filling exercise.
- Salary: midpoint EUR 95,000 plus a written review date; the band's upper half is
  unlikely at hire under their stated policy.
- Attach `packet/lebenslauf.pdf`; letters rarely have an upload field on Greenhouse.

## Next action

Review the packet. Then settle the location question — remote from Germany, or not at all —
before touching the form. Nothing has been sent.
