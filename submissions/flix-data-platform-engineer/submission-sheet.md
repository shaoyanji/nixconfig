# Flix — Data Platform Engineer (m/f/d), Berlin

**Status: applied 2026-11-22.** Submitted through the Greenhouse form embedded on
`flix.careers`; confirmed by the `job-success` page and the receipt email below.

Flix is the long-distance bus and train platform (FlixBus, FlixTrain, Greyhound); FlixTech
is its engineering organisation. The data platform team enables network planning,
pricing, operations and business analytics on mobility data, at millions of daily
events. The posting says the team is cross-functional with analysts, scientists and
platform engineers, and that this role owns features end to end, including on-call.

## Role

| Field | Value |
| :--- | :--- |
| Company | Flix (FlixTech) |
| Role | Data Platform Engineer (m/f/d) |
| Greenhouse req | `8690650002` |
| Apply URL | https://flix.careers/job/8690650002?gh_jid=8690650002 |
| Location | Berlin — office-first hybrid |
| Language | English |
| Compensation | Not published in the posting |
| Pipeline record | `flix-data-platform-engineer` (category `other`) |
| Folder | `submissions/flix-data-platform-engineer/` |

## Submission

| Field | Value |
| :--- | :--- |
| Submitted | 2026-11-22, 06:03 CET (05:03 UTC) |
| Confirmation page | `https://flix.careers/job-success` — "Thanks for applying, we'll keep you on track." |
| Receipt email | `Flix // Your candidacy`, `no-reply@flixbus.com` → `matt@bountystash.com`, 22 Nov 2026 05:03 UTC |
| Reference code | none issued; Greenhouse sent no security code and no candidate portal was opened |
| Document sent | `packet/lebenslauf.pdf` (2 pages, sha256 `66068134b75bd5f43534542ab83f8b047f47bd18f2cc21d675b1c1109a80e8f4`) |

Exact answers submitted:

| Form field | Answer |
| :--- | :--- |
| First / last name | Matt / Ji |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| Which of these do you have experience with: Kafka, Snowflake, Terraform? | None of the three in production; Nix rather than Terraform, a Postgres ledger and systemd journals rather than Kafka, no warehouse. Named as new tools, with the smaller equivalents built. |
| Salary expectation (gross per year) | EUR 103,000-110,000, target EUR 105,000 depending on scope |
| Earliest start | Immediately, available at short notice (matches `lib/matt/profile.de.json`) |
| Legal right to work? | Yes — German permanent residence |
| Based in Berlin / open to relocate? | Yes — would relocate for the office-first model, as the letter states |
| Open to on-call? | Yes |
| Privacy policy | Accepted (required) |

The letter was **not** uploaded: this form has no cover-letter field, only the three
free-text questions above. The salutation, relocation paragraph and gap list therefore
never reached the recruiter — the answers carry the same facts in shorter form.

## Location and hybrid — the question this packet had to answer

The posting is unambiguous about the model: "Hybrid work model: We are an office-first
company, but we offer flexibility to balance work and life", plus "Work from
(M)Anywhere: Depending on your role, work from another location for up to 60 days per
year." The 60 days are a travel allowance, not a remote arrangement.

The candidate lives in **Gutach im Breisgau**, in south-west Germany near Freiburg —
roughly 700 km and seven hours by train from Berlin. There is no reading of
"office-first" under which that is a commutable home base, so the letter says so in
its own paragraph instead of claiming flexibility:

- **Relocation, not remote.** Moving to Berlin is a domestic move. He holds German
  permanent residence (*unbefristete Niederlassungserlaubnis*) and works in Germany
  without restriction, so no permit, no sponsorship and no visa timeline is involved —
  unlike the Dublin and Amsterdam packets, this one carries no immigration risk.
- **The honest constraint is willingness and timing, not paperwork.** The letter states
  he would relocate rather than ask for a remote exception. That is a commitment worth
  confirming with him before anything is sent.
- **Ask at first call:** hybrid days per week expected, whether relocation support
  exists for a domestic move, and whether the 60-day "(M)Anywhere" allowance is
  available to this role.

## Compensation

The posting publishes no band, so there is nothing to measure against the €95,000
floor. Default from the other packets: do not volunteer a number first; if a form or
recruiter requires one, target **€103,000–110,000**.

## Projection audit

Twelve terms ranked from the description: **data** (23.137), then **aws**,
**kubernetes** and **streaming** (14.67 each), **mobility** (13.019), **engineering**
(11.866), **analysts** (10.985), and `cloud`, `even`, `events`, `network`, `networking`
(8.664 each).

That vocabulary lands on the corpus badly, and the audit shows it: **5 of 32
highlights kept — exactly one per employer, the budget minimum reached five times** —
and 4 of 10 projects.

- Kept: one line each at Bountystash, O3 Energy, Smart Energy 360, Fraunhofer ISE and
  Halliburton. The single-kept lines are the infrastructure and tooling ones; the risk
  and energy-trading lines scored low because the posting never mentions energy.
- Projects kept: `Risk Calculation Engine (Swirl Engine)`, `Master's Thesis`,
  `nixconfig`, `Vulnerability operations concept`. **`bountystash` and `kev-time`
  were dropped** — the mails/services archive and the KEV pipeline are the closest
  things in the corpus to a data platform, and the scorer preferred the risk engine.
  That is a selection artefact, not a judgement about the work.
- Skills: Backend & Database 6/6 and DevOps 5/5 kept; Programming Languages 6/10 (C,
  C++, Bash and Nim dropped); Web 6/7; Energy & Risk 6/8.

The practical consequence: this is the leanest CV of the packets built so far
(ScorePlay kept 10/32). It fits two pages comfortably, and the letter therefore carries
the platform, on-call and observability argument that the CV rows are too sparse to
make. If the corpus gains a Kubernetes or Terraform line backed by something actually
run, this is the packet that benefits most.

## What the finished documents say

Measured on the rendered PDFs, not the source:

| Term | CV | Letter |
| :--- | :--- | :--- |
| Go | 8 | — |
| Nix | 5 | — |
| SQL | 3 | — |
| Python | 2 | 1 |
| Kubernetes | 1 | 1 (as a named gap) |
| AWS | 1 | — |
| Postgres | 1 | 1 |
| `pipeline` | 2 | — |
| Terraform | 0 | 1 (as a named gap) |
| Kafka | 0 | 1 (as a named gap) |
| Snowflake | 0 | 1 (as a named gap) |
| Datadog | 0 | 1 (as a named gap) |
| Spark / Airflow / dbt / Docker | 0 | 0 |

## Alignment & honest gaps

Real matches, all inspectable in this repo:

- **Platform as a product for other engineers.** Thirteen hosts, one flake, and a task
  interface as the only operator surface, so nobody has to ask for a host — the same
  thesis as "enabling other teams to work efficiently with data".
- **Reliability recorded rather than assumed.** A sentinel writes job status, generation
  age, disk and pressure-stall figures to a ledger every fifteen minutes and pages when
  a state is not ok; gatus pages on `state != ok`. On-call is his own pager, which is the
  part of this role most people underweight.
- **Infrastructure as code, reviewed and gated.** SSH certificate authority,
  SOPS/age secrets per host, module chains per host; a change counts only once a gate has
  read the built artifact back. The habit transfers to Terraform and GitLab CI even
  though the tool does not.
- **Security as continuous work.** CISA KEV-driven patching ordered by exposure and
  effort, key rotation by task, no shared user keys.
- **Python and Go services in production**, including a PostgreSQL-backed mail archive.

Gaps, all stated in the letter rather than left for the interview:

1. **No Kafka, no Snowflake.** The fleet has no event stream and no warehouse; the
   nearest equivalents are a ledger table and systemd journals. This is the central gap
   for a data platform role.
2. **No Terraform, GitLab CI, PySpark or dbt.** Infrastructure-as-code is Nix; the
   declarative model transfers, the tools do not.
3. **No production Kubernetes.** Hosts are single-tenant and role-separated; isolation is
   a CA and a module boundary, not namespaces and quotas.
4. **No Datadog.** Observability is a ledger, gatus and journald.
5. **Scale is not Flix scale.** Event volume is a sentinel every fifteen minutes, not
   millions of events a day.
6. **Level is inverted.** The posting asks 3+ years; this candidate is more senior than
   that. Say nothing defensive about it, but expect the "why this level" question, and
   the salary conversation will follow it.
7. **Berlin office-first means relocating** — see the section above.

## Files in `submissions/flix-data-platform-engineer/`

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | 2 pages A4, sha256 `66068134b75bd5f43534542ab83f8b047f47bd18f2cc21d675b1c1109a80e8f4` |
| `packet/anschreiben.pdf` | 1 page, English, sha256 `c2bb6d20f39b8a7e6821ae06a7b0e8a798a90bd66772a338e37731373db5dbe0` |
| `packet/selection.json` | Projection audit: kept and dropped lines with scores |
| `letter.json` | Letter source, so the PDF is reproducible from this tree |
| `job-description.txt` | Full posting text |
| `lead.md` | The originating lead |
| `submission-sheet.md` | This sheet |

Built with:

```
task agents:apps:packet ID=flix-data-platform-engineer \
  LETTER=submissions/flix-data-platform-engineer/letter.json \
  JD=submissions/flix-data-platform-engineer/job-description.txt \
  OUT=submissions/flix-data-platform-engineer/packet
```

Compiled in the Nix sandbox; `cv-ats-check.sh` read the finished CV back against the
record it was built from, and the page budgets held at 2 (CV) and 1 (letter). The
artifact stayed read-only in the store; the copies in `packet/` are `cp -L` of the same
bytes, which is why the hashes above are the ones to compare after any rebuild.

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
| Work authorization | Unrestricted in Germany; domestic relocation to Berlin needs no permit |
| Languages | German C1; English native |

## Next action

Nothing to send. The application is in; the record is at stage `applied`.

Wait for the talent attraction team (recruiter listed on the posting: Yevheniia
Perederii), then settle these at the first call: hybrid days per week expected, whether
relocation support exists for a domestic move, whether the 60-day "(M)Anywhere"
allowance applies, and the band, since the posting publishes none.
