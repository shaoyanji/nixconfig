# Maze — Senior Site Reliability Engineer | SRE (Remote, EU/CET)

**Status: packet built, NOT submitted.** **[applied per apps DB `maze-senior-sre` (Ashby ack mail 311044) — this sheet's status predates submission]** 2026-11-22. Nothing sent, no account created,
no form opened.

The pipeline record said "Packet ready — CV and letter compiled 2026-11-21" with
`folderPath: submissions/maze`, but this directory did not exist and no JD was cached:
the claim was ahead of the work. The record is now backed by the files below, and the
status reads `packet built 2026-11-22 - not submitted` so it cannot drift again.

## Role

| Field | Value |
| :--- | :--- |
| Company | Maze (Series B, <150 people) |
| Role | Senior Site Reliability Engineer, Platform team |
| Board | Ashby, `mazedesign` |
| Posting ID | `f70288aa-44e4-4999-af2b-1b7f7ad3e8d5` |
| Apply URL | https://jobs.ashbyhq.com/mazedesign/f70288aa-44e4-4999-af2b-1b7f7ad3e8d5/application |
| Published | 2026-08-24 |
| Location | Remote — EU/CET; preference for NL, UK, IE, ES, PT |
| Compensation | EUR 109,000–128,000 + equity (published band) |
| Language | `en` |
| Pipeline record | `maze-senior-sre`, fit 5, stage `prep` |
| Folder | `submissions/maze/` |

## Location — the one question this role asks, and it is not a relocation

The posting is remote with a stated preference for five countries: Netherlands, United
Kingdom, Ireland, Spain, Portugal. **Germany is not on that list**, which is the only
location risk here. It is not a relocation question: the candidate is in Gutach im
Breisgau, which is CET — the exact timezone the role is hired into — so there is no
move, no permit, and no commute to decide.

The letter states that plainly and asks rather than assumes: Germany is outside the
preference list, the timezone overlap is full, and travel for retreats and on-sites is
fine. That is a question for the recruiter, not an operator decision that blocks the
packet.

## Files in `submissions/maze/`

- `packet/lebenslauf.pdf` — 2 pages, projected from this JD: **12/32** highlights, 4/10 projects
- `packet/anschreiben.pdf` — 1 page, English letter
- `packet/selection.json` — the projection audit, kept and dropped with scores
- `letter.json` — letter source, so the PDF is reproducible from this tree
- `job-description.txt` — the posting as published (Ashby job-board API, `descriptionPlain`)
- `submission-sheet.md` — this sheet

Built with `task agents:apps:packet ID=maze-senior-sre JD=submissions/maze/job-description.txt
LETTER=submissions/maze/letter.json`, which compiles in the Nix sandbox. Verified after
build: CV 2 pages, letter 1 page, letter text carries the Maze header and address block.

## Projection audit

Twelve terms ranked from the description, strongest first: **security** (27.412),
**cloud** (24.189), **systems** (24.189), **fast** (22.609), **aws** (14.67),
**secure** (13.019). The scorer read this posting as a security-and-cloud role, not a
generic SRE role, which is what the JD says: vulnerability management, cloud security
posture, audit readiness and SOC 2 / ISO 27001 sit alongside the reliability work.

- **Highlights: 12 of 32** — Bountystash 4/10, O3 Energy 2/8, Smart Energy 360 2/4,
  Fraunhofer ISE 2/4, Halliburton 2/6.
- **Projects: 4 of 10** — `Risk Calculation Engine (Swirl Engine)`, `nixconfig`,
  `kev-time`, `Vulnerability operations concept`. The two security projects surviving
  is the point of this projection: `kev-time` tracks the CISA KEV catalogue and the
  vulnerability-operations concept is the patching policy, so the CV leads with the
  security half the JD weights most.

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| Website | https://www.bountystash.com |
| Citizenship | United States |
| Residence | German permanent residence (*unbefristete Niederlassungserlaubnis*) |
| Work authorization | Unrestricted in Germany; EU remote needs no permit |
| Languages | German C1; English native |

## What the letter claims, and what it concedes

Claimed, all of it from work in this repo: thirteen NixOS hosts declared in one flake
with an SSH certificate authority and SOPS secrets; a sentinel writing job status,
generation age, disk and pressure-stall figures to a ledger every fifteen minutes and
paging when a state is not ok; gates that read the built artifact back before a change
counts; Go and Python services; PostgreSQL with versioned migrations and rehearsed
restores; a KEV-driven vulnerability pipeline; nftables default-deny; daily work with
coding agents operating the change loop.

Conceded in the letter rather than left for an interview:

1. **No production AWS.** The fleet runs on owned hardware; cloud vocabulary is reading.
2. **No Kubernetes or Terraform.** Nix is the infrastructure language here; container
   orchestration is a skill keyword, not operating experience.
3. **No Datadog.** Observability is a self-built sentinel and ledger, not an APM vendor.
4. **No SOC 2 or ISO 27001 audit.** The habits exist; the audit does not.
5. **No Neo4j, no Snowflake, and TypeScript/Node is not primary.** The application is
   not the platform's own language.

## Ashby form — read it at submit time

The form's question set was not fetched for this packet. Ashby's `application` URL is
client-rendered, so the fields must be read live at submission: expect name, email,
phone, resume upload, location, LinkedIn/website, and at least one authorization or
location question. Answer location as **Germany, CET, remote** — do not silently claim
one of the five preferred countries — and answer work authorization as **German
permanent residence, no sponsorship needed**.

## Salary

The band is published: **EUR 109,000–128,000 plus equity**. Do not open with a number;
when asked, target **EUR 120,000** inside the band, and treat the published floor of
109,000 as acceptable against the candidate's own floor of 95,000.

## Next action

Review the packet, then submit on Ashby with `packet/lebenslauf.pdf` and the letter's
content. Stage stays `prep` and nothing is sent until that instruction is explicit.
