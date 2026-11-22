# GitLab — Senior Staff SRE, Architecture Engineering: Hosted Runners

Remote (US / Canada / UK). English packet. Native Typst sources; `selection.json` and the old Nix-built PDFs are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `gitlab` |
| Employer | GitLab |
| Role | Senior Staff SRE, Architecture Engineering: Hosted Runners |
| Team | Hosted Runners / Runners Platform |
| Location | Remote, United States; Remote, Canada; Remote, United Kingdom |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/gitlab/jobs/8932489002 |
| Greenhouse ID | 8932489002 |
| Compensation | **USD 184,800 – 314,400** base + equity, no bonus; staged target USD 300,000 |
| Fit | 3 (DB entry 4) |

## What the role is

The compute behind every GitLab.com CI job: runner control plane, worker provisioning, workload isolation, autoscaling
during demand spikes, job pickup latency, usage metering for capacity and billing, and Go work across GitLab Runner and its
cloud integrations. Staff scope: architecture across teams, migrations with representative workload tests and rollback
paths, on-call on the Runners Platform rotation, mentoring, and validating AI-assisted changes.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Production systems software: controllers, agents, schedulers | Go service with an append-only job lifecycle; per-host deployment mechanism | partial, small scale |
| Strong Go, concurrency, retries, resource cleanup | Go service and tests; `fibtransponder` streaming with benchmarks; declared teardown | **strong** |
| Deep Linux and networking, trace across layers | systemd, cgroups, PSI, `strace`, `tcpdump`, nftables, WireGuard, MTU work | **strong** |
| Production Kubernetes, scheduling and rollouts | **none** | **gap, required** |
| Autoscaled or dynamically scheduled compute; VM fleets | **none**; a fixed thirteen-host fleet | **gap, required** |
| Public cloud and infrastructure automation | bare metal; automation is Nix and netboot | partial, different tooling |
| CI job lifecycle and running customer-controlled code | CI gate, isolation in microVMs and slices; **no runner fleet** | partial |
| Lead initiatives across teams, async writing, mentoring | Documentation as a product surface, mechanism over review comments | partial, small org |
| Validate AI-assisted changes before production | Drafts gated against the requirement, human signs, no credentials to models | **strong, and named in the JD** |
| Work location | US citizen, based in Germany; req lists US/CA/UK only | **decision to confirm** |

Fit **3**. Isolation, Go, Linux depth and the observability habit are genuinely close to the role. The two structural
requirements — Kubernetes in production and autoscaled VM fleets — are absent, and this is a staff req where both are
listed as things you bring.

## The argument the letter makes

It opens on the defining property of the job: a hosted runner is one of the few places where a stranger's code runs inside
your infrastructure on purpose, thousands of times an hour, and each job must get a machine, be contained, finish, and
leave nothing behind. Containment and cleanup are the parts this corpus can actually defend — declared microVMs with their
own kernel boundary, memory-capped systemd slices, teardown owned by the creating declaration, because a slice that leaks
per run becomes a fleet that cannot accept the next job and shows up as a capacity bill before an incident.

The gap paragraph is unusually long for this packet on purpose: no Kubernetes in production, no autoscaling cloud fleet,
thirteen machines rather than thousands of workers, and no experience with usage metering at billing scale. The framing is
that of someone who can own a control-plane component and its operations, not someone who has run this fleet.

## Location — settle before submitting

The req lists **Remote, United States / Canada / United Kingdom**. Matt is a **US citizen resident in Germany**. A US
contract or relocation is plausible; a Germany-entity hire may also be possible given GitLab's global hiring, but the
posting does not say so. The letter raises it directly rather than letting it surface at offer stage. Confirm with the
recruiter before investing in a multi-stage process.

## Checks

| Check | Result |
| :--- | :--- |
| `selection.json`, old Nix-built PDFs | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `microVM`, `PSI`, `cgroups`, `Go` |
| Markers letter | `Kubernetes` (gap), `autoscaling` (gap), `residency`, `metering` |
| `task checks:prose` | 249 prose files, exit 0 |
| sha256 CV | `bbd5cbdfef413e81386afe69403c1dc3919533f10975e7ebc47f8d94dd9b4845` |
| sha256 letter | `5c6747a738b5d63c9e832f98119d281dc493cd1f591bb18ff933addcbef3dc6a` |
| DB read-back | verified after upsert |

## Next steps

1. Confirm location eligibility (US contract vs Germany entity) before applying.
2. Ask how isolation is chosen today — Kubernetes pods, microVMs or both — since the posting lists it as an open design
   question, which is the most interesting thing in the req.
3. Prepare the Go sample: the job-lifecycle service and `fibtransponder` are the closest things to controller code.
