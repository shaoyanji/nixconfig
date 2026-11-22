#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.6cm, bottom: 1.6cm, left: 1.9cm, right: 1.9cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 11.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.70em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systembetrieb und Automatisierung — Server, Netze, Wartung]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Fünf Jahre lang dreizehn Linux-Server allein betreut: Installation, Netz, Dienste, Sicherheitsupdates, Überwachung, Wiederherstellung. Der Zustand jeder Maschine steht in einer Flake und nicht in der Erinnerung des Administrators; ein Rollout läuft über ein Gate, eine Rückkehr zur vorigen Generation dauert Minuten. Wartung ist bei mir automatisiert: Prüfungen, Protokolle, Alarmierung, Sicherungen mit geprüfter Wiederherstellung. In der Forschung habe ich 2012 am Fraunhofer ISE Messaufbau und Auswertung betreut. Debian im Regelbetrieb, Windows-Domänen, VMware und Ansible habe ich nicht verwaltet; das steht im Anschreiben.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(10pt)
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
  #v(7pt)
]

#section("Berufserfahrung")
#entry("Bountystash — Gründer und alleiniger Systembetreiber", "2020 – 2025", (
  "Dreizehn Linux-Server über drei Hardware-Generationen: Installation per PXE, Partitionierung, Dienste, Netz, Zugriffskontrolle",
  "Wartung automatisiert: Sicherheitsupdates über gepinnte Eingaben, Zustandsprüfung alle fünfzehn Minuten, Alarmierung mit bestätigter Zustellung",
  "Sicherungen mit restic und geprüften Wiederherstellungen, Rückrollung über die vorige Systemgeneration",
  "Netz und Fernzugriff im Code: nftables, WireGuard ohne öffentlichen Listener, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Dokumentation und Betriebshandbuch aus demselben Bestand erzeugt, damit Wissen nicht in einem Kopf bleibt",
  "Kapazität und Rollen dokumentiert: welcher Server welche Aufgabe trägt, damit ein Ausfall ohne Suche zugeordnet werden kann",
  "Werkzeuge in Python, Go und Shell für Rollout, Auswertung und Berichte",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung und Verantwortung für Software und IT des Unternehmens",
  "Betriebsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau im Labor betreut, Geräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "Arbeit in einem Forschungsumfeld mit geteilten Rechnern, Datenablage und dokumentierten Auswertungen",
))

#section("Projekte")
#entry("nixconfig — ein Bestand, einmal beschrieben", "seit 2023", (
  "Ein Server registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen daraus",
  "Gates vor jedem Rollout, Rückrollung über Generationen, keine von Hand geänderten Dateien auf den Maschinen",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst beschreiben, dann ändern: keine Datei auf einem Server von Hand, jede Änderung geht durch den Bestand und wird dort geprüft. \
  - Prüfen statt hoffen: Gates vor dem Rollout, Rückspielen von Sicherungen geübt, Alarmzustellung bestätigt. \
  - Aufschreiben, was getan wurde: ein Runbook je Verfahren, damit die Stelle nicht an einer Person hängt.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Systembetrieb] — Linux-Server, systemd, cgroups, Namespaces, Speicher- und Prozessdruck, Boot und Wiederherstellung \
#text(weight: "bold")[Netz] — nftables, WireGuard, DNS, Zertifikate, Fernzugriff ohne öffentliche Dienste \
#text(weight: "bold")[Wartung] — automatisierte Updates, Zustandsprüfung, Alarmierung mit Zustellbestätigung, restic-Sicherungen mit geprüfter Rückspielung \
#text(weight: "bold")[Nix] — Flakes, Modulaufbau, gepinnte Eingaben, reproduzierbare Systeme, Rückrollung \
#text(weight: "bold")[Skripte] — Python, Go, Shell; Auswertung, Berichte, Dokumentation \
#text(weight: "bold")[Nicht vorhanden] — Debian im Regelbetrieb, Windows-Domäne und Active Directory, VMware, Ansible, Ticketsysteme im Hochschulbetrieb \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Wohnsitz Freiburg
