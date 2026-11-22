# STACKIT / Schwarz Digits — (Senior) Platform Engineer, STACKIT Control Plane Platform (GT1923)

**Status: packet built 2026-11-22, NOT submitted.** No account created, no form opened, no
captcha solved. The pipeline record is at stage `prep`, status
`packet built 2026-11-22 - not submitted`.

STACKIT is the sovereign-cloud arm of Schwarz Digits, the IT division of the Schwarz Group
(Lidl, Kaufland, PreZero). The Control Plane Platform team builds the tooling that
provisions the cloud's own infrastructure and the monitoring that watches it.

## Role

| Field | Value |
| :--- | :--- |
| Company | STACKIT / Schwarz Digits (Schwarz Group) |
| Role | (Senior) Platform Engineer - STACKIT Control Plane Platform (m/f/d) |
| Job ID | `GT1923` — the ATS requisition is `jobReqId 1923` |
| Apply URL | https://schwarz-digits.de/en/jobsearch/hr/senior-platform-engineer-stackit-control-plane-platform-m-f-d-GT1923 |
| ATS | RocketApply (SAPUI5 on BTP), in-page dialog — no separate careers account of its own |
| Location | Am Campus 1, 74177 Bad Friedrichshall (Baden-Württemberg), hybrid |
| Posted | 2026-07-02 |
| Language | English application (`data-mmm-rocket-apply-language="en_US"`); the `/de/` variant of this slug returns **404**, so apply in English |
| Compensation | not posted; target band for this application **EUR 80,000–110,000** |
| Pipeline record | `stackit-schwarz-digits-senior-platform-engineer-control-plane`, stage `prep` |
| Folder | `submissions/stackit/` |

## Files

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | 2 pages A4, sha256 `5f4bd595a53ca38a8ef75343207a2cb217fef0132dfaf10b8b8d0ca560d9c421` |
| `packet/anschreiben.pdf` | 1 page A4, English, sha256 `7175cb7e7057d54d5c08c25751e6cb5d7ac03078b36941d90458cbb424f674dd` |
| `packet/selection.json` | Projection audit: kept and dropped lines with scores |
| `lebenslauf.pdf`, `anschreiben.pdf`, `selection.json` | Read-only `cp -L` copies of the packet, for upload |
| `letter.json` | Letter source, so the PDF reproduces from this tree |
| `job-description.txt` | Posting text, from the page's schema.org `JobPosting` block |
| `submission-sheet.md` | This sheet |

Built with:

```bash
bash scripts/task/appflow-packet.sh \
  --id stackit-schwarz-digits-senior-platform-engineer-control-plane \
  --jd submissions/stackit/job-description.txt \
  --letter submissions/stackit/letter.json \
  --out submissions/stackit/packet
```

The letter flag is not optional here: `appflow-packet.sh` defaults to
`~/.config/appflow/letter.json`, which currently holds the GoCardless letter. Compiled in the
Nix sandbox on `eu.nixbuild.net`; the artifact is
`/nix/store/26cjs3lv9h3d9bh9rqiqdcx6x7537438-appflow-packet-stackit-schwarz-digits-senior-platform-engineer-control-plane`.
`packet/` is a symlink to that store path, so the files in it are immutable.

## The application form — fields as the ATS actually defines them

Read from the RocketApply OData service and its i18n bundle
(`/app/i18n/i18n.properties`, `/app/view/Second.view.xml`,
`/api/jobsearch/$metadata`, `/api/application/$metadata`), not from a rendered dialog. The
dialog is opened by the **Apply** button on the posting page.

### Your Details

| # | Field (exact label) | Answer |
| :-- | :--- | :--- |
| 1 | Gender | **Male** (picklist `gender`, option id 1193; the others are Female 1194, Divers 1191, Not specified 1192) |
| 2 | First name | **Matt** |
| 3 | Last name | **Ji** |
| 4 | E-mail | **matt@bountystash.com** |
| 5 | Mobile (without "0" / "+" at the beginning) | **1733281570** — digits only; the field rejects a leading `0` or `+` |
| 6 | Country code | **49** (Germany) |
| 7 | Street | **Am Burgerhof** |
| 8 | Number | **4** |
| 9 | ZIP code | **79261** |
| 10 | City | **Gutach im Breisgau** |
| 11 | Country | **Germany** (picklist `country`, option id 1072) |
| 12 | How did you hear about this position? | **Career site** (picklist `CustHearPosition`, option id 711). Honest for this lead: the posting was found by searching employers' own career sites. The other twelve options are: Not specified, Recruitment consultancy/recruitment agency, Active sourcing, LinkedIn / Xing, Event at school/college/university, Print media, Online search engine (e.g. Google, Bing), Trade fairs, Social media channels, Online job boards/career portals (e.g. Stepstone/Indeed/etc.), Internal job advertisement, Recommendation by colleagues |
| 13 | Were we recommended to you by an employee? | **leave empty** — no referral exists, and inventing one is a reference the company can check |
| 14 | Talent pool opt-in ("I would like to find out more about career opportunities…") | **unchecked.** Granting marketing consent is the candidate's decision, not a form-filling default |
| 15 | SMS consent ("I agree to receive text messages…") | **unchecked** — same reason; it also requires the country code above |
| 16 | Visibility Settings | **"Only the recruiters responsible for a specific application of mine."** This is the narrowest of the three options; the wider ones expose the candidate profile and this candidate's other applications across the whole Schwarz Group for four months |
| 17 | "I have read and accept the data security declaration" | **checked** (required to submit) — https://gruppe.schwarz/en/privacy-recruiting/privacy-policy-recruiting |
| 18 | Screening Questions | **none for this requisition.** `JobReqQuestion` filtered on `jobReqId eq 1923` returns zero rows, and `JobQuestionChoices` likewise, so the section is absent or empty. If the dialog shows any question, it is new since this check: answer from the sheet's gap list, never by inventing experience |

### Your Documents

| Field | Rule (from the ATS i18n) | What to upload |
| :--- | :--- | :--- |
| Category | `Resume / CV *` is mandatory; `Cover letter` and `Certificates and other documents` are optional | `lebenslauf.pdf` → **Resume / CV**; `anschreiben.pdf` → **Cover letter** |
| File size | Max **5 MB per file** | CV 39 KB, letter 25 KB — fine |
| File type | PDF, DOCS, image and text allowed; **MSG, PPT and XLS are rejected as CV or cover letter** | both are PDF |

There is also a **captcha** ("Verification") that must complete before "Send application"
becomes available, and the page states that documents from an existing candidate profile are
merged into the application — so check the upload list before sending, not after.

**Send application** is the submit button; **Abort** closes without sending.

## Location, right to work, compensation

- **Bad Friedrichshall is ~230 km from Gutach im Breisgau**, roughly 2.5 h by car. The letter
  asks for the expected on-site cadence rather than assuming full remote, and offers to travel
  for onboarding and team weeks. The form itself has no location or remote field, so this is an
  interview question, not a form answer.
- **Right to work:** US citizen with German permanent residence, no sponsorship needed. The
  form asks nothing about nationality or permits — do not volunteer a visa framing.
- **Compensation:** not published. Reference signals for this requisition are contradictory
  (aggregators quote EUR 6,667–9,167/month, i.e. ~80–110k, for GT1923; sibling STACKIT postings
  sit at 56–81k). If a recruiter asks, the answer that matches the target band is **EUR 95,000
  base, negotiable to 110,000 for a senior scope**, and the question to ask back is which of the
  two levels the `(Senior)` prefix actually maps to. Do not quote a number before the level is
  settled.

## Projection audit (what the CV actually says)

Scorer terms, strongest first: **kubernetes** (20.676), **security** (16.137), **engineer**
(11.866), **data** (9.686), **cloud** (8.664), **database** (8.664).

- **Highlights: 9 of 32** — Bountystash **1/10**, O3 Energy 2/8, Smart Energy 360 2/4,
  Fraunhofer ISE 2/4, Halliburton 2/6.
- **Projects: 4 of 10** — `nixconfig`, `kev-time`, `Vulnerability operations concept`,
  `Risk Calculation Engine`.
- **Skills:** DevOps 5/5, Backend & Database 6/6, Security 6/6, Web 6/7, Energy & Risk 6/8,
  Programming Languages 6/10.

The projection is weaker than it should be, and the reason is a corpus artefact rather than the
JD: the Bountystash highlights are all business-shaped (PPA models, hedging, client portfolios),
so the scorer keeps exactly one — *"Audited bug bounty programmes"* — and the Go service, the
sentinel and the fleet survive only in the Projects block and the letter. `bountystash`, the
project that names the Go service, was **dropped** in favour of the risk engine. Measured on the
rendered PDFs: *Kubernetes* 1, *NixOS* 3, *Go* 8, *SOPS* 2, *Terraform* 0, *Helm* 0, and
*Control Plane* 0. A corpus fix (an infrastructure highlight under Bountystash naming the Go
service and the fleet) would repair every platform packet, not just this one; it is not done
here because it changes the shared corpus.

## Alignment and honest gaps

Matches, every one inspectable in this repo:

- **Provisioning as a function of a declaration** — one flake declares thirteen NixOS hosts,
  feature lists registered per host, option surface derived, one module gate in CI and on the
  machines.
- **Go as the service language** — `bountystash` is a single-binary Go service with append-only
  events, content-addressed specifications, a TUI and HTTP endpoints, operated by the candidate.
- **Monitoring that is trusted** — a sentinel records job status, generation age, disk and PSI
  every fifteen minutes; gatus pages on any state that is not ok; a green socket is not accepted
  as proof.
- **Security as engineering** — SOPS/age per host, an SSH certificate authority with short-lived
  certificates, default-deny nftables, patching ordered by CISA KEV and exposure.
- **Three-plus years in an SRE/platform-shaped role** — satisfied on time (2020–2025), though the
  title was Founder, not SRE.

Gaps, all stated in the letter:

1. **No production Kubernetes clusters operated.** Architecture and reconciliation are
   understood from building an equivalent layer; the operator pattern has not been implemented
   against a real cluster. The posting asks for "in-depth knowledge of Kubernetes architecture"
   and the operator pattern — this is the central miss.
2. **No Helm, Kustomize, Terraform, Pulumi, Istio, Calico, Concourse or Flux.** Nix and a task
   interface fill those roles here; the concepts transfer, the tooling does not.
3. **Go is single-author production code**, not a reviewed codebase at team scale; "advanced
   programming experience" is a claim to defend in a pairing exercise.
4. **No cloud-provider control plane experience** — no STACKIT, OpenStack, VMware or
   hyperscaler tenancy work.
5. **Hybrid cadence unknown** and the distance is real; see above.

## Submit-time checklist

1. Open the posting, press **Apply**, complete the captcha.
2. Fill Your Details exactly as the table above; do not opt into the talent pool or SMS unless
   the operator says so.
3. Upload `lebenslauf.pdf` as **Resume / CV** and `anschreiben.pdf` as **Cover letter**; nothing
   under certificates.
4. If a screening question appears, answer from the gap list honestly and stop if it asks for
   Kubernetes production years — the honest answer is zero.
5. Send, then confirm the acknowledgement e-mail (the page says to write to
   karriere@kaufland.de if no receipt arrives within 24 hours).
6. Update the record: status `Applied` / stage moves to `applied` with the receipt date.

## Next action

Review the projection (the Bountystash bullet is the weak spot) and the letter, then submit.
Nothing has been sent; the record stays at `prep` until it is.
