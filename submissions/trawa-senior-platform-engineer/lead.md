# Lead: trawa — Senior Platform Engineer (Berlin)

Fit: 4
Status: packet prepared 2026-11-22
Language: en
Compensation: not published; salary plus stock options

## Why it is interesting

trawa sells the claim that European industry can cut up to 30 % of recurring electricity cost by switching to renewable supply, and the product is an integrated B2B energy platform covering procurement, energy management and the marketing of flexible assets. Around 100 people, Berlin, more than EUR 35M raised, third market in 2027. The Platform team owns infrastructure, shared tooling and developer experience, so the work is the multiplier for every other engineer.

The domain overlap is not decorative: M.Sc. Renewable Energy Management at Freiburg (1.8), Fraunhofer ISE solar research, four years steering 10 MW PV assets at O3 Energy. This is a company whose customers buy what the candidate studied.

## What matches

- Ten years of running infrastructure end to end, five of them owning a fleet of thirteen hosts across three hardware generations.
- Declarative infrastructure: every service a module, every host a feature list, every change a commit.
- CI gate equals rollout gate; every state kept as a generation and rollback is the normal path, not the emergency.
- Observability with a real signal: a sentinel ledger every 15 minutes on job status, generation age, disk and PSI pressure, plus endpoint checks and alerts confirmed only on delivery.
- Security in the pipeline: sops and age, an own SSH certificate authority with short-lived certificates, nftables, no publicly exposed service.
- Cost and stability as one problem: resource limits per service, memory pressure watched as a first-order metric.
- Tooling in Go and Python when shell is not enough; documentation as runbooks so the team is not one person deep.
- Developer enablement: others were onboarded onto the fleet and given tasks instead of tribal knowledge.

## What is missing

- AWS: no production experience; the fleet is bare metal and VLANs, not cloud primitives.
- Terraform and Spacelift: infrastructure as code yes, these tools no.
- Docker and container orchestration in production.
- GitHub Actions: CI exists, the runner and the ecosystem do not.
- Postgres and ClickHouse operations at platform scale.
- Dash0, Sentry, Incident.io: adjacent practice, different products.
- The eight-year bar in a *titled* platform, DevOps or SRE role: five years as founder doing exactly this work, plus earlier engineering, is close but not identical.
- Berlin presence most of the week: candidate lives in Gutach im Breisgau, roughly 700 km away. Relocation is a real decision, not a formality.

## Route

Ashby application on the posting. No deadline published; the role is open as of 2026-11-22. No recruiter contact named in the posting.

## Money

No band published. Salary plus stock options, 30 days vacation. The own expectation of EUR 85,000 to 95,000 for a senior platform role in Berlin is plausible for the range but cannot be checked against the posting; no number goes in the letter.
