# Submission sheet — Nebius, Senior System Engineer (CloudGate)

Role `nebius-cloudgate` · Greenhouse **4377696101** · https://careers.nebius.com/?gh_jid=4377696101
Published 2024-08-27 · Amsterdam, Netherlands; Remote - Europe
Target compensation **EUR 110,000 – 135,000** (ask EUR 115,000 – 130,000). No band published.

## What the role actually is

CloudGate owns the software side of Nebius external connectivity: IPv4 connectivity, Cloud Interconnect, egress NAT and a network load balancer, at tens of millions of packets per second. Data plane in C, control plane in gRPC microservices, coding interview included. Bonus: VPP, DPDK, Linux kernel network subsystem, overlays/SDN/NFV, BGP/MPLS.

## Live Greenhouse fields (14 server-side labels)

| Field | Answer |
| :--- | :--- |
| First Name * | Matt |
| Last Name * | Ji |
| Email * | matt@bountystash.com |
| Country * | Germany |
| Phone * | +49 1733281570 |
| Location (City) * | Gutach im Breisgau (Freiburg area) — available for Amsterdam or remote across Europe |
| Attach | CV: lebenslauf.pdf; letter: anschreiben.pdf. This Greenhouse form has no cover-letter slot; the letter is kept in the packet and its content is repeated in the sheet. |
| Enter manually | n/a — files attached |
| LinkedIn Profile | https://linkedin.com/in/mattji |
| Which languages do you speak? * | English (native), German (C1, verhandlungssicher) |
| Are you currently authorized to work in the country where this position is located, without requiring sponsorship, now or in the future? * | Yes. US citizen with German permanent residence (unbefristete Niederlassungserlaubnis); unrestricted in Germany, the EU and the US, no sponsorship required now or later. |
| Do you currently reside in the location specified for this role? * | Yes for Germany/remote Europe — resident in Gutach im Breisgau. Not resident in Amsterdam. |
| Have you ever been employed by Nebius before? * | No |
| I have read Nebius’s Candidates Privacy Policy. * | Yes |

## Preflight checklist

- [ ] Attach `lebenslauf.pdf` (2 pages) to the Attach field.
- [ ] Attach `anschreiben.pdf` (1 page) where a letter can be added; otherwise paste the Additional context block.
- [ ] Country = Germany; Location = Gutach im Breisgau, with Amsterdam/remote noted.
- [ ] Authorization = Yes; state unbefristete Niederlassungserlaubnis and US citizenship.
- [ ] Reside in location = Yes for Germany/remote; not Amsterdam.
- [ ] Prior Nebius employment = No; privacy policy = Yes.
- [ ] Confirm salary answer matches EUR 115,000 – 130,000 ask.
- [ ] Nothing submitted until reviewed.

## Additional context (letter content)

Applying for CloudGate: external connectivity at tens of millions of pps, where the data plane must be correct before it is fast. My work sits at the kernel/network boundary — a 13-host NixOS fleet built hermetically from one flake with canary-verified changes and one-command rollback; microVMs for isolation with a real boundary; nftables and WireGuard routing; proxy and relay paths where connection state, timeouts and backpressure matter; C for low-level tooling with explicit allocation and lifetime, Go for services.

## Boundaries, stated plainly

- No VPP or DPDK experience.
- No eBPF programs in production (the repo contains none — a real gap, not modesty).
- No BGP, MPLS, SDN control-plane or NFV work.
- Traffic handled is fleet-scale, not tens of millions of pps through a purpose-built data plane.
- Coding interview is a gate; C is used here for tooling, not as years of forwarding-plane work.

## selection.json

Standard engineering evidence (`projects.kept`: nixconfig, email-archive, bountystash, fibtransponder), plus `greenhouse` (all {len(labels)} live field mappings), `compensation`, and `candidate` blocks.

Nothing submitted. No account created.
