# Flox — Member of Technical Staff, Security

Remote (posting carries a US address) · full time · **first dedicated security hire** ·
**USD 160,000–210,000 base + equity** (Ashby, published 2026-04-28, still listed 2026-11-21).

**Nothing was submitted.** The retired sheet said "READY TO SUBMIT … nothing sent". The DB row said `applied`; it is now `prep`, because
that is what happened.

## Provenance

1. **No job description on file.** `job-description.txt` is reconstructed from the retired `Flox_Security_Submission_Sheet.txt`, which
   verified the live Ashby posting and the rendered application form on 2026-11-21. Faithful to that verification, not a fresh fetch.
2. **The requisition is titled "Security Engineer"** — Ashby `37ec9578-4fab-432f-88f1-c130ffe13ac8`. This dossier is addressed to the
   instruction's title, **Member of Technical Staff, Security**; same role, first security hire. If the live posting keeps "Security
   Engineer", the letter's subject line is the single line to change.
3. **The compensation discrepancy is real and recorded in the retired sheet:** a staging brief said 180–250k, the live Ashby posting said
   160–210k + equity. The live posting wins, and it is what both documents and this sheet use.

Native English Typst, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1196 | 0 | `d064d7c60344e9ac` |
| `anschreiben.pdf` | 1 | 485 | 0 | `9c6ccc1ae4ce6796` |

Plus both `.typ` sources, `job-description.txt` and this sheet. Retired: `Matt_Ji_Resume_Flox_Security.pdf` (`a20291aa499cdee5…`),
`Flox_Security_Cover_Note.pdf` (`d711a3af33e4e855…`), `Flox_Security_Cover_Note.txt`, `Flox_Security_Submission_Sheet.txt`.

## What the corpus actually supports, checked before writing

The instruction named five pillars; four are evidenced and one is not, so the gap is written rather than filled.

| Pillar | Evidence in the repository | In the documents as |
| :--- | :--- | :--- |
| Software supply-chain security | Pinned flake inputs and submodules; asset filter excluding `^sbom`/`.proof`/`.zsync`; `sha256` pins confirmed before install; linkage check; no `curl \| sh` | claimed in full |
| Hermetic builds | Sandbox with network closed, content-addressed output, shared cache, generation as a pointer | claimed in full |
| **SBOM generation** | **No CycloneDX or SPDX emitter, no grype/trivy/osv-scanner anywhere in the flake** — `sbom` appears only as a filter token in `tools/library.nix` and `scripts/task/library-fetch.sh` | **stated as a gap**, with the store closure named as the half that exists |
| Vulnerability scanning | CISA KEV as a time series, effort clusters with exposure, bug-bounty audits; vulnerability operations concept on labelled sample data | claimed in full |
| Cryptographic verification | sops to per-host age keys with rekeying; own SSH CA issuing short-lived host certificates with listable principals; `sha256` digests as the install gate | claimed in full |
| — | **No cosign, sigstore or SLSA provenance** — verified by grep, zero hits | stated as a gap |

That is the difference between this packet and the retired one: the retired cover note said "I have studied SLSA rather than shipped it",
which was honest but left the SBOM question unasked. This one answers it in the letter's fourth paragraph, because a security-hire
interview asks it in the first ten minutes.

## Gaps, in both documents

No SBOM emission (CycloneDX/SPDX) and no scanner in the pipeline. No cosign/sigstore, no SLSA provenance shipped. No AWS hardening depth
(IAM/SCP, GuardDuty, Security Hub, CSPM). No Cloudflare Zero Trust — zero-trust access here is Tailscale plus an SSH CA. No EDR/MDM, no
SIEM/SOC operation. The retired cover note named the last three; this packet keeps all of them.

## Fit and route

**3 of 5.** Deep on the exact axis the product lives on — build graph, pinned inputs, hermetic builds, artefact identity, secrets and
certificates — and thin on the first-hire checklist the posting writes out (AWS hardening, Cloudflare, EDR, SOC).

**Location risk, unresolved:** Remote, but attached to a United States address, and Flox has advertised US-remote hiring before. A US
citizen resident in Germany is not automatically payable on a US-remote arrangement; payroll and work-location eligibility are separate
questions. The letter asks; the sheet treats it as a pre-submit blocker.

**Compensation:** USD 210,000 base + equity staged as the target, top of the published band. Not volunteered in the letter — the retired
draft did volunteer it and this one does not. Availability 01.12.2026, US hours from Germany.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| `**` in sources | 0 |
| Unsupported claims (CycloneDX/SPDX/grype/trivy/cosign/sigstore/SLSA) | 0 outside the gap paragraphs |
| Salary in letter | 0 mentions |
| `task checks:prose` | exit 0 |
| Legacy artefacts | all four removed in the same commit |
