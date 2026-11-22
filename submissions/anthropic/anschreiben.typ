#set document(title: "Application — Anthropic, Staff+ Data Infrastructure", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  Anthropic \
  Data Infrastructure \
  San Francisco / Seattle / New York
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Staff+ Software Engineer, Data Infrastructure]

#v(4pt)
Dear Anthropic team,

#v(2pt)
I have built the small version of the system your team operates: a fleet that writes structured records about itself every fifteen minutes, storage whose capacity was planned from measured pressure rather than a guess, access granted as short-lived certificates from an own CA, and an audit trail that existed because the system was built that way rather than because someone asked. That is a data infrastructure problem at thirteen hosts. Your posting describes the same problem at a scale where the interesting failures live.

#v(2pt)
The part I would bring is the instinct about what makes data systems trustworthy in practice. A pipeline is only as good as its ability to answer "what happened" months later, so records are structured, timestamps are honest, and delivery is confirmed rather than assumed. Storage is a capacity question before it is a performance question, which is why pressure is measured continuously. Access is a short-lived credential, not a shared key, and the audit trail is a byproduct of how changes enter the system, not a separate project.

#v(2pt)
What is missing matters more here. I have never used Spark or a distributed data processing framework, never worked with petabyte-scale data, and never owned a cloud storage service — my infrastructure is thirteen machines I bought and ran. I have also not operated at Staff+ scope, setting direction across teams rather than owning a platform end to end. This is a role where those are the job, not the onboarding, and I would rather say so than have a system design interview discover it.

#v(2pt)
I am applying because the reliability and auditability questions are the ones I find worth spending years on, and because Anthropic's mission makes those questions matter beyond the company. I am a German resident with permanent residence, native English and German C1; the posting's travel and US-site expectations would need discussing. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
