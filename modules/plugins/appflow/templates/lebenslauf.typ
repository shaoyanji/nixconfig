// Lebenslauf / Résumé — the standard JSON Resume schema, one template, two
// languages.
//
// Inputs, written by `packet.nix` next to this file:
//   resume.json       https://jsonresume.org/schema — basics, work, education,
//                     projects, skills, languages
//   application.json  { "language": "de" | "en" } plus the record's company/role
//   strings.json      the localized headings
//
// Personal data never lives in this tree: `resume.json` is read from
// ~/.config/appflow/ at build time.
#let resume = json("resume.json")
#let application = json("application.json")
#let all-strings = json("strings.json")
#let lang = application.at("language", default: "de")
#let strings = all-strings.at(lang, default: all-strings.at("de"))
#let basics = resume.at("basics", default: (:))

// PDF properties, not layout: a parser that files a document by its metadata before
// reading a line of text finds the candidate's name here. `cv.typ` sets the same two
// fields; this template set none, so the extracted text held the name while the
// document properties were empty.
#set document(
  title: basics.at("name", default: "") + " — " + (if lang == "de" { "Lebenslauf" } else { "Résumé" }),
  author: basics.at("name", default: ""),
)

#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
// Libertinus ships with Typst: no font package, no network, identical output on
// every host that has this flake.
// `hyphenate: false`: German compounds hyphenate under justification, and a
// keyword broken as `Schwachstellen-` / `programme` is a keyword an ATS does not
// match. Ragged-but-whole words are worth the loose right edge.
#set text(font: ("Libertinus Serif", "New Computer Modern"), size: 9.5pt, fill: rgb("#111827"), lang: lang, hyphenate: false)
#set par(leading: 0.5em, justify: true)

// ---- header, from `basics` ------------------------------------------------
#let location = basics.at("location", default: (:))
#let place = {
  let town = ()
  if location.at("postalCode", default: "") != "" { town.push(location.postalCode) }
  if location.at("city", default: "") != "" { town.push(location.city) }
  let parts = ()
  if location.at("address", default: "") != "" { parts.push(location.address) }
  if town.len() > 0 { parts.push(town.join(" ")) }
  parts.join(", ")
}
#let profiles = basics.at("profiles", default: ())
#let contact = {
  let parts = ()
  if basics.at("email", default: "") != "" { parts.push(basics.email) }
  if basics.at("phone", default: "") != "" { parts.push(basics.phone) }
  for profile in profiles { parts.push(profile.at("url", default: profile.at("username", default: ""))) }
  // The German corpus carries no `profiles`: keep one link rather than none.
  if profiles.len() == 0 and basics.at("url", default: "") != "" { parts.push(basics.url) }
  if place != "" { parts.push(place) }
  parts.join(" • ")
}

#align(center)[
  #text(size: 19pt, weight: "bold")[#basics.at("name", default: "")]
  #if basics.at("label", default: "") != "" [
    #v(1pt)
    #text(size: 9pt, fill: rgb("#4b5563"))[#basics.label]
  ]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[#contact]
]

#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

// The summary is the one part of `basics` a reader scans before the roles: it was
// the only field of the source document the packet never printed.
#if basics.at("summary", default: "") != "" [
  #v(6pt)
  #text(size: 9pt)[#basics.summary]
]

// ---- helpers --------------------------------------------------------------
#let year(value) = {
  if value == none or value == "" { none } else { value.split("-").at(0) }
}

#let period(start, end) = {
  let first = year(start)
  if first == none { "" } else {
    let last = if year(end) == none { strings.at("present") } else { year(end) }
    // A six-month role printed "2012 – 2012".
    if last == first { first } else { first + " – " + last }
  }
}

// A heading is derived from the section in the application's language; the data
// never carries translated headings. It is set in its own case, not uppercased:
// `Berufserfahrung` is the string a parser matches.
// `sticky`: without it the compiled lebenslauf ended page 2 on `Kenntnisse` with
// every skill on page 3 — a heading alone at the foot of a page. cv.typ keeps its
// headings with `sticky` for the same reason.
#let section(kind) = heading(strings.at(kind, default: kind), level: 1)
// A real `heading`, so the section word is tagged `/H1` in the structure tree
// rather than existing as a bold run a parser has to recognise. Level 1: each
// section is a top-level division, and PDF/UA-1 rejects a first heading at any
// other level. The show rule keeps the previous block's rendering; a heading
// element ends its paragraph, so the document grows about 2mm per section
// (example corpus 208 to 219mm, full corpus 105 to 109mm). No page count moves —
// 1 page and 3 pages respectively — so nothing is subtracted here, unlike cv.typ
// where the same gap broke a one-page budget.
#set heading(numbering: none)
#show heading: it => block(breakable: false, sticky: true, width: 100%)[
  #v(5pt)
  #text(size: 10.5pt, weight: "bold", fill: rgb("#1f2937"))[#it.body]
  #v(1pt)
  #line(length: 100%, stroke: 0.4pt + rgb("#e5e7eb"))
  #v(2pt)
]

// One column: the date follows the entry it dates, instead of sitting in a
// right-hand column an ATS may read out of order. docs/cv-ats-compliance.md.
#let entry(title, subtitle, when, bullets) = block(breakable: false, width: 100%)[
  #par[
    #text(weight: "bold")[#title]
    #if when != "" [#text(size: 8.5pt, fill: rgb("#4b5563"))[ — #when]]
  ]
  #if subtitle != "" [#text(size: 8.5pt, fill: rgb("#4b5563"))[#subtitle]]
  #if bullets != () [
    #v(1pt)
    #block(inset: (left: 10pt, top: 0pt, bottom: 0pt))[
      #for bullet in bullets [- #bullet]
    ]
  ]
  #v(3pt)
]

// ---- sections ------------------------------------------------------------
#if resume.at("work", default: ()) != () [
  #section("experience")
  // `sect`, not `block`: a loop variable named `block` shadows Typst's own
  // function and the layout then fails to compile.
  #for job in resume.at("work", default: ()) [
    #entry(
      // Employer first, then the role: that is the order their own Lebenslauf
      // used, and it reads correctly when the employer is the familiar name.
      (job.at("name", default: "") + if job.at("position", default: "") != "" [ — #job.position] else { "" }),
      job.at("location", default: ""),
      period(job.at("startDate", default: ""), job.at("endDate", default: "")),
      job.at("highlights", default: ()),
    )
  ]
]

#if resume.at("projects", default: ()) != () [
  #section("projects")
  // A project the corpus records only as a name and a period is not a CV entry.
  // Where there are no bullets the resume's one-line `description` is the
  // content; printing `entity` ("Personal", "Founder", a lab name) and nothing
  // else is what left seven bare headings on the full CV. An entry with neither
  // bullets nor a description is skipped rather than shipped empty.
  #for project in resume.at("projects", default: ()) [
    #let bullets = project.at("highlights", default: ())
    #let blurb = project.at("description", default: "")
    #if bullets.len() > 0 or blurb != "" [
      #entry(
        project.at("name", default: ""),
        if bullets.len() == 0 { blurb } else { project.at("entity", default: blurb) },
        period(project.at("startDate", default: ""), project.at("endDate", default: "")),
        bullets,
      )
    ]
  ]
]

#if resume.at("education", default: ()) != () [
  #section("education")
  #for study in resume.at("education", default: ()) [
    #entry(
      study.at("institution", default: ""),
      {
        let kind = study.at("studyType", default: "")
        let area = study.at("area", default: "")
        if kind != "" and area != "" { kind + ", " + area } else { kind + area }
      },
      period(study.at("startDate", default: ""), study.at("endDate", default: "")),
      study.at("courses", default: ()),
    )
  ]
]

#if resume.at("skills", default: ()) != () [
  #section("skills")
  #for skill in resume.at("skills", default: ()) [
    #text(weight: "bold")[#skill.at("name", default: "")]
    #if skill.at("keywords", default: ()) != () [
      #text(size: 9pt)[ — #skill.keywords.join(", ")]
    ]
    \
  ]
]

#if resume.at("languages", default: ()) != () [
  #section("languages")
  #for spoken in resume.at("languages", default: ()) [
    #text(size: 9pt)[#spoken.at("language", default: "") — #spoken.at("fluency", default: "")] \
  ]
]

// No closing `Generated from the application database` line: it named where the
// file came from, not the candidate, so it was the one line of the document an
// ATS could not place in a section — the letterhead footer this template
// otherwise avoided. Why: docs/cv-ats-compliance.md.

// typeset report — read back by the build (lib/typeset.nix) -------------------
// The page count and how far down its last page the content reached. A packet who
// spills a line onto a second page fails its build rather than shipping that page.
#context [
  #metadata((
    pages: counter(page).final().first(),
    last: int(calc.round(here().position().y / 1mm)),
  )) <typeset>
]
