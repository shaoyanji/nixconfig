#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.58em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Plattformbetrieb — reproduzierbare Server, Netz, Telemetrie, Auslieferung]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre Linux-Server für Dienste, die Menschen tatsächlich genutzt haben: dreizehn Hosts über drei Hardware-Generationen, begrenzte Ressourcen, kein Managed Cloud. Server entstehen beschrieben statt von Hand — Installation über das Netz, gepinnte Eingaben, Prüfung vor dem Rollout, Rückkehr zur vorigen Generation in Minuten. Netz und Zugriff sind Teil derselben Beschreibung: Adressierung, WireGuard ohne öffentlich erreichbaren Verwaltungszugang, nftables, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten. Telemetrie mit Zustellbestätigung statt Vermutung, Sicherungen mit geprüften Rückspielungen. Was nicht vorhanden ist, steht im Anschreiben.]

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
  "Dreizehn Linux-Hosts über drei Hardware-Generationen betrieben, inklusive Installation über das Netz, Datenträger, Dienste und Wiederherstellung",
  "Server als Beschreibung: gepinnte Eingaben, gleiche Beschreibung ergibt gleiches System, keine von Hand geänderten Dateien",
  "Auslieferung mit Prüfung vor dem Rollout und Rückkehr zur vorigen Generation in Minuten statt in einer Nacht",
  "Netz und Zugriff im Code: Adressierung, DNS, WireGuard zwischen Standorten, nftables, keine öffentlich erreichbare Verwaltung",
  "Telemetrie als Schleife: Ledger alle fünfzehn Minuten, Prüfungen von außen auf Erreichbarkeit und Antwortzeit, Go-Brücke mit Zustellbestätigung",
  "Sicherungen mit restic und tatsächlich durchgeführten Rückspielungen; Wiederherstellung geübt, nicht angenommen",
  "Sicherheit im Betrieb: eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, sops und age je Host, minimale Rechte",
  "Werkzeuge in Python, Go und Shell für Rollout, Auswertung und Berichte; Dokumentation aus dem Bestand erzeugt",
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
#entry("nixconfig — eine Plattform, einmal beschrieben", "seit 2023", (
  "Ein Host registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen aus derselben Beschreibung",
  "Dienste für Nutzende hinter offenen Schnittstellen betrieben, inklusive selbst betriebener Modelldienste mit Bedarfsladung",
  "Veröffentlichen, Ausrollen und Rückrollen sind Aufgaben, keine Eingriffe auf dem Host",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst beschreiben, dann ändern: ein Server, der nur in Handarbeit existiert, lässt sich nicht wiederherstellen. \
  - Erst messen, dann urteilen: ohne Vorher-Nachher-Wert ist eine Änderung eine Vermutung. \
  - Aufschreiben, was war: Adressierung, Regeln und Vorfälle gehören in die Dokumentation, nicht ins Gedächtnis.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Plattform] — Linux-Server, reproduzierbare Installation, Gates, Rückrollung über Generationen, PXE, systemd \
#text(weight: "bold")[Netz] — Adressierung, DNS, WireGuard, nftables, TLS mit eigener Zertifizierungsstelle, Fernzugriff ohne öffentliche Dienste \
#text(weight: "bold")[Betrieb] — Telemetrie mit Zustellbestätigung, Störungsbearbeitung, restic mit geprüften Rückspielungen \
#text(weight: "bold")[Code] — Python, Go, Shell, Nix; Automatisierung, Berichte, erzeugte Dokumentation \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes, Docker, Terraform, Ansible, Cloud-Plattformen, Plesk, großer MySQL- oder PostgreSQL-Betrieb, regulierter KRITIS-Betrieb \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Umzug nach Espelkamp oder Münster möglich
