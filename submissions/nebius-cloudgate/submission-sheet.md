# Nebius — Senior System Engineer (CloudGate)

Greenhouse **4377696101** · Amsterdam, Netherlands; Remote — Europe · CloudGate team, the software side of external connectivity: IPv4, Cloud
Interconnect, egress NAT and a network load balancer, at tens of millions of packets per second. Control plane in gRPC microservices, data plane in C,
coding interview included. **No band published**; target EUR 110,000–135,000, ask EUR 115,000–130,000.

**Status: prepared, not submitted.** The 2026-11-21 attempt filled the form completely and then stopped at **Cloudflare Turnstile**, which never issued a
token — the same environment-bound failure recorded for `nebius-sre-berlin`. One click in a normal browser finishes it; the DB row is therefore `prep`,
not `applied`.

## Legacy packet, now genuinely in git history

All five files were **untracked**, so they were committed unchanged first (`appflow(nebius-cloudgate): stage the pre-Typst packet`) and retired in the
rebuild commit:

| Artefact | sha256 (first 16) | What it was |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | `74dd951062886f22…` | Nix-built CV, "Site Reliability Engineer", three fleet bullets |
| `anschreiben.pdf` | `744b36141b3384bc…` | Nix-built letter, salutation "Dear Nebius Compute Node team" — wrong team |
| `selection.json` | `ae89da322b45f2db…` | selector output plus form mappings |
| `submission-sheet.md` | `4d5e3a52e69e9d00…` | the 2026-11-21 sheet, this file's predecessor |

`job-description.txt` is kept unchanged: a real capture of the posting (posted 2024-08-27, refreshed 2026-11-18), not a reconstruction.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1270 | 0 | `6bd5b1539d2a00bc` |
| `anschreiben.pdf` | 1 | 454 | 0 | `7fb579ff5b56ba03` |

## The five pillars, against the repository

| Pillar | Evidence | In the documents as |
| :--- | :--- | :--- |
| nftables default-deny filtering | NixOS firewall default-deny generated from a per-service table (`hosts/frieren/firewall-scope.nix`) with `lan`/`tailnet` booleans and dated prunes (CUPS 631 pruned 2026-10-12, uptime-kuma 3001 on 2026-11-04); `modules/net/dns/failover.nix` adds an nftables `extraInputRules` VRRP accept | claimed in full, including the reason the rule lives in the firewall's start path |
| WireGuard mesh routing | Tailnet-scoped service rows; NFS over the mesh when a laptop leaves the LAN ("measured fallback, not a guess"); 41641 open for the direct path; explicit note that broadcast, multicast, DHCP and PXE cannot cross a mesh | claimed in full |
| NAT and bridge forwarding | `modules/profiles/microvm-host.nix`: NM-owned `brlan` with gateway address, STP off, forward delay 0; udev rule attaching `microvm*` taps because the dispatcher never sees an unmanaged interface; `networking.nat` bridge to uplink; bridge trusted at the edge | claimed in full |
| MTU troubleshooting | **No `mtu`, `mss` or clamp configuration exists anywhere in the repository** (verified by grep; the only hits are a `nmcli` comment, a base64 hash and CSS `clamp()`). The claim is a **diagnostic method** — counters, `tcpdump` and the MTU per hop — not a shipped configuration, and both documents word it that way | claimed as method, flagged here |
| Network telemetry | gatus checks with thresholds, `fleet-monitors`, service portal, `fleet-sentinel` ledger writing job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence | claimed in full |

That fourth row is the honest seam in this packet. Writing "MTU tuning" on a CloudGate CV would be a lie a network engineer catches in one question; writing
"MTU by path" and saying where the antenna stops is the version that survives the call.

## Gaps, in both documents

No VPP or DPDK. No eBPF programs in production. No BGP, MPLS, SDN control plane or NFV. Traffic is fleet-scale, not tens of millions of packets per second
through a purpose-built forwarding plane. C is tooling with explicit allocation and lifetime, not years inside a forwarding plane. Those words appear in the
CV only inside the paragraph declining them.

## Route

Fourteen live Greenhouse labels, **no cover-letter slot** — the letter goes in the application email or the Additional-context block. Country Germany,
location Gutach im Breisgau with Amsterdam/remote noted; authorization yes (US citizen, unbefristete Niederlassungserlaubnis, no sponsorship now or later);
prior Nebius employment no.

**Compensation:** EUR 115,000–130,000 is the ask and it stays in the sheet, not the letter. Nothing was submitted, so there is no prior figure to keep
consistent, and Nebius publishes no band.

## Two DB rows, one job

`nebius-cloudgate` is the canonical row (this packet). `nebius-senior-system-engineer-cloudgate` came from the Greenhouse scouting crawl for the same
requisition; it is annotated as the duplicate rather than merged, because deleting a row loses the crawl provenance.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page (asserted before commit) |
| `**` in sources | 0 |
| Curly quotes | 0 |
| Unsupported claims (VPP/DPDK/eBPF/BGP/MPLS/NFV) | 0 outside the gap paragraph |
| MTU claimed as configuration | 0 — method only, and the sheet says why |
| `task checks:prose` | exit 0 |
| Legacy artefacts | staged first, retired in the rebuild, hashes above |
