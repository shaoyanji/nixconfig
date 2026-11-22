#set document(title: "Application Grafana Labs — Staff Software Engineer, Databases SRE", author: "Matt Ji")
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
  Grafana Labs \
  Databases SRE team \
  Germany, remote
]

#v(13pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(5pt)
#text(weight: "bold")[Application: Staff Software Engineer — Databases SRE (Germany, remote)]

#v(4pt)
Dear Hiring Team,

#v(2pt)
I have not operated Prometheus, Grafana or a database fleet. At a company whose product is the observability stack, that is the first thing worth saying rather than the last, and for a Staff role it is a real distance rather than a detail.

#v(2pt)
What I have done is build the same capability from nothing, because there was no budget for the stack. Over five years I ran thirteen servers as one declarative fleet and wrote the telemetry myself: a sentinel job records job status, generation age, disk pressure and PSI every 15 minutes into a JSONL ledger; Gatus checks the endpoints; a bridge I wrote in Go acknowledges an alert only when delivery is confirmed. That last part is the one I would defend in a design review. An alert that fires but never arrives is worse than no alert, because it buys a false belief that someone is watching. Diagnosis runs backwards through the same data: ledger first, then logs, then the packet. Every cause goes into a runbook, so the next incident is shorter.

#v(2pt)
The Linux underneath is where I am strongest: cgroup limits per service, PSI treated as a measurement rather than a symptom, systemd hardening, namespaces, nftables as code, installs over PXE from a local archive. Deploys are gated on the same state that ships, every state is kept as a generation, and rollback is a decision rather than an incident. Go is the language I reach for when a shell script stops being enough — the alerting bridge and the router of a self-hosted model platform both run in production on my own hardware.

#v(2pt)
What I would be learning, plainly: Prometheus and Grafana in production, OpenTelemetry and trace pipelines, and how databases behave at Grafana Cloud scale. I would be joining as someone who understands why those systems exist and what they must not do, not as someone who has tuned them. If the team needs a Staff engineer who can carry the database layer on day one, I am not that person.

#v(2pt)
Practicalities: I am based in Germany and set up for fully remote work, with US citizenship and permanent German residence, so no sponsorship or relocation is involved. German is C1 and English native, which suits a distributed team. The repository is public and unglamorous in the way real operations are: github.com/shaoyanji/nixconfig

#v(4pt)
Kind regards,

#v(16pt)
Matt Ji
