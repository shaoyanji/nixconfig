---
title: the CV site was redesigned for a parser
about:
  - doc:docs/cv-ats-compliance.md
  - doc:AGENTS.md
---

## The question

A CV is read twice: once by an applicant tracking system that files it before a person opens it, and once by the person. The site redesign started from the uncomfortable half — the parser — because a beautiful document that files itself as unsorted text is a document nobody reads.

## What the parser saw

The old templates were traditional rather than wrong: a header in two columns, contact details on the right, section headings in uppercase with letter-spacing, dates parked in a right-hand column, a footer repeating the name and email on every page.

Each of those is a column jump or a case change. An extractor that reads in document order emits the contact block after the summary. One that drops footers loses the identity line. Exact-match section detection sees `E X P E R I E N C E` and finds no section at all, so the technologies and the work permit — the two things a filter searches for — land in the unsorted pile.

## What changed

The header stacks into one column and the contact URLs are plain text, not link labels a parser may strip. Dates sit on the line they date. Headings use the standard words — `Experience`, `Projects`, `Skills`, `Languages`, and the German equivalents — in normal case, with no tracking, and a heading can no longer end a page alone. The footer is a page number, and a one-page document has none.

The site itself changed with them: every case study and brief now links the CV tailored to it, so the document a reader downloads is already the one that matches the page they were on.

## What it cost

Nothing measurable. The page budgets still hold: the full CV stays at two pages, the German one at two, the tailored energy CV at one. The redesign bought legibility for a machine without spending a millimetre of the reader's page.

The lesson is narrower than "design for robots". It is that the document has two audiences with different failure modes, and only one of them complains. The parser quietly misfiles you; the person simply never sees the file.
