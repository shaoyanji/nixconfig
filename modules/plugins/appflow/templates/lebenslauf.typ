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

#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
// Libertinus ships with Typst: no font package, no network, identical output on
// every host that has this flake.
#set text(font: ("Libertinus Serif", "New Computer Modern"), size: 9.5pt, fill: rgb("#111827"), lang: lang)
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

// ---- helpers --------------------------------------------------------------
#let year(value) = {
  if value == none or value == "" { none } else { value.split("-").at(0) }
}

#let period(start, end) = {
  let first = year(start)
  if first == none { "" } else {
    let last = if year(end) == none { strings.at("present") } else { year(end) }
    first + " – " + last
  }
}

// A heading is derived from the section in the application's language; the data
// never carries translated headings.
#let section(kind) = block(breakable: false, width: 100%)[
  #v(5pt)
  #text(size: 10.5pt, weight: "bold", fill: rgb("#1f2937"))[#upper(strings.at(kind, default: kind))]
  #v(1pt)
  #line(length: 100%, stroke: 0.4pt + rgb("#e5e7eb"))
  #v(2pt)
]

#let entry(title, subtitle, when, bullets) = block(breakable: false, width: 100%)[
  #grid(
    columns: (1fr, auto),
    column-gutter: 8pt,
    [#text(weight: "bold")[#title]],
    [#text(size: 8.5pt, fill: rgb("#4b5563"))[#when]],
  )
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
  #for project in resume.at("projects", default: ()) [
    #entry(
      project.at("name", default: ""),
      project.at("entity", default: project.at("description", default: "")),
      period(project.at("startDate", default: ""), project.at("endDate", default: "")),
      project.at("highlights", default: ()),
    )
  ]
]

#if resume.at("education", default: ()) != () [
  #section("education")
  #for study in resume.at("education", default: ()) [
    #entry(
      study.at("institution", default: ""),
      (study.at("studyType", default: "") + " " + study.at("area", default: "")),
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

#v(8pt)
#align(center)[#text(size: 7.5pt, fill: rgb("#6b7280"))[#strings.at("generated", default: "")]]

// typeset report — read back by the build (lib/typeset.nix) -------------------
// The page count and how far down its last page the content reached. A packet who
// spills a line onto a second page fails its build rather than shipping that page.
#context [
  #metadata((
    pages: counter(page).final().first(),
    last: int(calc.round(here().position().y / 1mm)),
  )) <typeset>
]
