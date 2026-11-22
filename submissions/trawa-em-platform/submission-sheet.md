# trawa — Engineering Manager, Platform and Data Intelligence

Arbeitnow listing `302262`, fetched 2026-11-22. Packet built the same day, **nothing submitted**.
Hand-authored Typst sources beside the PDFs.

| Field | Value |
| :--- | :--- |
| Role ID | `trawa-em-platform` |
| Employer | trawa, Berlin (~100 FTE, ~30 Product & Tech; €35M raised incl. €24M Series A 2025) |
| Role | Engineering Manager — Platform and Data Intelligence (two teams) |
| Reports to | Director of Engineering |
| Location | Berlin HQ; tech team **≥ 3 days/week** in office |
| Language | English |
| Pay | not published; salary + stock options |
| Fit | 3 — domain 5, management 1 |

## The dual match

This is the only role in the queue where the energy domain is an asset rather than a footnote, and it is
also a two-team platform role. The CV is ordered so both are visible without ranking one above the other.

### Energy domain

| trawa need | Evidence | Verdict |
| :--- | :--- | :--- |
| Understand energy procurement and volatility | Priced and hedged weather derivatives as internal risk manager | strong |
| Timeseries, metering and billing data | 10 MW solar PV asset management in a >USD 100 M portfolio; audit-grade financial models | strong |
| Renewable transition | MSc Renewable Energy Management, Freiburg; thesis on weather-pattern prediction and intermittency | strong, academic |
| Flexibility steering | Weather-driven volatility modelling; no direct flexibility-market trading | partial |
| "Data turns market complexity into savings" | Worked both sides: the analyst trusting the numbers and the engineer producing them | rare combination |

### Platform and data engineering

| trawa need | Evidence | Verdict |
| :--- | :--- | :--- |
| 3+ years people management across teams | **None.** Crew lead, director title, no engineering reports | **gap** |
| Deep data platform *or* platform/SRE, working knowledge of the other | Platform strong; data engineering partial (Postgres, pipelines, no warehouse ownership) | half, correctly shaped |
| AWS: IaC, cloud-native, containers, security, reliability, cost | Oracle hosts, one Lambda; IaC is NixOS modules — **no Terraform estate** | **gap** |
| Postgres, ClickHouse, dbt, Metabase | Postgres with append-only events; **no ClickHouse, dbt or Metabase** | partial |
| CI/CD and developer experience | Gate design in CI and host, task surface, runbooks | concept strong, tooling different |
| Observability practices | Fifteen-minute ledger, paging on state ≠ ok, incident notes | strong in substance |
| IT operations and security ownership | SOPS/age, least privilege, private CA, KEV reporting | strong |
| Cost efficiency | ARM over x86, microVMs, build cache — cost as design constraint | strong |

## Honest read

The advert's own escape hatch — "Don't meet every single requirement? We still encourage you to apply" —
is doing real work here: 3+ years of people management is the first listed requirement and the profile
has zero. What justifies applying is the shape of the second requirement ("deep background in data
platform/data engineering *or* platform engineering/SRE, solid working knowledge of the other") and the
domain, which almost no platform EM applicant will have. The letter says both plainly and does not use
the escape hatch as cover.

## Office rhythm — the honest evaluation

trawa is explicitly "office-first with flexibility", and the tech team's floor is **three days a week in
Berlin**. Gutach im Breisgau is roughly 700 km away.

| Option | Reality |
| :--- | :--- |
| Fully remote | Not offered; the 3-day floor is stated for tech |
| Weekly presence + home | Workable only with an overnight block per week; ~14 h travel weekly |
| Relocation | The honest fit if the role is offered; the letter says it would discuss this openly |
| Pretending a commute works | Not an option; seven hours each way is not a hybrid arrangement |

The letter commits to weekly presence and offers relocation as a conversation rather than asserting a
plan the candidate has not made.

## Pay

No band published, so no figure anywhere in the packet. Equity is part of the package (stock options),
which changes the comparison with the pure-salary roles in the queue — ask for the band and the option
strike/vesting terms in the first call.

## Checks

| Check | Result |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 226 prose files, exit 0 |
| sha256 Lebenslauf | `3767265b9aa46e0233609168df0bc6ddd6370a614f499a5a6eff0810de4932b6` |
| sha256 Anschreiben | `525c819d2dd5b272a25bad8556a28b75dcad6982f35e464c1c323ac28df58845` |

## Next steps

1. Apply via the Arbeitnow link; the domain story is the first paragraph, not a footnote.
2. Settle the three-day Berlin rhythm before any technical round — it is the binding constraint.
3. Ask for the salary band and the option terms together; one without the other is not comparable.
