# Nebius — Senior/Staff Site Reliability Engineer (Server Infrastructure)

Server Infrastructure SRE · Amsterdam · **Berlin** · Finland · London · Prague · Remote · full time.
Greenhouse job `5040922101`, posted 2026-11-18, valid through 2026-12-31.
**Nebius publishes no band.** EUR 130,000–160,000 is the applicant's staged target, not an offer.

## The stage question, answered rather than assumed

Two records disagreed. The retired `Nebius_SRE_Submission_Sheet.txt` said **"READY TO SUBMIT … nothing sent."** The apps DB says **applied**
2026-11-21 with a Greenhouse confirmation code. The DB is the ledger that logs confirmations, so this packet is treated as **applied** and the
documents are a faithful rebuild for the CV screen or a resend — but the contradiction is recorded here rather than smoothed over, because a
sheet that says "not sent" and a database that says "sent" cannot both be right.

The DB also carries a `rejected` row for the same requisition (`…-server-infra`, "duplicate of applied 5040922101"), which is the correct
disposition: one application, two rows, one of them dead.

## Provenance

**No job description on file.** `job-description.txt` is reconstructed from the retired sheet, which verified the Greenhouse API, the official
apply page and the fields on 2026-11-21. Faithful to that verification; not a fresh fetch. The instruction's title is *Site Reliability Engineer
/ Infrastructure*; the requisition's own title is *Senior/Staff SRE (Server Infrastructure)*, which is what the documents use — no drift to
reconcile here, unlike the other Flox folders.

Native English Typst, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1261 | 0 | `d89d22b6a64e96fa` |
| `anschreiben.pdf` | 1 | 481 | 0 | `bcf87b7d5b69e92c` |

Plus both `.typ` sources, `job-description.txt` and this sheet. Retired: `Matt_Ji_Resume_Nebius.pdf` (`362a52b9dc0828f9…`), `Nebius_Cover_Note.pdf`
(`49c5101d5f558dc3…`), `Nebius_Cover_Note.txt`, `Nebius_SRE_Submission_Sheet.txt`.

## The four pillars, and what the corpus actually holds

| Pillar | Evidence | In the documents as |
| :--- | :--- | :--- |
| Large-scale Linux infrastructure | systemd units/sockets/timers, cgroups, PSI, journald, SMART/NVMe, ZFS, PXE/iVentoy, thirteen hosts from one flake | claimed — at honest scale, "small fleet run the way a large one has to be" |
| **Low-latency GPU observability** | **A GPU host serving inference with a guard that yields the card to a human; `nvml` and DCGM appear nowhere in the repo** (verified by grep) | **stated as a gap** — contention learned, GPU health telemetry not |
| Network observability | Default-deny nftables, WireGuard/Tailscale transit, an MTU fault isolated by path, tcpdump/strace habits, gatus checks | claimed in full |
| Declarative fleet management | Pinned inputs, feature-list hosts, options with types and assertions, one evaluation gate per host | claimed in full |
| Automated cluster operations | Typed task surface with dry runs and JSON, CI gate equal to the machine's gate, canary microVM, rollback by pointer | claimed in full |

That `nvml`/DCGM grep is why the CV says "contention but not DCGM" instead of writing "GPU observability" on the skills grid and hoping. A GPU
infrastructure team will ask what you would instrument on a node; the answer here starts from PSI, SMART and the inference host's own load
rather than from a tool the packet cannot point at.

## Gaps, in both documents

No thousands-of-servers scale. No GPU fleet, no DCGM/NVML telemetry. No SaltStack, Terraform, IPMI or Redfish in production. Kubernetes familiar
rather than deep. No formal cloud-platform SLO ownership — health gates and alerting instead. (One adjacent fact left out of the CV because it
would overstate: `hosts/cassini` configures an RDMA-capable NIC; that is a hardware definition, not InfiniBand operations experience.)

## Fit and route

**3 of 5.** The lifecycle, the declarative fleet, the observability discipline and the automation are real and inspectable; the scale, the GPU
telemetry and the formal SRE ownership are the gaps, and the posting is written for someone who has already had them.

**Location:** Germany is explicitly listed (Berlin / Remote), so the Greenhouse "do you reside in the specified location" answer of *Yes* holds.

**Compensation:** EUR 130,000–160,000 staged and named in the letter. Unlike the Flox packets this one keeps the figure, because the letter was
already submitted with it and silently dropping it in a rebuild would change the offer signal. Nothing published by Nebius to contradict it.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| `**` in sources | 0 |
| DCGM/NVML/SaltStack/Terraform/IPMI/Redfish claimed | 0 in the CV; all appear only inside the gap paragraph |
| `task checks:prose` | exit 0 |
| Legacy artefacts | all four removed in the same commit |
