#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Systembetrieb und Beobachtung — Linux, NixOS, Automatisierung]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Fünf Jahre Betrieb von dreizehn Linux-Hosts aus einer Flake: ein Modul je Dienst, eine Feature-Liste je Host, gepinnte Eingaben, ein Gate vor jedem Rollout. Die Beobachtung dieses Bestands ist selbst gebaut: ein Ledger, das alle fünfzehn Minuten schreibt, Prüfungen von außen, ein Alarmkanal, der erst Erfolg meldet, wenn die Zustellung bestätigt ist, dazu Druck- und Speicherwerte, die vor dem Ausfall auffallen. Rückrollung ist eine Generation, kein Neuaufbau. Regulierte KRITIS-Umgebungen, Prometheus oder Loki im Telekom-Maßstab und OpenTelemetry habe ich nicht betrieben; das steht im Anschreiben.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(5pt)
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
  #v(3pt)
]

#section("Berufserfahrung")
#entry("Bountystash — Gründer und alleiniger Betreiber", "2020 – 2025", (
  "Dreizehn Linux-Hosts über drei Hardware-Generationen aus einer Flake, ohne von Hand geänderten Zustand auf einer Maschine",
  "Beobachtung als geschlossene Schleife: Ledger mit Zeitstempel alle fünfzehn Minuten, Prüfungen von außen, Auswertung von Speicher- und Prozessdruck",
  "Alarmkanal in Go, der eine Störung erst als gemeldet führt, wenn die Zustellung bestätigt ist — ein Alarm ohne Ankunft ist ein falscher Glaube",
  "Rollout nur über das ausgewertete System, Rückrollung über die vorige Generation",
  "Netz und Zugang im Code: nftables, WireGuard ohne öffentlichen Listener, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Werkzeuge in Python und Go für Rollout, Ledger, Auswertung und Dokumentation",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung und Verantwortung für Software und IT des Unternehmens",
  "Finanzmodelle und Betriebsdaten als Entscheidungsgrundlage für die Geschäftsführung",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau über C++-Anwendungen angesteuert und Messreihen in Python ausgewertet",
  "Untersuchung von Heliostaten-Ungenauigkeiten mit Interferometrie",
))

#section("Projekte")
#entry("nixconfig — ein Bestand, einmal beschrieben", "seit 2023", (
  "Ein Host registriert sich einmal als Feature-Liste; Aufgabenmenü und Dokumentation entstehen aus demselben Graphen",
  "Zustandsprüfung, Auftragsprotokoll und Agenten-Protokoll laufen auf der Plattform, die sie beobachten",
  "Veröffentlichen, Ausrollen und Rückrollen sind Aufgaben, keine Eingriffe auf dem Host",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Betrieb] — Linux-Hosts, systemd, cgroups, Namespaces, PSI und Speicherdruck, Boot und Wiederherstellung \
#text(weight: "bold")[Beobachtung] — Ledger mit Zeitstempel, Gatus-Prüfungen, node_exporter auf einzelnen Hosts, Alarmkanal mit Zustellbestätigung \
#text(weight: "bold")[Nix] — Flakes, Modulaufbau, gepinnte Eingaben, reproduzierbare Builds, Rückrollung über Generationen \
#text(weight: "bold")[Automatisierung] — Python, Go, Shell; Gates, Aufgaben, erzeugte Dokumentation \
#text(weight: "bold")[Sicherheit] — eigene Zertifizierungsstelle, kurzlebige Zertifikate, sops und age je Host \
#text(weight: "bold")[Nicht vorhanden] — Prometheus, Thanos oder Loki im Maßstab, OpenTelemetry, Kubernetes, KRITIS-Auditierung nach BSIG und IT-Grundschutz \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Fernarbeit aus Deutschland
