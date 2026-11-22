# Submission sheet — Anthropic, Staff+ Software Engineer, Data Infrastructure

Greenhouse **5114768008** · https://job-boards.greenhouse.io/anthropic/jobs/5114768008
Published 2026-02-13 · Remote-Friendly (Travel-Required) | San Francisco, CA | Seattle, WA | New York City, NY

## Compensation — read this before answering anything

Anthropic publishes **USD 405,000 – 485,000** for this role. The example band supplied for this packet (USD 280,000 – 340,000) is **below the posted range**, so the recorded ask is **USD 405,000 – 440,000**, anchored at the band floor. If you intended a different anchor, change `compensation` in `selection.json` and this section before submitting.

## What the role is

Data Infrastructure: data processing, storage and access that are trusted, fast and easy to use. Four possible areas — governance and access control (IAM, ACLs, audit logging), financial data infrastructure (revenue/usage pipelines, warehouses), cloud storage and reliability (petabyte-scale DR, backup, replication on GCS/S3), and data platform/tooling (BigQuery, BigTable, Airflow, dbt, Spark). 10+ years, 3+ leading complex projects, Python/Go/Java/SQL. Hybrid: 25% in office (SF, Seattle, NYC), travel required.

## Live Greenhouse fields (27 server-side labels)

| Field | Answer |
| :--- | :--- |
| First Name * | Matt |
| Last Name * | Ji |
| Email * | matt@bountystash.com |
| Country | Germany |
| Phone | +49 1733281570 |
| Attach | CV: lebenslauf.pdf; cover letter: anschreiben.pdf. |
| Enter manually | n/a — files attached |
| Where can we learn more about you? | https://github.com/shaoyanji · https://www.bountystash.com · https://linkedin.com/in/mattji |
| When is the earliest you would want to start working with us? | Approximately 6–8 weeks from a signed offer, depending on notice period and relocation timing. |
| Do you have any deadlines or timeline considerations we should be aware of? | None. I am not holding another offer with a deadline. |
| Are you open to relocation for this role? * | Yes — I am based near Freiburg, Germany, and open to relocating for one of the US offices. |
| What is the address from which you plan on working? If you would need to relocate, please type "relocating". | relocating |
| Are you open to working in-person in one of our offices 25% of the time? * | Yes. I understand the location-based hybrid policy and the travel expectation. |
| (Optional) Personal Preferences | Prefer not to say. |
| AI Policy for Application * | Read and understood. I used AI assistance to edit and format my own materials; every claim is mine and is backed by the work referenced in the CV. |
| Have you ever interviewed at Anthropic before? * | No. |
| Do you require visa sponsorship? * | No. US citizen. |
| Will you now or will you in the future require employment visa sponsorship to work in the country in which the job you're applying for is located? * |  |
| Why Anthropic? * | Because the reliability of a data platform is a safety property when the platform feeds decisions about models, usage and revenue. I have spent years making small infrastructure trustworthy — hermetic builds, restore drills, telemetry that pages — and Anthropic is one of the few places where that same discipline is applied to systems with genuine consequences. I also want to work alongside people who treat interpretability and honesty about limitations as engineering requirements, not marketing. The Data Infrastructure charter, especially access control and financial pipeline integrity, is the version of that work I can do best. |
| Additional Information | Boundaries stated in the letter: no BigQuery/BigTable/Airflow/dbt/Spark operations, no petabyte-scale GCS/S3 replication or disaster recovery, no IAM/audit design at thousands-of-users scale. Strengths: PostgreSQL with migrations and rehearsed restores, backup automation, Linux and networking, hermetic Nix infrastructure-as-code, Go/Python tooling, telemetry and alerting. |
| How many years of industry experience in a full-time Software Engineer role (does not include internships and co-ops) do you have? * | 2006+ years across infrastructure, platform and software engineering roles (details in CV). |
| Which programming language would you likely use for a coding interview? * | Python |
| Please read the arbitration agreement below * | Read. |
| Agreement to Arbitrate * |  |
| Gender | Prefer not to say |
| Are you Hispanic/Latino? | Prefer not to say |
| Veteran Status | Prefer not to say |

## Preflight checklist

- [ ] Attach `lebenslauf.pdf` (2 pages) and `anschreiben.pdf` (1 page).
- [ ] Confirm the relocation answer: yes to US relocation, "relocating" as work address.
- [ ] Confirm 25% in-person acceptance.
- [ ] **Arbitration agreement**: not accepted on your behalf — read and decide it yourself.
- [ ] **AI policy**: the submitted answer discloses AI-assisted editing; adjust if you prefer your own wording.
- [ ] Confirm the years-of-experience number against your own count.
- [ ] Confirm the compensation anchor at USD 405,000–440,000.
- [ ] Voluntary EEO fields left as prefer-not-to-say.
- [ ] Nothing submitted until reviewed.

## Additional context (letter content)

The pitch is reliability with evidence: 13-host NixOS fleet as code, PostgreSQL with versioned migrations and rehearsed restore drills, backup automation, storage with retention rules, disk/PSI/latency/job-state telemetry that pages on failure. Hermetic builds — pinned inputs, reproducible generations, one-command rollback — so a canary-verified change is the same artifact that reaches every host. sops/age secrets and short-lived SSH certificates as access discipline. Go and Python for pipelines, services and automation.

Leadership: ran an international team at O3 Energy and built the financial model its incentive structure rested on — accountability for numbers other people decided with.

## Boundaries, stated plainly

- No BigQuery, BigTable, Airflow, dbt or Spark operations.
- No petabyte-scale GCS/S3 replication or disaster recovery.
- No IAM and audit-logging design for thousands of users or ITGC/GDPR programme ownership.
- Storage and query work at small-fleet scale, not warehouse scale.
- Financial data experience is modelling and reporting ownership, not revenue pipeline engineering.

Honest fit is closer to 2 on the 10+ years data-infrastructure specialisation; stored as 3 as instructed.

## selection.json

Standard engineering evidence (`projects.kept`: nixconfig, email-archive, bountystash, fibtransponder), plus `greenhouse` (all {len(labels)} live field mappings), `compensation`, and `candidate` blocks.

Nothing submitted. No account created.
