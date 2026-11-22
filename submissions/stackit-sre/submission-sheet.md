# STACKIT / Schwarz Digits — (Senior) Site Reliability Engineer, STACKIT Control Plane (GT2321)

**Status: packet built 2026-11-22, NOT submitted.** No account created, no form opened, no
captcha solved. Pipeline record at stage `prep`, status
`packet built 2026-11-22 - not submitted`.

This is the second STACKIT posting in the pipeline; the sibling `(Senior) Platform Engineer,
Control Plane Platform` (GT1923) packet lives in `submissions/stackit/`. Both use the same
RocketApply instance, so the form schema below is shared, but the requisition — and the job — is
different.

## Role

| Field | Value |
| :--- | :--- |
| Company | STACKIT / Schwarz Digits (Schwarz Group) |
| Role | (Senior) Site Reliability Engineer - STACKIT Control Plane (m/f/d) |
| Job ID | `GT2321` — ATS requisition `jobReqId 2321` |
| Apply URL | https://schwarz-digits.de/en/jobsearch/hr/senior-site-reliability-engineer-stackit-control-plane-m-f-d-GT2321 |
| ATS | RocketApply (SAPUI5 on BTP), in-page Apply dialog |
| Location | Am Campus 1, 74177 Bad Friedrichshall (Baden-Württemberg), hybrid |
| Posted | 2026-01-16 — the oldest of the STACKIT control-plane postings, so re-confirm it is still open before spending the captcha |
| Language | English application (`data-mmm-rocket-apply-language="en_US"`); the `/de/` form of this slug returns **404** |
| Compensation | not posted; **expectation for this application: EUR 85,000–110,000** |
| Pipeline record | `stackit-schwarz-digits-senior-sre-control-plane`, stage `prep` |
| Folder | `submissions/stackit-sre/` |

## What the posting actually asks for

Six tasks, and the profile behind them:

- Shorten **time-to-detect** with monitoring and alerting that holds a defined **SLO**.
- Shorten **time-to-mitigate** with playbooks, first-responder dashboards and comprehensive
  telemetry (logs and metrics).
- Act as a **reliability consultant** to development teams, shifting reliability left.
- Design **CI/CD for progressive delivery** — canary and blue/green.
- Optimise **Control Plane scalability**: distributed consensus bottlenecks, database throughput,
  kernel-level networking.
- Carry a **compensated on-call rotation**, lead incidents, run blameless post-mortems and RCAs.

Profile: 3+ years SRE/DevOps/Platform on large-scale distributed systems in production;
**expert** knowledge of Kubernetes control-plane internals (API server, controller manager,
scheduler, etcd); production **Go** for automation, Operators or glue; IaC and containers;
**Linux internals** (kernel tuning, memory) and networking (TCP/IP, CNI, load balancers, eBPF);
datastores (PostgreSQL, Redis) and messaging (Kafka, NATS) at scale.

## Files

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | **2 pages** A4, sha256 `87e837125d73b512f3dde4b434b59513fccc922a15f2f2029dbb68122806bf4a` |
| `packet/anschreiben.pdf` | **1 page** A4, English, sha256 `3ac4a2772591ca246613ee104a96ec6deec47708ea0a410db394ad581fb5ce75` |
| `packet/selection.json` | Projection audit with kept and dropped lines |
| `lebenslauf.pdf`, `anschreiben.pdf`, `selection.json` | Read-only `cp -L` copies for upload |
| `letter.json` | Letter source, so the PDF reproduces from this tree |
| `job-description.txt` | Posting text from the page's schema.org `JobPosting` block |
| `submission-sheet.md` | This sheet |

Built with:

```bash
bash scripts/task/appflow-packet.sh \
  --id stackit-schwarz-digits-senior-sre-control-plane \
  --jd submissions/stackit-sre/job-description.txt \
  --letter submissions/stackit-sre/letter.json \
  --out submissions/stackit-sre/packet
```

`--letter` is required: the script otherwise reads `~/.config/appflow/letter.json`, which holds
another application's letter. Compiled in the Nix sandbox on `eu.nixbuild.net`; artifact
`/nix/store/xr3jgxrdxf2clh6w5cq22yrzvi72gfpr-appflow-packet-stackit-schwarz-digits-senior-sre-control-plane`,
and `packet/` is a symlink to it.

## Form schema — RocketApply, req 2321

Read from the ATS OData service and its i18n bundle rather than from a rendered dialog:
`/api/jobsearch/$metadata`, `/api/application/$metadata`, `/app/i18n/i18n.properties`,
`/app/view/Second.view.xml`. The **Apply** button on the posting opens the dialog in place.

| # | Field (exact label) | Value to enter |
| :-- | :--- | :--- |
| 1 | Gender | **Male** (`gender`, id 1193; others: Female 1194, Divers 1191, Not specified 1192) |
| 2 | First name | **Matt** |
| 3 | Last name | **Ji** |
| 4 | E-mail | **matt@bountystash.com** |
| 5 | Mobile (without "0" / "+" at the beginning) | **1733281570** — digits only, no leading `0` or `+` |
| 6 | Country code | **49** |
| 7 | Street | **Am Burgerhof** |
| 8 | Number | **4** |
| 9 | ZIP code | **79261** |
| 10 | City | **Gutach im Breisgau** |
| 11 | Country | **Germany** (`country`, id 1072) |
| 12 | How did you hear about this position? | **Career site** (`CustHearPosition`, id 711) — the posting was found through the employer's own career site, which is the truthful option |
| 13 | Were we recommended to you by an employee? | **empty** — no referral exists; a fabricated one is checkable |
| 14 | Talent pool opt-in | **unchecked** — marketing consent is the candidate's call |
| 15 | SMS consent | **unchecked** |
| 16 | Visibility Settings | **"Only the recruiters responsible for a specific application of mine."** — narrowest of the three; the others expose the profile and this candidate's other applications across the Schwarz Group |
| 17 | "I have read and accept the data security declaration" | **checked** (required) — https://gruppe.schwarz/en/privacy-recruiting/privacy-policy-recruiting |
| 18 | Screening Questions | **none.** `JobReqQuestion` filtered on `jobReqId eq 2321` returns zero rows, as does `JobQuestionChoices`, so the section is empty for this requisition |

Documents:

| Field | Rule | Upload |
| :--- | :--- | :--- |
| Category | `Resume / CV *` mandatory; `Cover letter`, `Certificates and other documents` optional | `lebenslauf.pdf` → **Resume / CV**; `anschreiben.pdf` → **Cover letter** |
| Size | max **5 MB** per file | 39 KB and 25 KB |
| Type | PDF/DOCS/image/text; **MSG, PPT, XLS rejected as CV or letter** | both PDF |

A **captcha** ("Verification") must complete before **Send application** activates. The page also
warns that documents from an existing candidate profile are merged into the application, so read
the upload list before sending.

## Location, right to work, compensation, on-call

- **Distance:** ~230 km from Gutach im Breisgau to Bad Friedrichshall, roughly 2.5 h by car. The
  letter asks for the on-site cadence instead of assuming remote; the form has no location field,
  so this is an interview conversation.
- **Right to work:** US citizen with **German permanent residence, no sponsorship needed**. The
  form asks nothing about permits — do not volunteer a visa framing.
- **Compensation:** not published. The lead note records aggregator figures near **EUR 62k** for
  this requisition, which is why the earlier scan flagged salary as the blocker rather than the
  stack. The expectation recorded for this application is **EUR 85,000–110,000**: quote
  **EUR 95,000 base** as the target and hold the 85k floor, and treat a first offer near 62–70k as
  the signal it is — the level is not what the `(Senior)` prefix implies.
- **On-call:** the posting explicitly says the rotation is **compensated**. Ask how (allowance,
  time off, or both) and what the rotation interval and escalation path are; a compensated
  rotation is worth more than a band that looks 5k higher.
- **Language:** English native, **German C1** — stated in the letter, and it is what the corpus
  claims, so a German-speaking interview is fair game.

## Projection audit (what the CV actually says)

Scorer terms, strongest first: **systems** (18.183), **kubernetes** (14.67), **networking**
(14.67), **security** (13.019), **data** (12.005), **internals** (11.866).

- **Highlights: 9 of 32** — Bountystash 2/10, O3 Energy 2/8, Smart Energy 360 1/4,
  Fraunhofer ISE 2/4, Halliburton 2/6.
- **Projects: 4 of 10** — `nixconfig`, `kev-time`, `Vulnerability operations concept`,
  `Risk Calculation Engine`. **`bountystash` — the Go service — is dropped again**, exactly as in
  the GT1923 packet, so the strongest Go evidence survives only in the letter.
- **Skills:** DevOps 5/5, Backend & Database 6/6, Security 6/6, Web 6/7, Energy & Risk 6/8,
  Programming Languages 6/10.

The projection keeps more of Bountystash than the platform packet did (2/10 rather than 1/10)
because this JD scores `security` and `systems` rather than `cloud`. It is still thin on the two
things the posting weights most: Kubernetes is one term on the page and zero projects, and
"internals" is a JD term the corpus cannot match with a project name. A corpus highlight naming
the fleet, the sentinel and the Go service would lift every platform-and-SRE packet; it is not
done here because it changes shared input.

## Alignment and honest gaps

Real, inspectable in this repo:

- **Monitoring as a discipline** — a sentinel writes job status, generation age, disk and PSI
  every fifteen minutes; gatus pages on any state that is not ok; the ledger, not a green socket,
  decides whether a job finished. That is time-to-detect work with the same failure mode the
  posting names.
- **Telemetry a responder can use** — one interface (`task`) keeps the query next to the action,
  and a runbook is a page in `docs/` or a skill rather than tribal knowledge.
- **Linux depth in practice** — hermetic builds with pinned inputs, pressure-stall and disk
  figures used to diagnose before changing anything, default-deny nftables, per-host secrets.
- **Zero standing credentials** — an SSH certificate authority issues short-lived certificates
  instead of leaving keys on hosts; SOPS and age encrypt secrets per host; patching follows the
  CISA KEV catalogue and exposure.
- **Go in production** — `bountystash`, a single-binary Go service with append-only events and
  content-addressed specifications, built and operated by the candidate.
- **PostgreSQL in production** — migrations, a rehearsed restore, statement timeouts,
  disk-pressure alerting. One instance, not a fleet.

Gaps, all named in the letter:

1. **No Kubernetes control-plane operation.** API server, controller manager, scheduler, etcd —
   none run in production by this candidate; consensus tuning at that layer is reading, not
   experience. This is the central miss and the posting asks for expert level.
2. **No SLO/error-budget practice.** Thresholds on one estate, not burn-rate alerting on a
   multi-tenant service.
3. **No Redis, Kafka, NATS, CNI, eBPF, load-balancer or canary/blue-green platform work.**
4. **No Kubernetes Operators**, and no IaC in Terraform/Pulumi — Nix and a task interface fill
   those roles.
5. **Scale:** thirteen hosts and a mail archive, not a cloud control plane with tenants.
6. **Distance and hybrid cadence** — see above.

## Submit-time checklist

1. Confirm the posting is still live (posted 2026-01-16), then press **Apply** and finish the
   captcha.
2. Fill Your Details from the table; leave the talent pool and SMS consents unchecked; pick the
   narrowest visibility setting.
3. Upload `lebenslauf.pdf` as **Resume / CV**, `anschreiben.pdf` as **Cover letter**.
4. No screening questions are defined for req 2321. If one appears anyway, answer honestly and
   stop if it asks for production etcd or API-server operating years — the honest answer is zero.
5. Send, wait for the acknowledgement (the page routes missing receipts to
   karriere@kaufland.de after 24 h).
6. Move the record to `applied` with the receipt date.

## Next action

Review the packaging, then submit. Nothing has been sent; the record stays at `prep` until it is.
