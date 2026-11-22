# SVA System Vertrieb Alexander — DevOps Engineer / Consultant – Linux (m/w/d), j734

**Status: packet built 2026-11-22, NOT submitted.** No form opened for entry, no upload sent.
Pipeline record `sva-devops-consultant-linux` at stage `prep`.

SVA is an owner-managed German system house (29 sites, ~100-person DevOps team), selling and
running IT infrastructure for customers. This role sits in that team: Linux infrastructure,
automation, customer projects from presales through operation — the posting's own words are
*"You build it, you run it"*.

## Role

| Field | Value |
| :--- | :--- |
| Company | SVA System Vertrieb Alexander GmbH (HQ Borsigstraße 26, 65205 Wiesbaden) |
| Role | DevOps Engineer / Consultant – Linux (m/w/d) |
| Kennung | **j734**; the application form is served as **f734** |
| Posting | https://www.sva.de/de/job-portal/DevOps-Engineer-Consultant-Linux-mwd-de-j734.html |
| Application form | https://www.sva.de/de/job-portal/DevOps-Engineer-Consultant-Linux-mwd-de-f734.html |
| Locations | **29 sites**, candidate's choice at application: **Freiburg** (Schnewlinstraße 12, 79098) is ~25 km from home; Karlsruhe, Leinfelden-Echterdingen, Ulm and Meersburg are the other Baden-Württemberg options |
| Employment | full time, permanent; mobile work depending on the assignment |
| Posted / valid | 2026-11-06, `validThrough` 2027-01-06; no application deadline while the posting is visible |
| Language | **German C1 or above required**, English B2 or above; the posting repeats it in English: *"All positions require fluent German language skills (level C1 or above)"* |
| Compensation | not published; SVA asks for a figure in the form — this packet states **EUR 85,000 p.a.** |
| Pipeline record | `sva-devops-consultant-linux`, language now `de`, stage `prep` |
| Folder | `submissions/sva-linux/` |

## Files

| File | Notes |
| :--- | :--- |
| `packet/lebenslauf.pdf` | **2 pages** A4, German headings, sha256 `0a1303d7afe8104df11178561a024b2458e87302d2be74b91bac0561f31e6960` |
| `packet/anschreiben.pdf` | **1 page** A4, German, 497 words, sha256 `a05f5afba1cba65fa3c6c0788901800abea7a5d0a95086941c4bd4ffd51fc6b6` |
| `packet/selection.json` | projection audit: 10/32 highlights, 4/10 projects |
| `lebenslauf.pdf`, `anschreiben.pdf`, `selection.json` | read-only `cp -L` copies for upload |
| `letter.json` | German letter source |
| `job-description.txt` | full German posting, assembled from the page's schema.org `JobPosting` (responsibilities, qualifications, jobBenefits) plus its header block |
| `submission-sheet.md` | this sheet |

Built with:

```bash
NIX_CONFIG='builders =' bash scripts/task/appflow-packet.sh \
  --id sva-devops-consultant-linux \
  --language de \
  --resume "$HOME/.config/appflow/lebenslauf.json" \
  --jd submissions/sva-linux/job-description.txt \
  --letter submissions/sva-linux/letter.json \
  --out submissions/sva-linux/packet
```

`--language de` is needed because the record is filed `en` from the first scan; without it the
German CV renders English section headings. `NIX_CONFIG='builders ='` keeps the build local —
`typeset` reports `lebenslauf.pdf: 2 page(s), budget 2` and `anschreiben.pdf: 1 page(s), budget 1`.

## The form, field by field

The SVA portal is server-rendered PHP, so every input name and required flag was read from the
markup of the live form (`f734`), not from a screenshot. Field names are `bewerbung_form[...]`.

### Person

| Portal label | Input name | Required | Value |
| :--- | :--- | :--- | :--- |
| Anredetitel | `bewerbung_form[titel]` | no | **Herr** (options load client-side) |
| VORNAME | `bewerbung_form[vorname]` | **yes** | **Matt** |
| NACHNAME | `bewerbung_form[nachname]` | **yes** | **Ji** |
| STRASSE | `bewerbung_form[strasse]` | no | **Am Burgerhof 4** |
| PLZ | `bewerbung_form[plz]` | no | **79261** |
| ORT | `bewerbung_form[ort]` | no | **Gutach im Breisgau** |
| LAND | `bewerbung_form[country]` | no | **Deutschland** |
| GEBURTSDATUM (TT.MM.JJJJ) | `bewerbung_form[geburtsdatum]` | no | **leave empty** — date of birth is voluntary and German practice does not require it |
| TELEFON | `bewerbung_form[telefon]` + country selector (`+49`) | no | **1733281570** |
| E-MAIL | `bewerbung_form[mail]` | **yes** | **matt@bountystash.com** |
| Geschlecht | `bewerbung_form[gender]` | no | **männlich** (free choice; the field is optional) |

### SCHULE, AUSBILDUNG, BERUF

| Portal label | Input name | Required | Value |
| :--- | :--- | :--- | :--- |
| SCHULABSCHLUSS | `bewerbung_form[schulabschluss]` | no | **Hochschulabschluss** (options load client-side) |
| BERUFSAUSBILDUNG (BEZEICHNUNG) | `bewerbung_form[berufsausbildung_o_sb]` | no | **M.Sc. Renewable Energy / Informatik-nahes Studium** — enter the degree as it appears in the CV |
| BERUFSERFAHRUNG | `bewerbung_form[erfahrung_pref_inJ]` | no | **mehr als 5 Jahre** (2020–2025 founder role plus earlier IT administration) |
| DEUTSCHKENNTNISSE | `bewerbung_form[berufsausbildung_m_sb]` | **yes** | **C1** — the bar the posting sets; the field is required, so it cannot be skipped |

### SONSTIGES

| Portal label | Input name | Required | Value |
| :--- | :--- | :--- | :--- |
| FRÜHESTER EINTRITT (TT.MM.JJJJ) | `bewerbung_form[eintrittsdatum]` | **yes** | **01.12.2026** (sofort möglich; the date format is enforced by a datepicker) |
| GEHALTSWUNSCH P.A. (NUR ZAHL) | `bewerbung_form[gehaltswunsch]` | no | **85000** — digits only, as the label demands, and the same figure the letter names |
| WIE HABEN SIE UNS GEFUNDEN? | `bewerbung_form[wie_gefunden]` | **yes** | the option that matches a job-board search; the list is populated client-side, so pick that wording (not "Empfehlung") |

### ANLAGEN

Formats: Word (doc, docx), PDF, JPG, PNG, GIF; **max 15 MB per file**; no password- or
write-protected files.

| Slot | Input name | Required | Upload |
| :--- | :--- | :--- | :--- |
| ANSCHREIBEN / KOMPLETTE UNTERLAGEN | `anschreiben` | **yes** | **`anschreiben.pdf`** — or one merged complete document; with separate files this slot is the letter |
| LEBENSLAUF | `lebenslauf` | no | **`lebenslauf.pdf`** |
| FOTO | `foto` | no | **none** — a photo is not part of a German IT application |
| LETZTES ARBEITGEBERZEUGNIS | `anlage1` | no | **missing** — the posting asks for Zeugnisse; the repo holds no employer references or diplomas, so the operator has to supply them |
| WEITERE ANLAGE 2–4 | `anlage2`, `anlage8`, `anlage9`, `anlage10` | no | reserved for those certificates |

The last control is the mandatory agreement: *"DIE »DATENSCHUTZERKLÄRUNG« DER SVA HABE ICH ZUR
KENNTNIS GENOMMEN UND AKZEPTIERE DIE VERARBEITUNG MEINER DATEN"* (`agbs_check`), without which
**Senden** does nothing. A CSRF token (`bewerbung_form_tkn`) is embedded in the page, so the form
must be submitted from the page itself, not replayed.

The posting also states the application material it expects — **Anschreiben, Lebenslauf,
Zeugnisse, Gehaltsvorstellung, Eintrittsdatum** — which maps one-to-one onto the fields above
except the certificates, which do not exist in this repo.

## Location, language, sponsorship

- **Freiburg is the reason this application is worth making.** Schnewlinstraße 12 is ~25 km from
  Gutach im Breisgau, and the posting lets the candidate choose among 29 sites. That removes the
  relocation and commute questions that dominated the last three packets.
- **German C1 is the stated bar, not a preference**; the letter states C1 and native English, and
  the form makes Deutschkenntnisse a required field. A German-language interview is fair game.
- **Travel:** readiness to travel within Germany is required, explicitly *with limited travel in
  support and operations*. Acceptable.
- **Sponsorship:** none needed — US citizen with German permanent residence. The form asks no
  permit question, so nothing to declare.

## Projection audit

Scorer terms, strongest first: **system** (24.079), **cloud** (14.603), **cloud-native** (8.625),
**cloud-technologien** (8.625), **system-monitoring** (8.625), **systemhaus** (8.625).

- **Highlights: 10 of 32** across the five roles.
- **Projects: 4 of 10** — `Masterarbeit: Wetter und Volatilität`, `Postgraduales Studium:
  Erneuerbare Energien`, `nixconfig`, `matt.bountystash.com`. `nixconfig` is the one that matters
  here and it is kept; `bountystash` (the Go service) is dropped again, so the Go evidence lives in
  the letter only.
- **Headings are German** (`Berufserfahrung`, `Projekte`, `Kenntnisse`, `Sprachen`) and tagged
  `/H1`, so a German ATS reads sections rather than bold runs.

## Alignment and honest gaps

Matches, every one inspectable in this repo:

- **Linux as the operating system, not a checkbox** — thirteen NixOS hosts declared from one
  flake, feature-list registration, derived option surface, one module gate in CI and on the
  machines.
- **Automation and configuration management** — version-controlled, pinned inputs, hermetic
  builds; a change reaches a host only by passing the gate, which is exactly the
  "standardised operating processes" the posting asks for.
- **System monitoring and management** — sentinel writes job status, generation age, disk and PSI
  every fifteen minutes; gatus pages on any non-ok state; a green socket is not accepted as a
  finished job.
- **Scripting in the three languages named** — Bash for operations, Python for analysis, Go for
  services (`bountystash`, a single-binary service with HTTP endpoints and a TUI).
- **Customer-facing work** — advised energy-trading clients and acted as in-house risk manager;
  ran O&M due diligence at O3 Energy; wrote documentation meant to be used without him. That is
  the presales/consulting half of the role, in a different industry.
- **Freiburg office, 25 km away** — no relocation, no weekly commute question.

Gaps, all named in the letter:

1. **Red Hat and SUSE are not in the administration history.** NixOS is the home distribution;
   RHEL/SUSE support paths and certifications would be learned on the job.
2. **No certificates** — no RHCE/RHCSA, no SUSE CLA. SVA's own training offer is a selling point
   here, but the missing paperwork is real.
3. **No IT-presales history** — the customer work was energy trading and due diligence, not
   infrastructure sales; the workshops and technical explanations transfer, the product catalogue
   does not.
4. **Virtualisation and hypervisor work is thin** — no VMware/Proxmox/Nutanix operation in the
   corpus.
5. **Certificates for the upload do not exist in this repo** — the posting asks for Zeugnisse.

## Submit-time checklist

1. Open `f734` from the posting's "Jetzt bewerben!" button (accept the cookie banner first, or the
   click is swallowed).
2. Fill the fields above; do not enter a birth date or upload a photo.
3. Upload `anschreiben.pdf` in the required slot and `lebenslauf.pdf` in LEBENSLAUF; add the
   certificates once the operator supplies them.
4. Salary `85000`, earliest entry `01.12.2026`, Deutschkenntnisse `C1`, "Wie gefunden" from the
   job-board options.
5. Tick the Datenschutz agreement, press **Senden**, and keep the confirmation.
6. Move the record to `applied` with the receipt date.

## Next action

Review the two PDFs, then supply the certificates that the form's attachment slots expect. Nothing
has been sent; the record stays at `prep` until it is.
