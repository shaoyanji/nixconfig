# Nebius — Senior Site Reliability Engineer (SRE, Compute Node Team)

**Status: prepared, NOT submitted.** 2026-11-21. No account created, nothing sent.

Nebius (Nasdaq: NBIS), Compute Node team inside AI Cloud. Locations offered: **Amsterdam and Remote Europe only — Germany is not a listed location**, which matters for the authorization answer. Requisition live since **2026-01-26**, refreshed 2026-11-18: a ten-month-old search. No compensation published.

The team runs the cluster scheduler and node-level services behind VMs across all cloud regions: Linux kernel and hypervisor close work, QEMU/KVM, cgroups and namespaces, NUMA, observability embedded in the node layer.

## Files

`lebenslauf.pdf` (2 pages, English), `anschreiben.pdf` (1 page, English), `selection.json` (15/25 highlights, 4/4 projects: nixconfig, email-archive, bountystash, fibtransponder), `job-description.txt`, this sheet.

## The angle: the layer where the guest meets the host

The letter is written for a team that debugs across user space and kernel space: each host pins its kernel track and kernel parameters, each service is a systemd unit with defined failure behaviour, and a whole generation rolls back in one command. When a host misbehaves, the question is which layer lied — user space, the unit, the kernel parameter, or the declaration that produced it.

The isolation paragraph is the strongest concrete match: microVMs on KVM behind a bridge with udev-attached taps and NAT, and a canary host proving a configuration before the rest of the fleet switches. Observability is presented as built rather than consumed: sentinel every fifteen minutes with job status, generation age, disk and PSI pressure, node_exporter behind it, alerts to a human, runbooks as text.

## The gaps, stated in the letter

- **No QEMU/KVM internals or live migration at scale**; microVM operation is real but small.
- **No NUMA or cgroup v2 tuning** beyond systemd defaults.
- **No perf, eBPF, ftrace or kernel crash-dump debugging** in production.
- **No GPU, NVLink, InfiniBand or BMC/IPMI hardware lifecycle** — the posting lists these as nice-to-have, not required.
- Kernel experience is deep configuration and operations, not hypervisor development.

## Compensation

Ask **EUR 130,000 – 160,000**. No band is published; only "competitive compensation". The ask is anchored to the German market on a Remote-Europe contract.

## Application route and live form

- Posting: https://careers.nebius.com/?gh_jid=4766627101 (Greenhouse job **4766627101**)
- Embedded form: https://boards.greenhouse.io/embed/job_app?for=nebius&token=4766627101
- Greenhouse API confirms the title, the two-location list, `first_published 2026-01-26`, `updated_at 2026-11-18`.

The embedded form renders server-side; these are **16 real field labels** from the live page:

| Live Greenhouse field | Answer |
| :--- | :--- |
| First Name * | Matt |
| Last Name * | Ji |
| Preferred First Name | Matt |
| Email * | matt@bountystash.com |
| Country * | Germany |
| Phone * | +49 1733281570 |
| Location (City) * | Gutach im Breisgau |
| Attach | `lebenslauf.pdf` (2 pages) |
| Enter manually | only if the resume parser mangles the dates |
| LinkedIn Profile | https://linkedin.com/in/mattji |
| Website | https://www.bountystash.com |
| Which languages do you speak? * | English (native), German (C1) |
| Are you currently authorized to work in the country where this position is located, without requiring sponsorship, now or in the future? * | Yes for Germany: US citizen with unbefristete Niederlassungserlaubnis, no sponsorship now or later. I am applying to the Remote-Europe location; a Dutch contract would need a permit, so Amsterdam is not my target. |
| Do you currently reside in the location specified for this role? * | Yes — Gutach im Breisgau, Germany; applying to the Remote-Europe location. |
| Have you ever been employed by Nebius before? * | No |
| I have read Nebius's Candidates Privacy Policy. * | read and accept |

The authorization answer needs care: the question asks about "the country where this position is located", and the location list is Amsterdam plus Remote Europe. The sheet answers yes for Germany and applies to Remote Europe; a Dutch contract would need a permit, because the German Niederlassungserlaubnis is national.

There is no cover-letter upload and no free-text field. If the letter has nowhere to go, compress the isolation paragraph (microVMs, canary) into any additional-information box.

## Verification

- `pdfinfo`: CV 2 pages, letter 1 page, both A4, Typst-compiled.
- Both page budgets passed; no spillover error.
- No placeholders (`{`, TODO, XXX, FIXME) in either PDF.
- Letter contains: EUR 130,000, EUR 160,000, Niederlassungserlaubnis, microVM, QEMU, PSI.
- Selection: 15/25 highlights, 4/4 projects, all four requested evidence projects kept.
- JD written from Greenhouse's API as plain text, 0 HTML tags.
- DB row: `nebius-senior-site-reliability-engineer-sre-compute-node-team`, `stage=prep`, `status=prep`, `fit=3`, `folder_path=submissions/nebius-compute-node`.
