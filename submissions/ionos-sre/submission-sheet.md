# IONOS SE — Site Reliability Engineer (f/m/d) – Application Hosting, Karlsruhe

**Status: packet built 2026-11-22 against a CLOSED requisition.** Do not submit this link: the
posting is gone. The packet is an archive artifact and the base for a speculative application or for
the live SRE roles listed below.

## The posting is closed — verified four ways

| Check | Result |
| :--- | :--- |
| `job-boards.eu.greenhouse.io/ionos2/jobs/4956693101` in a browser | redirects to `/ionos2?error=true`, page text: *"The job you are looking for is no longer open."* |
| Live board `ionos2` (Greenhouse API, `?content=true`) | **60 jobs**, `4956693101` **absent** |
| Live board `ionos` (the German duplicate, `4956674101`) | **49 jobs**, both `4956674101` and `4956693101` **absent**; that URL also lands on `?error=true` |
| IONOS career pages (`jobs.ionos.de/...4956693101...`, `ionos-group.com/...4956693101...`) | **404**; Arbeitsagentur mirror `10001-1003577914-S` → **410 Gone** |

The job-description file therefore carries a provenance header saying exactly this, and its text is
the recovered content of the same requisition (Application Hosting SRE, Managed Nextcloud / Nextcloud
Workspace / IONOS GPT on the Kubernetes platform), not text lifted from a live page.

## Live IONOS alternatives (checked the same day, from the board API)

| Requisition | Title | Location |
| :--- | :--- | :--- |
| `5036214101` | Associate Site Reliability Engineer (f/m/d) | Berlin — level below target |
| `4988144101` | Staff Site Reliability Engineer (f/m/d) | Berlin — level above, no Karlsruhe |
| `4971782101` | Staff Network Reliability Engineer (f/m/d) | **Karlsruhe** — network specialism |
| `4706356101` | Staff Reliability Engineer (f/m/d) Ceph Storage Platform | Berlin |

If IONOS is still the target, `4971782101` is the only Karlsruhe SRE-shaped live req, and it is a
staff-level network role — a different application, not this packet with a new link.

## Role as advertised (recovered)

| Field | Value |
| :--- | :--- |
| Company | IONOS SE |
| Role | Site Reliability Engineer (f/m/d) – Application Hosting |
| Team | Application Hosting: Managed Nextcloud, Nextcloud Workspace, IONOS GPT, further web services |
| Location | Hinterm Hauptbahnhof 3-5, 76137 Karlsruhe — hybrid, not remote-first |
| References | Greenhouse `ionos2` 4956693101 / DE duplicate `4956674101` / IONOS Kennziffer 1585 |
| Stack as originally captured | Kubernetes platform, Terraform, GitLab CI, Argo CD, Prometheus/Grafana, ELK |
| Compensation | not published; this packet states **EUR 85,000 p.a.** |
| Pipeline record | `ionos-site-reliability-engineer-karlsruhe`, stage `prep`, status `Packet prepared 2026-11-22` |
| Folder | `submissions/ionos-sre/` |

## Files

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | **2 pages** A4, German headings, sha256 `3f7421383101c569a121561a040d829675fcb4e935269b6520d19ca282aa9f8e` |
| `packet/anschreiben.pdf` | **1 page** A4, German, sha256 `a06726af9ed8273276b7512bde95135c96d6a1ad38916e55b9f68ea3327369fc` |
| `packet/selection.json` | projection audit |
| `lebenslauf.pdf`, `anschreiben.pdf`, `selection.json` | read-only copies |
| `letter.json` | German letter source |
| `job-description.txt` | recovered posting text + a provenance header naming the closure |
| `submission-sheet.md` | this sheet |

Built with:

```bash
NIX_CONFIG='builders =' bash scripts/task/appflow-packet.sh \
  --id ionos-site-reliability-engineer-karlsruhe \
  --language de --resume "$HOME/.config/appflow/lebenslauf.json" \
  --jd submissions/ionos-sre/job-description.txt \
  --letter submissions/ionos-sre/letter.json \
  --out submissions/ionos-sre/packet
```

## Candidate facts (what goes into any IONOS form)

| Field | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| E-Mail | matt@bountystash.com |
| Telefon | +49 173 3281570 |
| Languages | German **C1**, English **native** |
| Work authorisation | US citizen with German permanent residence — **no sponsorship needed** |
| Salary expectation | **EUR 85,000** gross p.a. |
| Earliest start | immediately / by agreement |
| Location willingness | Karlsruhe hybrid, ~130 km from home, office days possible, daily not |

## Greenhouse EU form — field IDs and staged answers

**Honest caveat first:** the application form for this requisition cannot be opened, because the page
redirects to the board error view. The fields below are the **standard Greenhouse EU application
shape** (`job_application[...]`), which is what `ionos2` uses for its live jobs; they are staged
answers, not a transcription of a form that no longer exists.

| Field ID | Label | Required | Staged answer |
| :--- | :--- | :--- | :--- |
| `job_application[first_name]` | First name | yes | **Matt** |
| `job_application[last_name]` | Last name | yes | **Ji** |
| `job_application[email]` | Email | yes | **matt@bountystash.com** |
| `job_application[phone]` | Phone | no | **+49 173 3281570** |
| `job_application[location]` | Location / city | no | **Gutach im Breisgau** |
| `job_application[resume]` | Resume/CV upload | yes | **`lebenslauf.pdf`** (2 pages, 39 KB) |
| `job_application[cover_letter]` | Cover letter upload | no | **`anschreiben.pdf`** (1 page) |
| `job_application[cover_letter_text]` | Cover letter text | no | paste the letter body if no upload field appears |
| `job_application[linkedin_profile_url]` | LinkedIn | no | leave empty — the profile is not needed to evaluate this CV |
| `job_application[website]` | Website / portfolio | no | **https://matt.bountystash.com** |
| `job_application[custom_questions][...]` | Board-specific questions | varies | none observable for this req; answer honestly if a live req asks for clearance, on-call consent or K8s years |
| GDPR consent (EU board) | data-processing consent | yes | accept — the EU board requires it to submit |

Greenhouse also asks for a **resume file, not a profile scrape**; the CV is built for exactly that
(one column, tagged headings, no tables).

## Fit map — job requirement to evidence

| Requirement | Evidence in this repo | Strength |
| :--- | :--- | :--- |
| Reliable operation of a product platform | sentinel ledger every 15 min (job status, generation age, disk, PSI) + gatus paging on any non-ok state | **strong** for method, small in scale |
| Kubernetes platform work | no production clusters; declarative microVM guests and containerised builds instead | **gap** — the posting's core |
| Automation / Infrastructure as Code | one flake declares 13 NixOS hosts, derived option surface, same module gate in CI and on hosts | **strong**, different tool |
| Linux depth | NixOS immutable generations, systemd, nftables default-deny, kernel-adjacent diagnosis from PSI/disk | **strong** |
| Monitoring / observability | self-built ledger + gatus; no Prometheus/Grafana/ELK operation | partial — concepts yes, tools no |
| Terraform / GitLab CI / Argo CD | not in the tool history; Nix + a task interface fill those roles | **gap** |
| Go/Python automation | `bountystash` Go service; Python analysis and tooling | **strong** |
| Nextcloud / Managed Hosting domain | not administered | **gap** |
| Scale (millions of customers) | 13 hosts, one mail archive | **gap** — stated plainly in the letter |

## Checks

| Gate | Result |
| :--- | :--- |
| `task checks:prose` | see the commit run — exit 0 expected on 184 files |
| `pdfinfo` budget | CV **2** pages, letter **1** page |
| DB record | `stage=prep`, `status=Packet prepared 2026-11-22` |
| Commit | packet committed with the closure documented |

## Next action

Do not submit to the dead link. Decide between (a) waiting for IONOS to repost a Karlsruhe SRE req,
(b) applying to `4971782101` (Staff Network Reliability, Karlsruhe) with a re-tailored letter, or
(c) sending this packet speculatively to IONOS recruiting with the closure noted.
