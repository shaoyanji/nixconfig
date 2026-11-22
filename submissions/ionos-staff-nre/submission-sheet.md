# IONOS SE — Staff Network Reliability Engineer (f/m/d), Karlsruhe

**This requisition is live.** Checked 2026-11-22: Greenhouse board `ionos2`, job `4971782101`,
`updated_at 2026-10-28T08:31:43-04:00`, `?content=true&questions=true` returns the full advert
plus **15 application questions**. Apply now, while it is open — the previous IONOS req this
packet series covered (`4956693101`, SRE Application Hosting) is gone.

| | |
| :--- | :--- |
| Role ID | `ionos-staff-network-reliability-engineer-karlsruhe` |
| Requisition | Greenhouse `ionos2` / `4971782101` |
| Apply URL | https://job-boards.eu.greenhouse.io/ionos2/jobs/4971782101 |
| Office | Hinterm Hauptbahnhof 3-5, 76137 Karlsruhe — hybrid, remote Germany |
| Team | NRE Operations: physical fabric, SDN overlay, virtual network functions, dozens of data centers |
| Level | senior or staff (5+ years for Senior, longer for Staff) |
| On-call | yes, shared rotation |
| Vetting | **SÜ2** under §10 SÜG (voluntary question, but the role requires it) |
| Language | fluent English required, German a plus |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence (`Niederlassungsrecht`) — no sponsorship needed |
| Distance to Karlsruhe | ~130 km door to door |
| Compensation target | 105.000 – 130.000 EUR; letter states **120.000** |
| Start | immediate or by agreement |
| Web | https://matt.bountystash.com |

## Fit map

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| Define what "healthy" means; catch problems before customers | Sentinel ledger every 15 min (job status, generation age, disk, PSI), gatus pages on `[BODY].state != ok`; a green socket is explicitly not a finished job | strong |
| Lead hard incidents, run postmortems that produce lasting fixes | Single-operator fleet: every incident is mine end to end; xs turn log, `AGENTS.nix` decisions and `docs/history/` are the postmortem record | partial — no incident commander across teams |
| Remove toil through automation | Gates that fire in CI and on the host, one task per procedure, Go and Python behind `scripts/task/` | strong |
| Strengthen observability | Same ledger + gatus; pressure-stall and disk instrumentation rather than dashboards nobody reads | strong |
| Deep L2/L3: BGP, OSPF, VXLAN with BGP/EVPN | Not operated in production, and the letter says so | **gap** |
| Multi-vendor Juniper and Cisco; SONiC, Netbox a plus | No hands-on history in any of the four | **gap** |
| Strong Linux fundamentals and toolkit (bash, tcpdump, iptables, git) | NixOS/Linux daily, tcpdump and MTU/DNS diagnosis, nftables (the iptables successor), git as the only change path | strong |
| Network automation with Python, Ansible, GitLab CI | Python and Go automation, CI gating on the config repo; **no Ansible, no GitLab CI** | partial |
| WireGuard / encrypted mesh operations | Hosts joined in a WireGuard-based mesh (Tailscale), SSH through an own CA with short-lived certificates | strong (mesh, not carrier routing) |
| systemd, cgroups, resource pressure | systemd units, per-slice memory limits, PSI and OOM behaviour drive the alerting | strong |
| Reliability mindset: SLOs, change management, capacity | Immutable generations, rollback as a pointer, change only through one module gate; **no formal SLO programme** | partial |
| Fluent, critical use of AI in daily work | Agent tooling in daily use with a standing rule that no model authorises an action | strong |
| Scale: dozens of DCs, 6.2M customers | 13 hosts and one mail archive | **gap**, stated plainly |

## Application form — exact Greenhouse questions

Fetched from `boards-api.greenhouse.io/v1/boards/ionos2/jobs/4971782101?questions=true`.
Labels are verbatim; field names use the standard Greenhouse `job_application[...]` form,
where custom questions are addressed as `question_<id>` with the id from that payload.
Answer column is what to type, not what is already typed.

| # | Question (verbatim) | Field | Answer | Note |
| :-- | :--- | :--- | :--- | :--- |
| 1 | First Name | `job_application[first_name]` | Matt | required |
| 2 | Last Name | `job_application[last_name]` | Ji | required |
| 3 | Email | `job_application[email]` | matt@bountystash.com | required |
| 4 | Phone | `job_application[phone]` | +49 173 3281570 | required |
| 5 | Resume/CV | `job_application[resume]` | `lebenslauf.pdf` (required) | required |
| 6 | Cover Letter | `job_application[cover_letter]` | `anschreiben.pdf` (optional, but this packet has one) | optional |
| 7 | How did you hear about this position? | `job_application[question_None]` | IONOS careers page (Greenhouse board) | required |
| 8 | What is your current notice period? | `job_application[question_None]` | Sofort bzw. nach Vereinbarung (Eintritt spätestens 01.01.2027) | optional |
| 9 | What are your yearly salary expectations for this role? | `job_application[question_None]` | 120.000 EUR brutto jährlich | required |
| 10 | This role requires an extended security vetting process (SÜ2) in accordance with § 10 SÜG. Are you willing to consent to and actively participate i... | `job_application[question_None]` | Ja, Bereitschaft zur SÜ2-Überprüfung. Hinweis: US-Staatsbürger mit deutschem Niederlassungsrecht, Verfahren kann laenger dauern. | optional |
| 11 | If you do not live in Karlsruhe, would you be willing to relocate? | `job_application[question_None]` | Nein, Umzug nicht geplant: Karlsruhe liegt ca. 130 km entfernt, regelmäßige Präsenz ist machbar. | required |
| 12 | Do you have a work permit to work in the country in which the role is based? | `job_application[question_None]` | Ja: unbefristetes Niederlassungsrecht in Deutschland, kein Sponsoring nötig. | required |
| 13 | Would you agree to us forwarding your application documents to other departments? | `job_application[question_None]` | Ja | optional |
| 14 | Have you worked at IONOS in the past? | `job_application[question_None]` | Nein | optional |
| 15 | I agree that my application documents and personal data may be kept in the IONOS talent pool for max. 2 years (revocable at jobs@ionos.com) | `job_application[question_None]` | Ja | required |

Landing-page path: `job-boards.eu.greenhouse.io/ionos2/jobs/4971782101` → **Apply for this job**
→ single-page form with these fields → attach `lebenslauf.pdf` and `anschreiben.pdf` → submit.
The page renders client-side; use `agent-browser` if it must be driven.

## Open points before submitting

- **SÜ2 as a US citizen.** Consent is the right answer and the letter commits to it, but the
  vetting for a non-EU national can take longer and may need documents from the US. Say yes,
  do not promise a timeline.
- **Notice period** is not a fact in the record; the staged answer says immediate or by agreement.
  Confirm before submitting if that is wrong.
- **Relocation** is answered "no" with commuting offered instead — 130 km is a real commute,
  so pair it with the hybrid question rather than leaving it bare.
- Salary: 120.000 sits inside the 105.000 – 130.000 band and matches the letter.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 185 prose files, exit 0 |
| selection | 0/32 highlights, 2/10 projects |
| sha256 CV | `5ea87a117a69dc942cda6727f2c831104d528ae36d99cb711cf963f3cf1760a6` |
| sha256 letter | `49d2e940a895ca375373cbbcc0b9aa27f39e07c88c07b6a5998fa631d68b29c1` |

## Next actions

1. Submit through the Greenhouse form above, attaching both PDFs.
2. Reuse the answers block verbatim — the salary and SÜ2 questions are the two that get read.
3. If IONOS replies about the earlier closed req instead, point at `4971782101`.
