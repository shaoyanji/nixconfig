#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.58em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Zuverlässigkeit für Energieplattformen — Linux, Telemetrie, reproduzierbare Auslieferung]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre Betrieb einer Plattform, die niemand neu starten konnte: dreizehn Linux-Hosts, drei Hardware-Generationen, begrenzte Ressourcen, kein Managed Cloud. Telemetrie ist selbst gebaut — ein Ledger schreibt alle fünfzehn Minuten Jobstatus, Generation-Alter, Speicher- und Prozessdruck in ein Protokoll, Prüfungen von außen messen Erreichbarkeit, und eine Brücke in Go führt einen Alarm erst dann als gemeldet, wenn die Zustellung bestätigt ist. Davor fünf Jahre Energiewirtschaft: 10 MW Solarleistung kaufmännisch betreut, Betriebsdaten ausgewertet, Software und IT des Unternehmens verantwortet. Dazwischen Forschung am Fraunhofer ISE. Was fehlt, steht im Anschreiben.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(6pt)
  #text(size: 10.5pt, weight: "bold", fill: rgb("#1f2937"))[#kind]
  #v(1pt)
  #line(length: 100%, stroke: 0.4pt + rgb("#e5e7eb"))
  #v(2pt)
]

#let entry(title, when, bullets) = block(breakable: false, width: 100%)[
  #par[
    #text(weight: "bold")[#title]
    #if when != "" [#text(size: 8.5pt, fill: rgb("#4b5563"))[ — #when]]
  ]
  #if bullets != () [
    #v(1pt)
    #block(inset: (left: 10pt, top: 0pt, bottom: 0pt))[
      #for bullet in bullets [- #bullet]
    ]
  ]
  #v(4pt)
]

#section("Berufserfahrung")
#entry("Bountystash — Gründer und alleiniger Systembetreiber", "2020 – 2025", (
  "Dreizehn Linux-Hosts über drei Hardware-Generationen betrieben, gehärtet und erneuert, ohne Reserve und ohne Managed Cloud",
  "Verfügbarkeit als Schleife gebaut: Ledger alle fünfzehn Minuten, Prüfungen von außen auf Erreichbarkeit und Antwortzeit, Alarmbrücke mit Zustellbestätigung",
  "Speicher- und Prozessdruck, Alter der laufenden Generation und Plattenplatz als Vorlaufgrößen geprüft, weil sie einem Ausfall vorausgehen",
  "Auslieferung über gepinnte Eingaben und eine Prüfung des ausgewerteten Systems; Rückkehr zur vorigen Generation in Minuten statt in einer Nacht",
  "Sicherungen mit restic und tatsächlich durchgeführten Rückspielungen; Wiederherstellung geübt, nicht angenommen",
  "Sicherheit im Betrieb: eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, sops und age je Host, nftables, WireGuard ohne öffentlichen Listener",
  "Werkzeuge in Python, Go und Shell für Rollout, Auswertung, Berichte und Alarmwege; Dokumentation aus dem Bestand erzeugt",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung: Erträge, Verträge, Abrechnung und Betriebsdaten",
  "Betriebsdaten ausgewertet und als Entscheidungsgrundlage für die Geschäftsführung aufbereitet",
  "Software und IT des Unternehmens verantwortet — von der Beschaffung bis zum Betrieb",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau im Labor betreut: Geräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "Messdaten nachvollziehbar abgelegt, damit Ergebnisse über die Projektlaufzeit hinaus prüfbar bleiben",
))

#section("Projekte")
#entry("nixconfig — eine Plattform, einmal beschrieben", "seit 2023", (
  "Ein Host registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen aus derselben Beschreibung",
  "Zustand, Auswertung und Entscheidung getrennt: der Bestand beschreibt, das Ledger beobachtet, die Auswertung entscheidet",
  "Selbst betriebene Dienste hinter offenen Schnittstellen, inklusive Modelldienste mit Bedarfsladung und Rechenbremse",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst messen, dann ändern: ohne Vorher-Nachher-Wert ist eine Änderung eine Vermutung. \
  - Alarmierung ist erst fertig, wenn die Zustellung bestätigt ist; alles andere ist ein Dashboard. \
  - Aufschreiben, was war: ein Vorfall ohne Notiz wird beim nächsten Mal wieder ein Vorfall.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Plattform] — Linux-Hosts, reproduzierbare Auslieferung, Gates, Rückrollung über Generationen, PXE-Installation \
#text(weight: "bold")[Telemetrie] — Ledger mit Zeitstempel, Prüfungen von außen, Alarmbrücke mit Zustellbestätigung, Vorlaufgrößen statt Ausfallmeldungen \
#text(weight: "bold")[Energie] — Photovoltaik-Assetbetreuung, Ertrags- und Betriebsdaten, energiewirtschaftliche Bewertung, M.Sc. Renewable Energy Management \
#text(weight: "bold")[Code] — Python, Go, Shell, Nix; Automatisierung, Berichte, erzeugte Dokumentation \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes, Terraform, Ansible, Cloud-Plattformen, Prometheus, Grafana, großen Kafka-Betrieb, regulierten KRITIS-Betrieb \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Fernarbeit aus Deutschland, Umzug möglich
