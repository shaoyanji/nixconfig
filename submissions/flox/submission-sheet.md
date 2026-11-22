# Flox — Member of Technical Staff, Infrastructure & Operations

Remote, full time, Engineering, reports to the VP of Engineering, on-call included. English packet. Native Typst
sources; `Flox_Cover_Letter.pdf`, `Matt_Ji_Resume_Flox.pdf`, `selection.json` and the two `.txt` files are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `flox` |
| Employer | Flox |
| Role | **Member of Technical Staff, Infrastructure & Operations** |
| Location | Remote (US-incorporated; remote contract) |
| Language | **en** |
| Posting | https://jobs.ashbyhq.com/flox/87f6bc08-b01d-47ad-bad3-5fd74b7c60c9 |
| Compensation | USD 180K – 250K published (from the 2026-11-21 recon) |
| Fit | **4** |

## Title discrepancy — resolved against the live board

This packet was requested as "Senior Infrastructure / Release Engineer". **No such posting exists on Flox's live
board.** Ashby's public job-board API (`api.ashbyhq.com/posting-api/job-board/flox`, queried 2026-11-22) lists five
roles: Security Engineer, Member of Technical Staff, Senior Software Engineer (Packaging), Member of Technical Staff
(Infrastructure & Operations), and Head of Business Operations & Finance. The ID in this directory's earlier recon,
`87f6bc08-b01d-47ad-bad3-5fd74b7c60c9`, resolves to **Member of Technical Staff, Infrastructure & Operations**.

The documents therefore carry the real title. Applying under a title the company does not use would be a small,
avoidable mistake at the first screen.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Daily Nix, packaging and environment work | 1,400-file flake, 13 hosts, modules and overlays, `nix build` as the only path | **core match** |
| Hermetic, reproducible builds | `flake.lock` pinning, derivation identity, rebuild-from-lock discipline | **core match** |
| Release engineering, rollback | Generation switch, parent pointer, one-command rollback | **core match** |
| Binary cache and remote builders | Substituters and builders as configuration; cache-miss triage | strong |
| CI that matches the machine | Inventory-driven matrix, per-host module gate, same check locally | **core match** |
| Linux systems depth | systemd, cgroups/PSI, nftables, `tcpdump`, `strace` | strong |
| Monitoring and alerting | Fifteen-minute sentinel over job, generation, disk and PSI | strong |
| AWS | **bare metal, no AWS** | **gap** |
| Upstream Nixpkgs / public cache at scale | **none** | **gap** |
| Go / Python for tooling | Go service with tests, Python tooling, Bash | strong |
| Remote, no sponsorship | Germany, permanent residence, C1 German, native English | fulfilled |

## The argument the letter makes

Most companies ask a candidate to learn Nix for their infrastructure; Flox *is* the infrastructure, so the question is
whether the working style survives contact. The letter answers with the repository rather than adjectives: one flake for
thirteen hosts, hosts as feature lists, inputs pinned in a lock file, deployment as a rebuild and a generation switch,
rollback as a parent pointer — plus the parts that decide whether a Nix platform is pleasant or miserable: cache and
remote builders, cache misses as events, an inventory-driven CI gate that cannot disagree with the host, and a sentinel
that treats silence as a fault.

Two gaps named: no Nixpkgs work, no public cache at that scale, no AWS. Framed as the reason to apply — learning those
from people who have solved them, at thirteen machines rather than pretending otherwise.

## Form notes (from the 2026-11-21 recon)

Six fields, four required: Name, Email, Phone, Resume, LinkedIn, optional cover letter upload. There is **no** salary,
location, start-date, sponsorship or free-text field — those facts belong in the first human reply.

| Field | Value |
| :--- | :--- |
| Name | Matt Ji (legal name Shaoyan Ji) |
| Email | matt\@bountystash.com |
| Phone | +49 1733281570 |
| Resume | `lebenslauf.pdf` (2 pp) |
| LinkedIn | https://linkedin.com/in/mattji |
| Cover letter | `anschreiben.pdf` (1 p) |
| Citizenship / permit | US citizen, unbefristete Niederlassungserlaubnis, no sponsorship |
| Start | immediately |
| Salary | 210,000 USD — inside the published 180K–250K band |
| Location | Gutach im Breisgau, Germany |

Trap: ignore the "Autofill from resume" upload at the top of the form — it parses the PDF and can overwrite the fields
typed by hand.

## Checks

| Check | Result |
| :--- | :--- |
| Legacy PDFs, `selection.json`, `.txt` files | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `flake.lock`, `binary cache`, `rollback`, `generation` |
| Markers letter | `Member of Technical Staff`, `Nixpkgs`, `cache misses`, `nixconfig` |
| `task checks:prose` | 245 prose files, exit 0 |
| sha256 CV | `93c99e161d92edf31fd38513197885c447d4456d4d4bd7bc44b5db077cc0a78f` |
| sha256 letter | `5c0b70e4009d51bfd4acff708bf2c31f2b2ef70d90579cabbc728cca4af8114c` |
| DB read-back | verified after upsert |

## Next steps

1. Submit through the Ashby form; upload both PDFs rather than pasting text.
2. Lead with the repository — the interviewer can read it, which few candidates can offer.
3. Ask how cache trust and signing are handled across customer environments; that is where Flox's hard problems live.
