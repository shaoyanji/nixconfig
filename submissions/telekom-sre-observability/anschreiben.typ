#set document(title: "Bewerbung — T-Systems, SRE Observability", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig
]

#v(12pt)

#text(size: 9pt)[
  Deutsche Telekom AG / T-Systems International GmbH \
  Site Reliability Engineer (SRE) — Schwerpunkt Observability \
  Referenz 12444-563465374109848-DT-S
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(4pt)
#text(weight: "bold")[Bewerbung als Site Reliability Engineer, Schwerpunkt Observability]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Eine Observability-Plattform beantwortet im Störfall eine einzige Frage: wo in einer Kette aus Diensten ist es passiert. Fünf Jahre lang habe ich diese Frage ohne Werkzeugkasten beantwortet, weil das Budget für einen gab es nicht: ein Ledger schreibt alle fünfzehn Minuten einen Datensatz je Host — Jobstatus, Alter der laufenden Generation, Plattenplatz, Speicher- und Prozessdruck; Prüfungen laufen von außen, damit sich ein Host nicht selbst die Erreichbarkeit bescheinigt; und ein Alarmkanal in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist. Ausgelöst und zugestellt sind bei mir zwei verschiedene Zustände.

#v(2pt)
Wo die Kette länger wird, hört diese Handarbeit auf. Ohne Tracing korreliere ich über Zeitstempel, Hostnamen und Logzeilen — das funktioniert bei dreizehn Knoten und wird bei verteilten Diensten zur Suche. Genau diesen Schritt automatisiert ein Collector mit Context Propagation, und genau deshalb bewerbe ich mich auf eine Stelle, die ihn einführt: Ich kenne den Schmerz, den Sampling-Strategien und Trace Storage lösen sollen, weil ich ihn ohne sie getragen habe.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: OpenTelemetry habe ich nicht betrieben, weder Collector noch OTLP, SDKs oder Auto-Instrumentation; verteiltes Tracing mit Span-Korrelation, Context Propagation und Sampling kenne ich als Konzept, nicht aus dem Betrieb, und Jaeger weder als Speicher noch als Abfrageplattform. SIEM-Integration mit CEF ist neu für mich, Kubernetes ebenso; Prometheus, Grafana und Loki habe ich nicht im Einsatz. Was ich mitbringe, ist der Unterbau: Linux und systemd im Griff, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten und Secrets pro Host, Go, Python und Shell für die Werkzeuge selbst, und die Gewohnheit, eine Änderung erst als fertig zu betrachten, wenn ein Messwert sie bestätigt.

#v(2pt)
Von den zehn ausgeschriebenen Standorten ist Karlsruhe der nächste — rund anderthalb Stunden von Gutach im Breisgau, und ich bin bereit, dort regelmäßig vor Ort zu sein. Deutsch ist C1, Englisch Muttersprache, die Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
