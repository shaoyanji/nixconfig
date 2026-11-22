#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 11pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.66em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systembetrieb — Betriebstelemetrie, Alarmierung, reproduzierbare Auslieferung]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre Linux-Betrieb, in dem die Beobachtung nicht am Ende stand, sondern am Anfang: ein Ledger, das alle fünfzehn Minuten schreibt, Prüfungen von außen auf Erreichbarkeit und Antwortzeit, ein Alarmkanal in Go, der eine Störung erst als gemeldet führt, wenn die Zustellung bestätigt ist. Dreizehn Hosts über drei Hardware-Generationen, aus einer Beschreibung gebaut, geprüft vor dem Rollout, rückrollbar in Minuten. Dazu die Messdisziplin aus der Forschung — 2012 am Fraunhofer ISE Messaufbau und Auswertung in Python, davor ein Ingenieurstudium an der Colorado School of Mines. Was an Tracing-Werkzeugen fehlt, steht im Anschreiben.]

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
  "Dreizehn Linux-Hosts über drei Hardware-Generationen installiert, gehärtet und im Dauerbetrieb gehalten, inklusive PXE-Installation",
  "Betriebstelemetrie selbst gebaut: JSONL-Ledger mit Zeitstempel alle fünfzehn Minuten — Jobstatus, Alter der laufenden Generation, Plattenplatz, Speicher- und Prozessdruck",
  "Alarme, die ankommen: eine Brücke in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist; ausgelöst und zugestellt werden nicht verwechselt",
  "Prüfungen von außen auf Erreichbarkeit und Antwortzeit; Diagnose aus Ledger und Logs statt aus Vermutungen",
  "Störungen im Journal eingegrenzt: erst der Zeitpunkt im Ledger, dann die systemd-Einheit und ihr Verlauf in journald, dann die Regel oder das Modul, das sie verursacht hat",
  "Signale vor dem Ausfall: Druck, Wachstum der Sicherungen und Alter der Generation als Vorlaufgrößen, nicht der Ausfall selbst",
  "Knoten als Beschreibung: gepinnte Eingaben, Prüfung vor dem Rollout, Rückkehr zur vorigen Generation in Minuten statt in einer Nacht",
  "Linux-Interna und Zugang: cgroups, Namespaces, systemd-Härtung, nftables, WireGuard, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, Secrets pro Host",
  "Werkzeuge in Go, Python und Shell für Rollout, Auswertung, Messreihen und Berichte",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau im Labor betreut: Geräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "Messdaten nachvollziehbar abgelegt, damit Ergebnisse über die Projektlaufzeit hinaus prüfbar bleiben",
  "In einem Forschungsumfeld mit geteilten Rechnern und dokumentierten Auswertungen gearbeitet",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung und Verantwortung für Software und IT des Unternehmens",
  "Betriebsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet",
))

#section("Projekte")
#entry("Sentinel — Betriebsmessung als Schleife", "seit 2023", (
  "Ein Lauf alle fünfzehn Minuten schreibt einen Datensatz je Host; die Auswertung liest den Verlauf, nicht den Augenblick",
  "Prüfungen laufen von außen, damit ein Host sich nicht selbst bescheinigt, dass er erreichbar ist",
  "Der Alarmweg endet erst mit der Bestätigung der Zustellung; ohne Bestätigung bleibt die Störung offen und sichtbar",
))
#entry("nixconfig — ein Verbund, einmal beschrieben", "seit 2023", (
  "Ein Host registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen aus derselben Beschreibung",
  "Veröffentlichen, Ausrollen und Rückrollen sind Aufgaben, keine Eingriffe auf dem Knoten",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst messen, dann urteilen: ohne Vorher-Nachher-Wert ist eine Änderung eine Vermutung. \
  - Ein Alarm, dessen Zustellung niemand prüft, ist ein Wunsch. \
  - Aufschreiben, was war: Messreihen, Regeln und Vorfälle gehören in die Dokumentation, nicht ins Gedächtnis.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2; Ingenieurausbildung mit Mess- und Versuchstechnik",))

#section("Kenntnisse")
#text(weight: "bold")[Betrieb] — Linux-Knoten, systemd, cgroups, Namespaces, PSI, Boot und Wiederherstellung, PXE \
#text(weight: "bold")[Beobachtung] — Ledger mit Zeitstempel, journald und journalctl-Diagnose, Prüfungen von außen, Alarmbrücke mit Zustellbestätigung, Vorlaufgrößen, Auswertung in Python \
#text(weight: "bold")[Sicherheit] — eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, Secrets pro Host (sops, age), WireGuard, nftables, Härtung nach systemd-Vorgaben \
#text(weight: "bold")[Auslieferung] — Nix als reproduzierbare Beschreibung, Gates, Rückrollung über Generationen \
#text(weight: "bold")[Code] — Go, Python, Shell; Automatisierung, Auswertung, Berichte \
#text(weight: "bold")[Nicht vorhanden] — OpenTelemetry (Collector, OTLP, SDKs, Auto-Instrumentation), verteiltes Tracing mit Span-Korrelation, Context Propagation und Sampling, Jaeger, SIEM-Integration mit CEF, Prometheus, Grafana, Loki, Kubernetes  \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Karlsruhe in rund 1,5 Stunden erreichbar
