# Coda — Senior Infrastructure Operations Engineer

Amsterdam, **hybrid** (Lever: workplaceType hybrid, country NL — not remote). English packet. Native Typst sources;
`selection.json` and the old Nix-built PDFs are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `coda` |
| Employer | Coda (Singapore HQ; Amsterdam, Dubai, Bristol, Shanghai, Eindhoven) |
| Role | Senior Infrastructure Operations Engineer, InfraOps |
| Location | Amsterdam, hybrid |
| Language | **en** |
| Apply URL | https://www.arbeitnow.nl/jobs/companies/coda/senior-infrastructure-operations-engineer-amsterdam-netherlands-459282 |
| Real ATS | Lever `dab81392-7736-4942-b633-110f5cab1eb5` — https://jobs.lever.co/Coda/dab81392-7736-4942-b633-110f5cab1eb5/apply |
| Compensation | not published; staged ask EUR 95,000–120,000, **not quoted in the letter** |
| Fit | **3** (DB entry 4) |

## What the role asks

Secure, highly available **AWS** infrastructure across multiple accounts and regions; Terraform (or similar) and CI/CD;
AWS security — IAM, cross-account access, SCPs, RCPs, CloudTrail, Config, GuardDuty, Security Hub; VPC, routing, firewalls,
VPN and private connectivity; Linux with Python or Bash and containers (Docker, ECS, Kubernetes); Datadog, Grafana,
Prometheus or OpenTelemetry; on-call and incident response; cost efficiency. **5+ years** infra ops with **3+ on AWS**.
Plus: security automation (Cloud Custodian, Checkov, Trivy), PCI DSS or CIS AWS Benchmark, high-traffic or payment
platforms, AWS certifications.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Infrastructure operations, on-call | Five years running the fleet and holding the pager | **strong** |
| Least privilege, access control | SSH CA with short-lived certificates, per-host secrets, default-deny | **strong** |
| Infrastructure as code discipline | One declaration, pinned inputs, gate identical in CI and host, rollback by pointer | strong, **not Terraform** |
| Networking | nftables, WireGuard mesh, own DNS, MTU proven with `tcpdump` | strong, **not VPC/Transit** |
| Linux, Python, Bash | systemd, cgroups, PSI; Python and Bash automation; Go services | **strong** |
| Monitoring and alerting | Fifteen-minute ledger, alert on state, silence as fault | strong, **hand-built** |
| Cost and capacity | Retention as a decision, disk pressure measured | strong at small scale |
| AWS (EC2, ECS, Lambda, RDS, VPC, Route 53, CloudFront) | **none** | **gap, required** |
| AWS Organizations, IAM policy, SCPs, CloudTrail | **none** | **gap, required** |
| Terraform | **none**; Nix flake | **gap, required** |
| Docker / ECS / Kubernetes | **none** | **gap** |
| Datadog / Grafana / Prometheus / OTEL | **none** | gap |
| Payments, PCI DSS, 70-market scale | **none** | gap |

Fit **3**. The operations and access-control columns are genuinely strong; the AWS/Terraform/container stack is the bulk of
the job description and is absent. The DB keeps the instructed **4**.

## The argument the letter makes

Payments run on two promises that look like infrastructure: the money moves exactly once, and the shop is open at 03:00 on
the busiest night. Both are bought with unglamorous discipline — enforced least privilege, changes reversible by someone
who did not make them, and alarms that mean something. The letter then shows that discipline at fleet scale: access issued
rather than stored (short-lived SSH certificates, per-host secrets, default-deny), a gate identical in CI and host,
generations with parents so rollback is a pointer, and a fifteen-minute ledger that pages on silence.

The gap paragraph is deliberately blunt, because the JD asks for **3+ years of AWS specifically**: no EC2, ECS, Lambda,
RDS, VPC, Route 53 or CloudFront, no AWS Organizations, IAM policy design, SCPs or CloudTrail, no Terraform, no Docker/ECS/
Kubernetes, no Datadog or Grafana. Same invariants, different tooling.

## Location and permit — the part that needs care

- The role is **hybrid Amsterdam**, not remote, whatever the aggregator suggests: roughly 700 km from Gutach.
- **A Dutch contract does not inherit German residence rights.** The Niederlassungserlaubnis is national. A Dutch contract
  needs a sponsored permit — the *kennismigrant* route, which requires a recognised sponsor and a salary threshold above
  the 30+ rate. US citizenship makes the person eligible; it does not make the employer a sponsor.
- Confirm both the sponsorship route and the hybrid expectation **before** investing in a process. The letter raises it.

## Lever form (live labels, 9 labels / 25 inputs)

| Field | Answer |
| :--- | :--- |
| Resume/CV * | `lebenslauf.pdf` — check the autofill parsed name and dates |
| Full name * | Matt Ji |
| Email * | matt\@bountystash.com |
| Phone * | +49 1733281570 |
| Current location | Gutach im Breisgau, Germany (relocation to Amsterdam: discuss) |
| Current company | Bountystash (founder) |
| LinkedIn / GitHub / Portfolio | linkedin.com/in/mattji · github.com/shaoyanji · bountystash.com |

**Lever has no cover-letter upload field.** The letter goes nowhere unless a custom question appears; if one does, paste
the first paragraph plus the permit sentence.

## Checks

| Check | Result |
| :--- | :--- |
| `selection.json`, old Nix-built PDFs | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `AWS` (gap), `Terraform` (gap), `short-lived`, `PSI`, `on-call` |
| Markers letter | `Coda`, `AWS`, `Terraform`, `Dutch contract`, `PCI DSS` |
| `task checks:prose` | 251 prose files, exit 0 |
| sha256 CV | `1c483614bf5a5757633dd56d223d2ce8967aeb83653135b8dc849341301343ea` |
| sha256 letter | `c01902bd36bb505c87780cc7999ac5db83a47a8878b1988c8d5908608f7f9b21` |
| DB read-back | verified after upsert |

## Next steps

1. Confirm the kennismigrant route and the hybrid expectation before applying.
2. Decide whether to keep the AWS gap paragraph: it is honest, and it will likely end this application at screen.
3. If submitting anyway, lead the recruiter note with the access-control and rollback material, not the stack.
