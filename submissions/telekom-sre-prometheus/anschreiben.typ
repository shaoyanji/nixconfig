#set document(title: "Bewerbung — T-Systems, Site Reliability Engineer Prometheus", author: "Matt Ji")
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
  T-Systems International GmbH \
  Site Reliability Engineer (SRE), Schwerpunkt Prometheus \
  Referenz 12444-563465374109756-DT-S
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(4pt)
#text(weight: "bold")[Bewerbung als Site Reliability Engineer, Schwerpunkt Prometheus]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ein Alarm ist zuerst ein Zustellproblem und erst danach ein Messproblem. Diese Reihenfolge habe ich fünf Jahre lang auf eigener Hardware gelernt: dreizehn Linux-Hosts, begrenzte CPU, begrenzter Speicher, kein Managed Cloud, keine öffentliche Schnittstelle. Ein Sentinel-Job schreibt alle fünfzehn Minuten Jobstatus, Alter der laufenden Generation, Speicher- und Prozessdruck und Plattenplatz in ein Ledger. Prüfungen von außen messen Erreichbarkeit und Antwortzeit. Eine Brücke in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist — ein Alarm, der ausgelöst und nie zugestellt wird, ist schlimmer als keiner, weil er einen falschen Glauben erzeugt.

#v(2pt)
Für Edge-Umgebungen ist genau das die entscheidende Eigenschaft: Die Datenquelle ist klein, die Leitung ist schmal, und trotzdem muss eine Entscheidung vor Ort fallen. Ich habe gelernt, mit knappen Ressourcen zu planen statt gegen sie anzukämpfen: Abtastrate und Aufbewahrung sind eine Entscheidung über Kosten, Logrotation ist eine Entscheidung über Beweise, und Rückrollung über die vorige Generation dauert Minuten statt einer Nacht. Infrastruktur steht bei mir als Beschreibung im Repository, nicht als Handarbeit auf der Maschine; jede Änderung läuft durch eine Prüfung.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: Prometheus habe ich nicht als Server betrieben — kein PromQL, keine Federation, kein Remote Write — und Grafana, Loki und AlertManager ebenso wenig, also kein LogQL, kein Routing und keine Inhibition. Die einzige Standardkomponente in diesem Bild ist ein einzelner node_exporter auf Port 9100 im Tailnet; ausgewertet habe ich daneben das eigene Ledger, das aus derselben Quelle schöpft, aber selbst geschrieben ist. Kubernetes-Monitoring, YAML-Konfiguration im großen Stil, Terraform, Ansible und OpenTelemetry kenne ich nicht aus dem Betrieb. Einen regulierten KRITIS-Betrieb mit Nachweispflichten habe ich nicht verantwortet. Meine Telemetrie ist selbst gebaut, nicht aus Standardkomponenten zusammengestellt — die Denkweise ist dieselbe, der Werkzeugkasten ist es nicht.

#v(2pt)
Karlsruhe ist von meinem Wohnort in etwa eineinhalb Stunden erreichbar, hybrides Arbeiten passt zu meinem Arbeitsstil. Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
