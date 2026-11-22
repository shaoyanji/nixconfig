# Nebius — Senior Site Reliability Engineer (SRE, Compute Node Team)

Greenhouse **4766627101** · Cornerstone: Compute Node team inside AI Cloud. **Amsterdam and Remote Europe only — Germany is not a listed
location**, which is the one answer on the form that can end this application. Requisition live since 2026-01-26, refreshed 2026-11-18: a
ten-month-old search. No compensation published; EUR 130,000–160,000 is the applicant's target.

## Stage: the two records disagree, again

The sheet this rebuild replaces said **"prepared, NOT submitted. No account created, nothing sent."** The apps DB says **applied** 2026-11-21 with a
Greenhouse confirmation. The ledger that logs confirmations is the stronger record, so the row stays `applied` and both documents are a faithful
rebuild for a screen or a resend — but the contradiction is written down here rather than smoothed over, exactly as with `submissions/nebius`.

## Legacy packet, now genuinely in git history

These files were **untracked**, so deleting them in the rebuild commit would have destroyed them. They were therefore committed unchanged first
(`appflow(nebius-compute-node): stage the pre-Typst packet`) and retired in the second commit:

| Artefact | sha256 (first 16) | What it was |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | `a3e473a7bfcbcb9c…` | Nix-built CV, 15/25 highlights, English |
| `anschreiben.pdf` | `6da8e7a2fef01e17…` | Nix-built one-page letter |
| `selection.json` | `8ffd5d3742f571a9…` | JD selector output (15/25 highlights, 4/4 projects) |
| `submission-sheet.md` | `99755731bdf8d394…` | the 2026-11-21 sheet, this file's predecessor |

`job-description.txt` is kept unchanged: it is a real capture of the posting, not a reconstruction.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1255 | 0 | `1d9e26915262bac3` |
| `anschreiben.pdf` | 1 | 475 | 0 | `185173308377ab38` |

## The four pillars, against the repository

| Pillar | Evidence | In the documents as |
| :--- | :--- | :--- |
| microVM orchestration on KVM | `hosts/microvms/`: `microvm.nix` with cloud-hypervisor, vsock cid, tap `microvm1` on `brlan` with NAT, read-only virtiofs store plus writable overlay, separate `/var` volume, ssh host key from a persistent share, explicit TCG fallback where `/dev/kvm` is absent | claimed in full — the centre of the packet |
| Host/guest boundary isolation | Guest firewall off because the host owns the bridge; the guest imports no host chain and carries none of the host's service tier; default-deny nftables between hosts | claimed in full |
| Canary host rollout | A guest with its own kernel and root exercises a configuration or a runbook before a fleet does; per-host evaluation gate refuses before an installer | claimed in full |
| Node observability via PSI and sentinel | `fleet-sentinel`: job state, generation age, disk and pressure stall information per resource every fifteen minutes; `node_exporter` behind dashboards; gatus paging on silence | claimed in full |

## Gaps, in both documents

No QEMU or cloud-hypervisor internals, no live migration at scale. No NUMA placement or cgroup v2 controller tuning beyond systemd defaults. No perf,
eBPF, ftrace or kdump in production. No GPU, NVLink, InfiniBand or BMC/IPMI hardware lifecycle. Guest counts are single digits, not thousands. Those
terms appear in the CV only inside the paragraph declining them.

## Route and the location question

The form has sixteen live fields and **no cover-letter upload**, so the letter travels in the application email or the first human reply. Germany is
not among the listed locations; the letter says plainly that the application is for Remote Europe or Germany and not Amsterdam, and that reading needs
confirming before an offer, not after.

**Compensation:** EUR 130,000–160,000, named in the letter because the earlier version carried it and quietly dropping a figure in a rebuild changes
the signal.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page (asserted before commit) |
| `**` in sources | 0 |
| Curly quotes | 0 |
| Unsupported claims (live migration/NUMA/cgroup v2/perf/eBPF/ftrace/kdump/InfiniBand/IPMI) | 0 outside the gap paragraph |
| `task checks:prose` | exit 0 |
| Legacy artefacts | staged first, retired in the rebuild, hashes above |
