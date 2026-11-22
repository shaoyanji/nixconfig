#set document(title: "Bewerbung T-Systems — SRE Observability", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  Deutsche Telekom AG \
  T-Systems International GmbH \
  Referenz 12444-563465374109848-DT-S \
  Standort Karlsruhe
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Site Reliability Engineer (SRE) (m/w/d), Schwerpunkt Observability]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Observability heißt für mich nicht, ein Dashboard zu haben, an dem jemand vorbeigeht. Sie heißt, dass das System eine Aussage über seinen eigenen Zustand macht und dass diese Aussage ankommt. Ich habe fünf Jahre lang ohne Prometheus und ohne Grafana Betrieb gemacht — nicht aus Überzeugung, sondern weil niemand einen Stack bezahlt hätte. Also habe ich die Messung selbst gebaut.

#v(2pt)
Konkret: Ein Sentinel-Job schreibt alle 15 Minuten Jobstatus, Generation-Alter sowie Disk- und PSI-Druck in ein JSONL-Ledger. Gatus prüft die Endpunkte. Eine in Go geschriebene Bridge nimmt einen Alarm und bestätigt ihn erst, wenn die Zustellung nachweislich erfolgt ist — ein ausgelöster Alarm ist nicht dasselbe wie ein zugestellter, und die Verwechslung ist der teuerste Fehler in der ganzen Kette. Diagnose läuft rückwärts aus denselben Daten: erst das Ledger, dann die Logs, dann das Paket. Darunter steht ein deklarativer Betrieb mit Generationen und Rückrollung, sodass eine Änderung immer einen Weg zurück hat.

#v(2pt)
Was ich nicht mitbringe, sage ich vor der ersten Zeile der Anforderungen: kein OpenTelemetry, kein verteiltes Tracing, kein Prometheus, kein Grafana, kein Loki, kein AlertManager, kein Kubernetes. Ihre Anzeige nennt Observability und Tracing als Schwerpunkt; das ist die halbe Stelle, und ich habe sie nicht. Was ich habe, ist die Gewohnheit, Telemetrie so zu bauen, dass sie unter Knappheit trägt — und die Fähigkeit, einen Stack zu verstehen, dessen Bausteine ich von Hand nachgebaut habe.

#v(2pt)
Karlsruhe ist der nächste Ihrer zehn Standorte: von Gutach im Breisgau rund anderthalb Stunden, mein Wohnsitz liegt in Baden-Württemberg. Hybrides Arbeiten mit Präsenz bei Bedarf ist deshalb die passende Form, ein Umzug in die Region nach erprobter Zeit denkbar. Ich bin US-Amerikaner mit Niederlassungserlaubnis, brauche also keinen Visa-Sponsor. Deutsch C1, Englisch Muttersprache. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
