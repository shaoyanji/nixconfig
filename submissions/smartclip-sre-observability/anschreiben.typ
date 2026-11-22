#set document(title: "Application smartclip — Site Reliability Engineer, Observability and Internal Tools", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.9cm, bottom: 1.9cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.55em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(13pt)

#text(size: 9pt)[
  smartclip Europe GmbH \
  Berlin and Cologne, Germany
]

#v(13pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(5pt)
#text(weight: "bold")[Application: Site Reliability Engineer (f/m/d) — Observability and Internal Tools]

#v(4pt)
Dear Hiring Team,

#v(2pt)
You ask for evidence of building rather than configuring, so I will start with what I built and then say what I did not. Over five years I ran thirteen servers as one declarative NixOS fleet: every service a module, every host a feature list, every change a commit that a gate had to pass, every previous state kept as a generation I could return to. Nothing was configured by hand, which means nothing drifted.

#v(2pt)
Observability came the same way. I did not have a dashboard to look at, so I wrote the measurement: a sentinel job that records job status, generation age, disk use and PSI pressure into a JSONL ledger every 15 minutes. Gatus checks the endpoints. A bridge written in Go takes an alert and only acknowledges it once delivery is confirmed, because an alarm nobody received is worse than no alarm — it is a false belief that someone is watching. The loop closes: pressure shows up as a number, the number has an owner, the owner gets a message that provably arrived.

#v(2pt)
That is the same reasoning I would bring to SLOs and error budgets, and I should be plain about the limit: I have not run a formal SLO programme. My budgets were informal — how much disk headroom, how old a generation, how long an alert could sit unconfirmed. What I lack is the discipline of writing targets down with a team and letting them govern releases. What I have is the habit of measuring before promising.

#v(2pt)
The honest gap is the tooling in your first requirement: no Prometheus, no Grafana, no Alertmanager in production. I know what they are for and I know my stack is a substitute, not an equivalent — instrumenting exporters and writing recording rules would be new work, not a rename of old work. Everything around it is not new: Linux internals with cgroup limits and PSI, infrastructure as code, security in the delivery path through sops, age, an own CA and short-lived certificates, and internal tools other people actually used.

#v(2pt)
Two practical points. I am a US citizen with permanent German residence, so no sponsorship is needed and I can start without immigration steps. My salary expectation is 80,000 to 85,000 EUR. Remote-first suits how I have worked for years; I am glad to travel for architecture sessions and planning. The repository is public and unpolished in the way real operations are: github.com/shaoyanji/nixconfig

#v(4pt)
Kind regards,

#v(16pt)
Matt Ji
