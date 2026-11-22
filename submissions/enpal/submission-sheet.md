# Enpal — Staff Platform Engineer (f/m/d)

Berlin-Friedrichshain, hybrid. English packet. Native Typst sources; `selection.json` and the old Nix-built PDFs are
removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `enpal` |
| Employer | Enpal |
| Role | Staff Platform Engineer (f/m/d) |
| Location | Berlin, hybrid (posting says no remote) |
| Language | **en** |
| Apply URL | https://www.arbeitnow.com/jobs/companies/enpal/staff-platform-engineer-berlin-319233 |
| Compensation | not published; staged target 130,000–150,000 EUR, **not quoted in the letter** |
| Fit | 3 (DB entry 5) |

## What the role is

Technical leadership for Enpal's internal platform: own the architecture, drive automation and self-service for the whole
engineering organisation, set standards for **Kubernetes operations, CI/CD, observability and infrastructure as code**,
treat the platform as a product with metrics, mentor engineers, and lead cross-team initiatives with minimal oversight.
**8+ years** platform/cloud/DevOps, hands-on **Azure + Kubernetes** in production, **Terraform**, Helm, observability
tooling, strong system-design trade-off reasoning. German is a plus; regulated-energy experience is a nice-to-have.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Energy domain, regulated environment | Asset management of a USD 100M+ solar portfolio, bank-audited models, O&M, audits | **strong, and rare** |
| Platform architecture and ownership | Thirteen hosts as one declaration, generations, pinned inputs | strong at small scale |
| Automation, self-service, toil removal | One validated entry surface; docs generated from source | **strong** |
| Standards across teams (CI/CD, gate) | Gate identical in CI and host; failure twice becomes a check | **strong** |
| Observability | Fifteen-minute ledger, alert on state, silence as fault | **strong in principle** |
| Kubernetes operations in production | **none** | **gap, required** |
| Terraform, Helm | **none**; Nix flake is the IaC | **gap, required** |
| Azure | **none** | **gap, required** |
| Mentoring, raising the bar | Led an international team, design review, documentation as product | strong |
| Cross-team initiatives end to end | Fleet-wide changes, generated docs surface, task plane | partial, small org |
| Go / Python | Go service with tests, Python tooling | strong |
| Platform as product with metrics | Self-service surface, generated navigation, cost and capacity thinking | strong |

Fit **3**. The domain and the platform instincts are genuinely differentiated; three named must-haves (Kubernetes,
Terraform/Helm, Azure) are absent, which for a staff role that sets standards across teams is a real ramp. The DB keeps the
instructed **5**; the sheet records what an interviewer would find.

## The argument the letter makes

It opens on the part of Enpal.One+ Matt has lived from the inside rather than observed: a string that stops reporting still
looks green on a dashboard that only counts what arrives, and the gap between those states is a year of yield and an
argument with a bank. That is the operator's version of connecting thousands of systems, and it makes the energy domain
load-bearing rather than decorative.

The platform half is answered with the thing the posting actually asks for — platform as a product — and the measure is
whether a developer ships without asking: one entry surface with validation, docs generated from the same source as the
configuration, a gate that cannot disagree between CI and host.

The stack gap gets its own paragraph and one good line: rather than pretend a flake is a Terraform module, the letter says a
staff role that sets standards deserves someone who learns the agreed stack properly first.

## Compensation

No band is published for this role. The staged target of 130,000–150,000 EUR stays in this sheet and out of the letter, so
the first number mentioned is theirs. Confirm the band is reachable before submitting.

## Application route

The arbeitnow link is an aggregator. The real ATS is Ashby:
https://jobs.ashbyhq.com/enpal/5f2bc677-edc1-48e5-9118-92d80a7ed352/application — the Ashby public posting API confirms
`Staff Platform Engineer (f/m/d)`, Berlin, FullTime, published 2026-11-16, `isListed: true`.

The Ashby form is client-rendered (no server-side labels), so confirm each field on the live page. Values to hand: Matt Ji,
matt\@bountystash.com, +49 1733281570, CV `lebenslauf.pdf`, letter `anschreiben.pdf`, LinkedIn
https://linkedin.com/in/mattji, GitHub https://github.com/shaoyanji, location Gutach im Breisgau — open to Berlin hybrid,
German Niederlassungserlaubnis, no sponsorship, German C1.

## Checks

| Check | Result |
| :--- | :--- |
| `selection.json`, old Nix-built PDFs | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `PSI`, `ledger`, `O&M`, `generation` |
| Markers letter | `Enpal.One+`, `Kubernetes` (gap), `Terraform` (gap), `auditors` |
| `task checks:prose` | 247 prose files, exit 0 |
| sha256 CV | `fad1decebd4437d9e1bbab580b135cc619c8eded859609e6bd64b1ce4b4e3d26` |
| sha256 letter | `fb2d224d3ab7279fde39034af8bc5e1145a112f36ebf4993cc03cdd7935a52e2` |
| DB read-back | verified after upsert |

## Next steps

1. Apply through Ashby, not the aggregator.
2. Ask what the current platform stack really is — the posting names Azure, Kubernetes, Terraform and Helm, which is a stack
   decision as much as a hiring one.
3. Ask how platform success is measured today, since the posting asks for the metrics but not an existing number.
