# Miaplaza — Hands-on Engineering Manager DevOps (GCP/Kubernetes)

Arbeitnow listing `302151`, fetched 2026-11-22. Packet built the same day, **nothing submitted**.
Hand-authored Typst sources beside the PDFs, as with the Catapult packet.

| Field | Value |
| :--- | :--- |
| Role ID | `miaplaza-em-devops` |
| Employer | Miaplaza (US EdTech, self-funded; Miacademy, MiaPrep, Always Icecream) |
| Role | Hands-on Engineering Manager, DevOps (GCP/Kubernetes) |
| Location | **100% remote (EMEA)**; two-month senior-engineer onboarding before taking the team |
| Team | four engineers, reporting to the head of engineering, ~50/50 hands-on |
| Language | English |
| Pay | **82.000 – 140.000 EUR**; placement by skills, internal equity and local market |
| Ask | **110.000 EUR** |
| Fit | 3 — the advertised 4 fails on the management line, not on infrastructure |

## Match analysis

| Requirement (advert) | Evidence | Verdict |
| :--- | :--- | :--- |
| 7+ years DevOps / SRE / Infrastructure | Ten years operating systems; five owning a thirteen-host fleet | strong |
| 3+ years production Kubernetes, GKE preferred | **None.** Containers as pinned build environments | **gap** |
| 3+ years major cloud + IaC; senior GCP (IAM, KMS, GKE, CloudSQL, Secret Manager) | Oracle Cloud hosts, one Lambda project; GCP never operated | **gap** |
| 2+ years mentor/leader, 1+ leading a team | Two frac crews, safety training owned, director title, direct instruction of field staff | **partial — leadership yes, engineering reports no** |
| 3+ years at Senior/Staff/Principal level | Sole engineer and founder; no staff-level scope inside a larger org | partial |
| CI/CD pipeline design and operations | Gate design executed in CI and on the host; no GitLab/GitHub pipeline built | partial |
| GitOps (FluxCD or ArgoCD) | Declaration, gate and rollback by generation; **no Flux or Argo** | concept yes, tool no |
| Working with other managers as customers, scoping | Client-facing scoping as director and consultant; no internal platform customer | partial |
| Incident response and postmortems | Ledger-based incident reconstruction, causes written into the repo | strong in substance |
| Self-hosted observability (Prometheus, Loki, Grafana) | Custom ledger, journald, PSI, gatus; **no Prometheus stack** | strong practice, different tools |
| Internal developer platform / self-service | Task surface, runbooks, gates; not a portal | partial |
| PostgreSQL / MongoDB / Redis (standout) | Go services on PostgreSQL with append-only events | strong on PostgreSQL |

## Pedagogical leadership — the part that actually matches

Miaplaza's unusual claims are the ones worth answering directly: full oversight of direct reports' work,
feedback as the norm, growing engineers as a stated responsibility, and an EM who stays in the code.

| Claim | What the packet can show | Honest reading |
| :--- | :--- | :--- |
| "You can't teach what you don't see" | The ledger records process, not just outcome — job status, generation age, disk, PSI; incident causes are written down | the instinct is real, the practice was solo |
| Feedback is the norm | Reviews run from recorded state rather than recollection; specific because the data is specific | no experience giving feedback to reports |
| Grow your engineers | Taught field technicians directly instead of routing tickets; ran crew safety training and certification | teaching yes, engineer development no |
| ~50% hands-on | Five years as the only engineer: design, code, operate, document | matches exactly |
| Shrink and consolidate the stack | Cost and complexity treated as design constraints (ARM, microVMs, build cache); repeated subtraction | matches the stated goal |

The CV puts leadership in its own section so the claim is visible without inflating it: crews and
instruction, not performance reviews. The letter says the same sentence — led people, never managed
engineers — and turns the two-month onboarding into the reason this role is credible rather than a
workaround.

## Pay band notes

| Point | Value |
| :--- | :--- |
| Published range | 82.000 – 140.000 EUR |
| Ask | **110.000 EUR** |
| Position | ~48% of the band; between the 82k floor and the 140k ceiling |
| What sets placement | skills, internal equity, **local labour market for the candidate's area** |
| Risk | the management gap pulls toward the lower half; German labour cost sits above Miaplaza's US-remote median for EMEA |
| Why the number holds | the range is public, so this is a positioning choice, not a negotiation guess |

110k is a fair ask given no GKE and no reports: it is above the floor by 28k, which the platform depth
supports, and 30k below the ceiling, which the management gap does not. If they anchor at the floor,
the counter is the onboarding value — the role expects a senior engineer for two months, and that is the
part of the profile that is already true.

## Checks

| Check | Result |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 224 prose files, exit 0 |
| sha256 Lebenslauf | `61ec206b654eabf32c9d8ce776db1e522fd0c40454ff0e2bbbc75943e84a6974` |
| sha256 Anschreiben | `1984ed5058ac0e1dd92a31942e02d459b613cb15b75252fdf99933358db68c69` |

## Next steps

1. Apply through the Arbeitnow link; expect a 20-minute screen with seven technical questions.
2. Prepare for the scenario interview: GKE migration with a four-person team is the obvious prompt.
3. Line up three references early — at least one former manager is required, and the reference check is
   a named stage.
