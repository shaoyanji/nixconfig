# EnBW Energie Baden-Württemberg — Platform / DevOps Engineer Linux & Kubernetes (w/m/d) C-TIPCP

**Status: packet built 2026-11-22, and the posting is CLOSED — do not submit.**
`stage=prep` in the pipeline means "packet exists", not "ready to send": the application route
for this requisition answers *"The job that you were looking for either does not exist or is no
longer open."* (verified in a headless browser against
`/de/de/apply?jobSeqNo=EBQEBQGLOBAL25599EXTERNALDEDE`, 2026-11-22.)

## The finding that decides this one

| Check | Result |
| :--- | :--- |
| Posting page `/global/de/job/…EBQEBQGLOBAL25599EXTERNALGLOBAL…` | HTTP 200, but only the SPA shell — the same 88 KB shell as the home page |
| Same slug in `/de/de/` (EXTERNALDEDE) and `/global/en/` (EXTERNALENGLOBAL) | **HTTP 410** |
| Posting page in the browser | redirects to `/de/de` — the home page, not a job |
| **Apply flow** `?jobSeqNo=EBQEBQGLOBAL25599EXTERNALDEDE` | **"The job that you were looking for either does not exist or is no longer open."** |
| Career-site search for "Platform DevOps Engineer" | 25 results, this requisition **not** among them |
| Full job text | still readable on a mirror of the same posting (Netze BW GmbH, Kennung ad-2493271128), last seen ~20 days ago |

So the packet is a complete, honest artifact for a role that can no longer be applied to from the
portal. Keep it if the requisition reopens (C-TIP re-posts), or as the base for a speculative
application to EnBW C-TIP; do not treat it as a queue item to submit.

## Role

| Field | Value |
| :--- | :--- |
| Company | EnBW Energie Baden-Württemberg AG — Bereich C-TIP (Cloud Technology, Infrastructure & Platforms); advertised via **Netze BW GmbH** |
| Role | Platform / DevOps Engineer Linux & Kubernetes (w/m/d), Kennung C-TIPCP |
| Requisition | `EBQEBQGLOBAL25599EXTERNALGLOBAL` (apply-layer `jobSeqNo EBQEBQGLOBAL25599EXTERNALDEDE`) |
| Apply URL | https://careers.enbw.com/global/de/job/EBQEBQGLOBAL25599EXTERNALGLOBAL/Platform-DevOps-Engineer-Linux-Kubernetes-w-m-d-C-TIPCP |
| Location | Karlsruhe (76131), hybrid with home-office share |
| Languages | German required ("sehr gute Deutschkenntnisse in Wort und Schrift"), English documentation |
| Compensation | not published; aggregators put it at **EUR 50–65k** — the decisive gap, see below |
| Pipeline record | `enbw-platform-devops-engineer-linux-kubernetes`, language now `de`, stage `prep` |
| Folder | `submissions/enbw/` |

## Files

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | **2 pages** A4, German headings, sha256 `948dfb65dd35ce1c70abd894f49b5a4be565f57248ea026d8607afb3aa84f1bb` |
| `packet/anschreiben.pdf` | **1 page** A4, German letter, sha256 `e1183fe48504e89ca57a00b89ecf1d70fd28b151559a1825d30703c268772fb4` |
| `packet/selection.json` | Projection audit, 14/32 highlights and 4/10 projects kept |
| `lebenslauf.pdf`, `anschreiben.pdf`, `selection.json` | read-only `cp -L` copies for upload |
| `letter.json` | German letter source |
| `job-description.txt` | full German posting text, with its provenance paragraph |
| `submission-sheet.md` | this sheet |

Built with:

```bash
NIX_CONFIG='builders =' bash scripts/task/appflow-packet.sh \
  --id enbw-platform-devops-engineer-linux-kubernetes \
  --language de \
  --resume "$HOME/.config/appflow/lebenslauf.json" \
  --jd submissions/enbw/job-description.txt \
  --letter submissions/enbw/letter.json \
  --out submissions/enbw/packet
```

Two deliberate deviations, both load-bearing:

- **`--language de`** did not exist before today. The record is filed as `en`
  (from the first scan), and the ATS-facing API ignored a `language` field posted to
  `application-update`, so a German application on that row would have rendered *English* section
  headings over German prose. The flag is four lines in `scripts/task/appflow-packet.sh` and
  overrides the language without rewriting the database.
- **`NIX_CONFIG='builders ='`** builds locally. `eu.nixbuild.net` had cached a build failure for
  this derivation (nixbuild build `14767958`) from the first attempt, whose real error was
  benign — the letter was two pages against a one-page budget; the remote caches the failure and
  refuses to retry. Local build: `typeset: lebenslauf.pdf: 2 page(s), budget 2`,
  `anschreiben.pdf: 1 page(s), budget 1`.

## Job description provenance

The careers site is Phenom and renders the description client-side: the page carries only
`WebSite`/`WebPage` JSON-LD, no `JobPosting`, and its widget API answers `Tenant not identified`
or an empty result set without a browser session. The stored text therefore comes from a
**full mirror of the same Netze BW/EnBW requisition** and says so in its header. Nothing was
summarised or reworded.

## Form schema — the EnBW apply flow, as the portal actually builds it

Mapped by driving the portal in headless Chrome on a **live** requisition (the flow is shared by
every EnBW posting), because the static HTML contains none of it:

`https://careers.enbw.com/de/de/apply?jobSeqNo=<SEQ>&step=1&stepname=personalInformation`

Three steps, shown as a stepper:

1. **Anwendung erstellen** (`personalInformation`)
2. **Überprüfen Sie das Profil**
3. **Dokumente & Stellenbezogene Fragen**

Step 1 fields, exactly as rendered:

| Field | Rule | Value to enter |
| :--- | :--- | :--- |
| "Lebenslauf hochladen" (CV upload) | **optional** — "Auch ohne Lebenslauf ist eine Bewerbung möglich"; DOC, DOCX, JPEG, PNG, PDF, TXT; **max 5 MB**; alternatively a LinkedIn profile or manual entry | `lebenslauf.pdf` (39 KB, PDF) |
| "E-Mail (privat)" | **required**; the portal states the address is deleted after a short time if the process is not continued | **matt@bountystash.com** |
| Privacy notice | linked as "Datenschutzhinweise"; processing for the application procedure | read, then proceed |

Steps 2 and 3 sit behind the email step, which begins an application, so their field list was
**not** entered. From the posting and the flow's own labels, expect: the profile fields (name,
address, phone), document categories, and — in the posting's words — "gegebenenfalls ein paar
jobspezifische Fragen". The posting also states plainly: **"Ein Anschreiben ist dafür nicht
erforderlich."** The letter in this packet is therefore optional material; upload it only if a
document category offers it.

Values to enter once those fields appear:

| Field | Value |
| :--- | :--- |
| Vorname / Nachname | Matt / Ji |
| E-Mail | matt@bountystash.com |
| Telefon | +49 173 3281570 |
| Straße, Hausnummer | Am Burgerhof 4 |
| PLZ, Ort | 79261 Gutach im Breisgau |
| Land | Deutschland (Baden-Württemberg) |
| Arbeitserlaubnis | US-Staatsbürger mit deutschem Niederlassungsrecht, **keine Unterstützung nötig** |
| Frühester Eintritt | sofort / nach Vereinbarung |
| Gehaltsvorstellung | siehe unten |

## The two blockers, in order of severity

**1. On-call, one hour on site.** The posting: *"Du beteiligst dich an der 24/7-Bereitschaft in
rollierenden Abständen und stellst sicher, dass du bei Bedarf innerhalb einer Stunde vor Ort in
Karlsruhe einsatzbereit sein kannst."* Gutach im Breisgau to Karlsruhe is ~130 km, about 1.5 h by
car. The one-hour promise is not keepable, and the letter says so rather than accepting a term
that would be broken on the first real incident. A remote first response with on-site escalation
would work; anything else does not.

**2. Money.** No band is published. Aggregators put this requisition at **EUR 50–65k**
(devjobs), against a target of EUR 85,000–95,000. Even at the top of that range the gap is
20–35k. For this application the sheet records **EUR 85,000 with a floor of 75,000**, and the
honest expectation is that EnBW will not reach it for this grade — which is a reason to skip
rather than to negotiate hard.

## Projection audit

Scorer terms, strongest first: **kubernetes** (24.079), **energy** (23.56), **cloud** (22.506),
**energie** (18.1), **kubernetes-umgebungen** (18.1), **netze** (16.056).

- **Highlights: 14 of 32** — the strongest selection of the four packets so far, because the JD is
  German and the German corpus shares its vocabulary: Bountystash keeps several bullets, and the
  energy work at O3 Energy survives.
- **Projects: 4 of 10** — `Risikoberechnungs-Engine`, `Masterarbeit: Wetter und Volatilität`,
  `Postgraduales Studium: Erneuerbare Energien`, `nixconfig`. The energy projects rank because
  the posting's own vocabulary (`energie`, `netze`) matches them; `bountystash` is dropped again.
- **Headings are German** (`Berufserfahrung`, `Projekte`, …) and the ATS check confirms they are
  tagged `/H1` in the PDF structure tree, so a German parser sees sections rather than bold runs.

## Alignment and honest gaps

Real here:

- **Linux as the platform, declared**: thirteen NixOS hosts from one flake, feature-list
  registration, derived option surface, the same module gate in CI and on the machines, a task
  interface as the self-service surface.
- **Monitoring that is acted on**: sentinel writes job status, generation age, disk and PSI every
  fifteen minutes; gatus pages on any non-ok state; a green socket is not proof of a finished job.
- **Energy domain**: heliostat metrology at Fraunhofer ISE (C++/Python), 10 MW of solar PV and a
  USD 100M+ portfolio at O3 Energy, projects and customer work at Smart Energy 360 — the
  "Anlagen, Messdaten, Infrastruktur" side the posting's division works on.
- **Go and Python in production**: `bountystash` is a single-binary Go service with append-only
  events, content-addressed specifications, HTTP endpoints and a TUI.

Gaps:

1. **No production Kubernetes operation** — architecture and reconciliation are from building an
   equivalent layer, not from running clusters; the posting asks for practical experience
   operating Linux and Kubernetes environments.
2. **No Terraform, no Helm**, no CNI/eBPF work.
3. **German is C1, not native** — the posting asks for "sehr gute Deutschkenntnisse"; C1 is that,
   but a German-language panel will notice the difference from a native speaker.
4. **No 24/7 rotation experience**, and the one-hour on-site term is unmeetable from Gutach.

## Next action

None by default: the requisition is closed. If it reopens — or for a speculative C-TIP
application — the packet is ready, and the letter's two questions (on-call model, tooling depth)
are the ones to settle first, before any form is filled.
