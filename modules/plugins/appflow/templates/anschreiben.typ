// Anschreiben — cover letter from JSON, in the language of the application.
//
// Inputs, written by `packet.nix` next to this file:
//   letter.json   { "salutation", "subject", "paragraphs": [ "..." ], "closing" }
//   resume.json   JSON Resume — the letter uses `basics` only
//   application.json { "company", "role", "apply_url", "language" }
#let letter = json("letter.json")
#let resume = json("resume.json")
#let basics = resume.at("basics", default: (:))
#let application = json("application.json")
#let lang = application.at("language", default: "de")
#let all-strings = json("strings.json")
#let strings = all-strings.at(lang, default: all-strings.at("de"))
#let months = strings.at("months", default: ())
#let location = basics.at("location", default: (:))
#let address = {
  let parts = ()
  if location.at("address", default: "") != "" { parts.push(location.address) }
  if location.at("postalCode", default: "") != "" { parts.push(location.postalCode) }
  if location.at("city", default: "") != "" { parts.push(location.city) }
  if location.at("countryCode", default: "") != "" { parts.push(location.countryCode) }
  parts.join(", ")
}
#let contact = {
  let parts = ()
  if basics.at("email", default: "") != "" { parts.push(basics.email) }
  if basics.at("phone", default: "") != "" { parts.push(basics.phone) }
  if basics.at("url", default: "") != "" { parts.push(basics.url) }
  parts.join(" • ")
}

#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "New Computer Modern"), size: 10pt, fill: rgb("#111827"), lang: lang)
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

// Sender block: who is writing, in the shape a German letter expects.
#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[#basics.at("name", default: "")] \
  #address \
  #contact
]

#v(14pt)

#text(size: 9pt)[
  #application.at("company", default: "") \
  #if application.at("apply_url", default: "") != "" [
    #link(application.at("apply_url"))[#application.at("apply_url")]
  ]
]

#v(14pt)
// The date comes from the packet, never from datetime.today(): a Nix build
// runs with SOURCE_DATE_EPOCH=1980-01-01, so "today" inside the sandbox is not
// today. The task passes the real date in, and it is part of the build hash.
#let date-text = if application.at("date", default: "") == "" {
  []
} else {
  let parts = application.date.split("-")
  [#(int(parts.at(2))). #(months.at(int(parts.at(1)) - 1)) #(parts.at(0))]
}
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[#date-text]]

#v(6pt)
#text(weight: "bold")[#letter.at("subject", default: "Bewerbung")]

#v(4pt)
#letter.at("salutation", default: "Sehr geehrte Damen und Herren,")

#v(2pt)
#for paragraph in letter.at("paragraphs", default: ()) [
  #paragraph

  #v(2pt)
]

#v(4pt)
#letter.at("closing", default: "Mit freundlichen Grüßen")

#v(18pt)
#basics.at("name", default: "")

// typeset report — read back by the build (lib/typeset.nix) -------------------
#context [
  #metadata((
    pages: counter(page).final().first(),
    last: int(calc.round(here().position().y / 1mm)),
  )) <typeset>
]
