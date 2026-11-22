# ScorePlay — Ashby submission payload

**State: NOT submitted.** 2026-11-22. Automated submission from a headless pane was
attempted twice and did not complete; the form is gated behind reCAPTCHA, whose token
stays empty for this session and leaves `Submit Application` disabled. Nothing was
sent and no confirmation email arrived. This file is the exact payload for a human or
an authenticated pane to finish in one pass.

- **Apply URL:** https://jobs.ashbyhq.com/scoreplay/42f1911f-68d4-4a9f-8d9e-e3a7939ceb96/application
- **Pipeline record:** `scoreplay-senior-platform-engineer-sre`
- **CV to upload:** `lebenslauf.pdf` — 2 pages, A4, rebuilt as native Typst on 2026-11-22 (the `packet/` tree is gone)
- **Letter to upload:** `anschreiben.pdf` — 1 page, A4, English

## Why the browser could not finish it

| Evidence | Observed |
| :--- | :--- |
| reCAPTCHA token | `g-recaptcha-response` length **0** after refill; a token appears only transiently and is consumed before submit |
| Submit control | `button "Submit Application"` reported **disabled**; `click @e53` refused with "element is disabled, so the click would not reach it" |
| After first `Submit` click | no confirmation screen, form still rendered, no validation errors surfaced |
| Reload | clean, empty form — no "already applied" state, so no submission is recorded against this email |
| Inbox (`-a bountystash`) | zero messages matching `ashbyhq` / `scoreplay` |

A captcha is the site's own anti-automation gate. Obtaining or injecting a token from
outside the page's normal user flow is circumvention, so the attempt stops here.

## Field map — exact values, in DOM order

| # | Field (DOM id) | Value to enter |
| :--- | :--- | :--- |
| 1 | `_systemfield_name` | `Shaoyan (Matt) Ji` |
| 2 | `_systemfield_email` | `matt@bountystash.com` |
| 3 | `fe82994c-458d-4e2a-99cd-7ab76a119578` (Phone, `type=number`) | `491733281570` — the input rejects `+`; the CV shows `+49 1733281570` |
| 4 | `_systemfield_resume` (file) | `packet/lebenslauf.pdf` |
| 5 | `ee663a7c-36a1-4664-b70d-eb5f372ec053` (LinkedIn URL) | `https://linkedin.com/in/mattji` |
| 6 | `31a4b96f-ef63-4d69-b56d-35ea953a7d17` (Location) | `Gutach im Breisgau, Germany` |
| 7 | `0bfec1e2-9f36-4f8b-9d3e-4a69ed2f7717` (Visa sponsorship) | see below |
| 8 | `8b68bd4e-679e-4df3-97cd-083d3bada629` (What sparked your interest) | see below |
| 9 | `d6173516-591f-499a-84d1-81a2961c63f0` (Why a good fit) | see below |
| 10 | `342e33a5-7eb3-4919-a7e0-c76d0aa22986` (Expected salary) | see below |

**There is no cover-letter field.** The form replaces it with fields 8–10, and its own
copy asks for short answers "in your own words", with AI allowed only as a drafting
aid — so review fields 7–10 before sending and put them in your own register.

### 7 — Visa sponsorship

```text
No. I hold German permanent residence (unbefristete Niederlassungserlaubnis) and work in Germany without restriction; this role is remote from Germany, so no sponsorship is needed now or in the future.
```

### 8 — What sparked your interest (2–3 sentences requested)

```text
The platform team is one person today, and being the second hire with half a roadmap to own end to end is the job I have been doing alone on my own fleet. Bring Your Own Storage is the other draw: egress economics deciding whether sharing media is viable is a cost-and-reliability trade-off with numbers attached, not a side project.
```

### 9 — Why you would be a good fit

```text
I built and still operate a 13-host NixOS fleet from one flake: declared hosts, an SSH certificate authority, SOPS-encrypted secrets, and a sentinel that writes job status, generation age, disk and pressure-stall figures to a ledger every 15 minutes and pages me when one is not ok. That is the on-call and platform-as-a-product half of this role, run alone. Kubernetes, Terraform and Kafka would be new tools for me; I would say so rather than pretend otherwise.
```

### 10 — Expected annual gross salary

```text
EUR 105,000 gross per year; the range I am working with is EUR 103,000-110,000 depending on scope.
```

Published band is €90,000–110,000 plus €150,000 equity cash value; the candidate floor
is €95,000, so the bottom €5,000 of their range is below it. Target €103,000–110,000.

## Letter text, if a cover-letter field appears after all

Source of truth is `letter.json` (rendered as `packet/anschreiben.pdf`, 1 page). Subject:
`Application - Senior Platform Engineer (SRE), Western Europe Remote`. Salutation
`Dear ScorePlay team,` and four paragraphs: the second-platform-hire argument; the
on-call, IaC, security-continuous and cost reasoning; the honest gaps (no production
Kubernetes, no Terraform/Terragrunt/Helm, no Kafka/Temporal, not 15 PB, AWS as instances
not architecture); and Western-Europe remote with German permanent residence, no
relocation and no permit.

## Finish it in one pass

1. Open the apply URL in a normal browser session and let reCAPTCHA run.
2. Upload `packet/lebenslauf.pdf`, then fill fields 1–10 from the table.
3. Review fields 7–10 in your own words; adjust the salary line only upward.
4. Press `Submit Application` and wait for the confirmation screen, then for the Ashby
   email in `matt@bountystash.com`.
5. Only then: `task apps:update -- scoreplay-senior-platform-engineer-sre --status "submitted <date>"`.

## Traps this attempt hit

- **Ashby's resume autofill overwrites fields.** Attaching a PDF rewrites name, email,
  phone, location and can draft answers to the custom questions — one run produced a
  `90000 EUR gross/year` salary, below the €95k floor. Re-check every field after upload.
- **`fill` can append into the previously focused element.** One run concatenated the
  LinkedIn URL, the location and the sponsorship answer into a single field. Verify each
  value after typing; never trust the click order alone.
- **The phone field is `type=number`** and silently drops a leading `+`.
- **`submission-sheet.md` says the question set is unknown until the page is opened.**
  It is now known and recorded above.

## File hashes at this build

| File | Pages | sha256 |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | `6aafcd638b29b43a28025d8702ebffb4a0509c885865fb35231034fa963d05ca` |
| `anschreiben.pdf` | 1 | `d34b4f2f70725f920e59114b6d62ec75c68b8d8d7c21a05adf85c7e055a65ab9` |

`packet/` was removed with the JSON leftovers; the Typst sources in this directory are the only originals.
