#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.58em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Serverbetrieb — Härtung, Netz, Auslieferung, Überwachung]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre Linux-Serverlandschaft, allein verantwortet: dreizehn Hosts über drei Hardware-Generationen, ohne von Hand geänderten Zustand, mit Härtung als Vorgabe statt als Nacharbeit. Netze und Fernzugriff sind beschrieben, nicht gewachsen: nftables, WireGuard zwischen den Standorten, keine öffentlich erreichbaren Verwaltungsdienste, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten. Auslieferung läuft über gepinnte Eingaben und eine Prüfung vor dem Rollout; Überwachung über ein Ledger mit Zeitstempel, Prüfungen von außen und eine Alarmbrücke, die erst nach bestätigter Zustellung als gemeldet gilt. Ein verteiltes Team ist für mich normal: der Betrieb war fern vom Aufstellungsort.]

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
  "Dreizehn Linux-Hosts über drei Hardware-Generationen administriert, gewartet und gehärtet, ohne Reserve und ohne Managed Cloud",
  "Netzwerk-Infrastruktur aufgebaut und erweitert: WireGuard zwischen Standorten, DNS, nftables-Regeln, keine öffentlichen Verwaltungsdienste",
  "Auslieferung automatisiert: gepinnte Eingaben, Prüfung des ausgewerteten Systems vor dem Rollout, Rückrollung über die vorige Generation in Minuten",
  "Überwachung und Alarmierung als geschlossene Schleife: Ledger alle fünfzehn Minuten, Prüfungen von außen, Go-Brücke mit Zustellbestätigung",
  "Incident Response ohne Eskalationsstufe dahinter: Schweregrad bestimmen, Ursache eingrenzen, Dienst wiederherstellen, Ursache dokumentieren",
  "Sicherheit im Betrieb statt auf dem Papier: eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, sops und age je Host, getrennte Schlüssel, minimale Rechte",
  "Sicherungen mit restic und tatsächlich durchgeführten Rückspielungen; Wiederherstellung als geübter Vorgang",
  "Installation über das Netz, inklusive Aufbau neuer Hardware und Übergabe in den Betrieb",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung und Verantwortung für Software und IT des Unternehmens",
  "Betriebsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau im Labor betreut, Geräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "In einem Forschungsumfeld mit geteilten Rechnern und dokumentierten Auswertungen gearbeitet",
))

#section("Projekte")
#entry("nixconfig — ein Bestand, einmal beschrieben", "seit 2023", (
  "Ein Host registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen daraus",
  "Änderungen laufen durch Gates, nicht durch Zuruf; jede Prozedur hat ein Runbook",
  "Dokumentation wird aus dem Bestand erzeugt, damit sie nicht von der Wirklichkeit abweicht",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst beschreiben, dann ändern: keine Datei auf einem Server von Hand. \
  - Erst messen, dann urteilen: ohne Vorher-Nachher-Wert ist eine Änderung eine Vermutung. \
  - Aufschreiben, was war: ein Vorfall ohne Notiz wird beim nächsten Mal wieder ein Vorfall.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Linux] — Debian-nah über NixOS, systemd, cgroups, Namespaces, PSI, Boot und Wiederherstellung, PXE-Installation \
#text(weight: "bold")[Netz] — nftables, WireGuard, DNS, TLS mit eigener Zertifizierungsstelle, Fernzugriff ohne öffentliche Dienste \
#text(weight: "bold")[Betrieb] — Monitoring mit Zustellbestätigung, Incident Response, restic mit geprüften Rückspielungen, Rückrollung über Generationen \
#text(weight: "bold")[Automatisierung] — Nix-Flakes, CI/CD über Gates, Python, Go, Shell \
#text(weight: "bold")[Sicherheit] — Härtung, kurzlebige Zertifikate, sops und age, minimale Rechte; kein ISO-27001-Audit begleitet \
#text(weight: "bold")[Nicht vorhanden] — ISO-27001-Zertifizierung, Cloud-Plattformen, Kubernetes und Container-Orchestrierung im Betrieb, Java-Anwendungsbetrieb \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Fernarbeit aus Deutschland, Präsenz in Hamburg möglich
