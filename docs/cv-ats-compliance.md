# ATS compliance: the CV and the Lebenslauf

An employer's applicant tracking system reads a resume's text layer and files it
before a person opens the file. It reads in document order, matches section
headings against a fixed vocabulary, and drops anything it cannot place into an
unsorted pile. Both templates now answer that: one column top to bottom, standard
heading words, contact details in the body, plain-text URLs, no letter-spacing and
no letterhead footer.

The rules live in the templates themselves. This page is the reason they are
shaped that way, and the measurement that says the change kept the page budgets
(`lib/typeset.nix`).

## What an ATS needs

| It reads | So the document |
| :--- | :--- |
| text in one column, top to bottom | stacks the header; puts a date on the line it dates instead of in a right-hand column |
| the standard section words | says `Experience`, `Projects`, `Education`, `Skills`, `Languages` (and the German equivalents) in the record's language |
| contact details as body text | keeps name, email, town and URLs in the first block of the page |
| the keywords as text | writes every technology as text, never as an image, a table cell or a link label |

## Violations found, before the change

| # | Finding | Where | Effect on a parser |
| --- | :--- | :--- | :--- |
| 1 | Header split into two columns (`grid(columns: (1fr, auto))`): name and role left, contact right | `lib/matt/cv.typ` header | the contact block is a second column; an extractor that reads by column emits it after the summary, not after the name |
| 2 | Footer repeated the name, the email and a page counter on every page | `lib/matt/cv.typ` page footer | a parser that keeps footers reads the name twice and the email in the wrong place; one that drops them loses the identity |
| 3 | Headings were uppercased and carried `tracking: 0.14em` | `head()` in `lib/matt/cv.typ`, `section()` in `lebenslauf.typ` | extraction returned `EXPERIENCE` and, with spacing, `E X P E R I E N C E`; exact-match section detection then finds no section |
| 4 | Contact URLs were link anchors (`#link(...)[text]`) | `lib/matt/cv.typ` header | a parser that strips link annotations can drop the visible text with them, or leave the label without its address |
| 5 | Each role, degree and project put its period in a right-hand column | `lib/matt/cv.typ` experience and education loops; `entry()` in `lebenslauf.typ` | the date is a column jump: it is read after the prose it belongs to, or on its own |
| 6 | Three headings were house words, not section words: `Selected projects`, `Tools`, `Languages and authorisation` (German: `Ausgewählte Projekte`, `Werkzeuge`, `Sprachen und Arbeitserlaubnis`) | `cvLabels` in `lib/matt-site.nix`, and the `labels` override in `cv-energy.json` / `cv-energy.de.json` | a heading the parser cannot classify turns that section into unsorted text, which is where the technologies and the work permit go |

Nothing else applied: neither template had a table, an image, a text box, a body
in two columns, or a skill written as a graphic. The data is plain text already,
and the fonts (New Computer Modern, Libertinus Serif) ship with Typst.

## What changed

| File | Change |
| :--- | :--- |
| `lib/matt/cv.typ` | header stacked into one column, contact URLs as plain text; headings in normal case at 9.7pt with no tracking; each role, degree and project on one line with its period; footer reduced to the page number (`1/2`), and omitted on a one-page document; `show link` rule removed because no link remains |
| `modules/plugins/appflow/templates/lebenslauf.typ` | `entry()` uses one column instead of a two-column grid; `section()` sets the heading in its own case, not uppercased |
| `lib/matt-site.nix` | `cvLabels` now carries the standard words: `Projects`, `Skills`, `Languages` / `Projekte`, `Kenntnisse`, `Sprachen`; the key `tools` became `skills` |
| `lib/matt/cv-energy.json`, `cv-energy.de.json` | the tailored CV overrides `projects` with `Projects` / `Projekte` instead of `Relevant projects` / `Relevante Projekte` |

The templates' own comments name this page, so a later edit that reintroduces a
grid column meets the reason it was removed.

## Measurement

Compiled with the pinned typst, from the four `cv.json` payloads the site build
produces, and from the resume corpora for the Lebenslauf. `last` is how far down
its last page the content reached, in millimetres.

| Document | Budget | Before | After |
| :--- | ---: | :--- | :--- |
| `cv.pdf` (full, English) | 2 | 2 pages, 53 mm | 2 pages, 72 mm |
| `cv-de.pdf` (full, German) | 2 | 2 pages, 72 mm | 2 pages, 88 mm |
| `cv-energy.pdf` (tailored) | 1 | 1 page, 270 mm | 1 page, 269 mm |
| `cv-energy-de.pdf` (tailored) | 1 | 1 page, 273 mm | 1 page, 273 mm |
| `lebenslauf.pdf`, full corpus, no selection | 1 in a packet | 3 pages, 52 mm | 3 pages, 52 mm |
| `lebenslauf.pdf`, selected from a job ad | 1 in a packet | 2 pages, 125 mm | 2 pages, 125 mm |

The floor is 40 mm of content on a final page once a document has a second page, so
no measurement above is near it. The Lebenslauf rows are unchanged because the
template edit is height-neutral: an inline date occupies the line the grid row
already used. Its packet budget is met by `select.py`, which narrows the corpus to
one page of material, not by the template.

The same numbers are what `lib/typeset.nix` reads back from each build's
`<typeset>` report, so a budget that stops fitting is a build error rather than a
page someone has to notice.

## Checked after the change

- `typst compile` succeeds on `lib/matt/cv.typ` and on
  `modules/plugins/appflow/templates/lebenslauf.typ`, and each still writes its
  `<typeset>` report.
- `pdftotext` order: name, role, contact, summary, `Experience`, roles, `Projects`,
  `Education`, `Skills`, `Languages` — the name at line 1 of the extracted text and
  the headings at lines 12, 42, 66, 73 and 79.
- No link annotation is left: a scan of the PDF bytes finds no `/URI`.
- The footer no longer carries `page 1 of`: on a one-page document it carries
  nothing, and on the full CV it carries only the page number, `1/2` and `2/2`.

## Limits of this check

No commercial ATS was run; the evidence is the extracted text, the annotation scan
and the layout rules above. The packet target was compiled from the corpus and from
a selection over a synthetic description, because the production selection depends
on the job ad it is built for.
