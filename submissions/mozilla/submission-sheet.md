# Mozilla — Staff Software Engineer, Tools & Systems

Remote Germany, Greenhouse **8315181**. English packet. Native Typst sources; the `packet` symlink into `/nix/store` and
`selection.json` are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `mozilla` |
| Employer | Mozilla Corporation (wholly owned by the Mozilla Foundation) |
| Role | Staff Software Engineer, Tools & Systems |
| Location | Remote Germany |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/mozilla/jobs/8315181 |
| Compensation | published **EUR 81,000 – 108,000** plus performance bonus; no figure quoted in the letter |
| Fit | 3 (DB entry 4) |

## What the role is

The tools and systems that support Firefox engineering: internal engineering systems, developer tooling, workflow
automation, and the infrastructure they run on. Cloud Engineering owns shared platforms; product teams own their services;
this role makes that model work by solving hard operational problems, setting standards and patterns, and building the
automation. Build in the open, contribute upstream. Requirements: strong software engineering **plus** production
operations; Python or JavaScript/TypeScript (C++/Rust useful); cloud deployment with **Terraform**; several of CI/CD,
containers and orchestration, networking, databases, observability, developer tooling; telemetry-driven decisions;
familiarity with AI-assisted development tools.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Developer tooling and workflow automation | One entry surface with validation, help text, JSON output | **strong** |
| CI/CD | One gate for CI and host, inventory-driven matrix, per-host process | **strong** |
| Reproducible builds | Pinned inputs, content-addressed outputs, identical rebuild | **strong** |
| Linux systems internals | systemd, cgroups, PSI, `strace`, `tcpdump`, nftables | **strong** |
| Telemetry and data-driven decisions | Fifteen-minute ledger, capacity and cache arguments | **strong** |
| Python / Go | Go service, Python tooling, tests | strong |
| Open source working style | Public repository, generated docs, decisions readable | **strong** |
| AI-assisted development | Drafts gated against requirements, no credentials to models, human signs | strong |
| Terraform and managed cloud | **none**; Nix flake and bare metal | **gap, named** |
| JavaScript / TypeScript | **none**; Go, Python, Bash, some C++ | **gap** |
| Browser-scale C++ / Rust codebase | **none** | **gap** |
| Containers and orchestration at scale | microVMs and slices, **no Kubernetes** | partial |

Fit **3**: tooling, CI, reproducibility, Linux and telemetry are exactly the columns this corpus can defend with public
evidence; Terraform, TypeScript and browser-scale C++ are absent. The DB keeps the instructed **4**.

## The argument the letter makes

It opens by naming the role as work already done alone for five years — the systems other engineers depend on, built so
they keep working when the builder is asleep — and then argues three properties rather than a tool list: **reproducibility
is a property of the repository, not a discipline of the person**; **the gate is the same everywhere**, so a green build
cannot disagree with a healthy machine; and **the documentation is a build artefact**, so a stale page is a build failure
rather than a drift someone finds during an incident.

The gap paragraph is explicit because a staff role deserves it: no browser-scale C++ or Rust, no Terraform or managed
cloud, no JavaScript or TypeScript. The framing is that the build system is Nix and the target is bare metal — same
questions, different machinery.

## One thing to consider before applying

The band is **EUR 81,000 – 108,000** for a **staff** title, which is below market for staff-level infrastructure in Germany.
Nothing about that is fatal, but it should be known before a four-stage process: decide whether the top of that band is
acceptable, and if not, raise it at the recruiter screen rather than at offer. The letter quotes no number.

## Greenhouse form (8315181)

| Field | Answer |
| :--- | :--- |
| First / last name | Matt / Ji |
| Email | matt\@bountystash.com |
| Phone | +49 1733281570 |
| Resume | `lebenslauf.pdf` (2 pages) |
| LinkedIn | https://linkedin.com/in/mattji |
| Website | https://www.bountystash.com |
| How did you hear about this job? * | Career Site (`757625518`) |
| Employed by Mozilla before? * | No |
| Fill the position in a listed country without relocation assistance? * | Yes — German permanent residence, no sponsorship |

## Checks

| Check | Result |
| :--- | :--- |
| `packet` symlink into `/nix/store` | removed |
| `selection.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `PSI`, `pinned`, `Terraform` (gap), `content` |
| Markers letter | `Mozilla`, `Terraform`/`TypeScript`/`C++` (gaps), `reproducible` |
| `task checks:prose` | 254 prose files, exit 0 |
| sha256 CV | `7d4efbff2019e31f0d648784eaff6f5804b45a41c989fd0210c0f189b5b5e7c1` |
| sha256 letter | `ad1119c734f36b5281d6b4e09e9c24aac693b88d1221d046e7455557cbb95e4d` |
| DB read-back | verified after upsert |

## Next steps

1. Apply through Greenhouse 8315181; the form asks three questions with exact option IDs, listed above.
2. Decide on the band before the screen, since a staff title at that range is the likeliest friction point.
3. Ask which internal system costs Firefox engineers most time — the question in the letter is a real one, and the answer
   shapes whether this role is build, test infrastructure or environment provisioning.
