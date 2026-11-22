#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.58em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systembetrieb und Automatisierung — Server, Netze, Support im Forschungsumfeld]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre IT-Betrieb, allein verantwortet: dreizehn Linux-Server, Netz, Dienste, Sicherheitsupdates, Überwachung, Sicherungen. Der Zustand jeder Maschine steht in einer Flake und nicht in der Erinnerung des Administrators; Änderungen laufen über eine Prüfung, eine Rückkehr zur vorigen Generation dauert Minuten. Wartung ist automatisiert, Dokumentation entsteht aus dem Bestand, damit Wissen nicht an einer Person hängt. Dazu ein Forschungsumfeld aus eigener Erfahrung: 2012 am Fraunhofer ISE Messaufbau, Geräteanbindung und Auswertung. Windows-Server, Active Directory, Hyper-V, PowerShell und Lizenzserver habe ich nicht betreut; das steht im Anschreiben.]

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
  "Dreizehn Linux-Server über drei Hardware-Generationen: Installation über das Netz, Datenträger, Dienste, Netz, Zugriffsrechte",
  "Mehrere Standorte und Netze in einem Bestand zusammengehalten, mit WireGuard zwischen den Standorten und ohne öffentlich erreichbare Verwaltungsdienste",
  "Wartung automatisiert: gepinnte Updates, Zustandsprüfung alle fünfzehn Minuten, Alarmierung, die erst nach bestätigter Zustellung als gemeldet gilt",
  "Sicherungen mit restic und geprüften Rückspielungen; Rückkehr zur vorigen Systemgeneration als Routine, nicht als Ausnahme",
  "Beschaffung und Inbetriebnahme von Hardware selbst gemacht: Auswahl, Aufbau, Installation, Übergabe an den Betrieb",
  "Nutzende betreut, ohne Administrator zu sein: Rechte, Zugänge, Anleitungen, kurze Wege statt Ticketschlangen",
  "Dokumentation und Betriebshandbuch aus demselben Bestand erzeugt, damit die Stelle nicht an einer Person hängt",
  "Werkzeuge in Python, Go und Shell für Rollout, Auswertung und Berichte",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung und Verantwortung für Software und IT des Unternehmens",
  "Betriebsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau im Labor betreut: Geräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "In einem Forschungsumfeld mit geteilten Rechnern, Datenablage und dokumentierten Auswertungen gearbeitet",
))

#section("Projekte")
#entry("nixconfig — ein Bestand, einmal beschrieben", "seit 2023", (
  "Ein Server registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen daraus",
  "Gates vor jedem Rollout, Rückrollung über Generationen, keine von Hand geänderten Dateien auf den Maschinen",
  "Dienste für Forschende und Werkzeuge: Ablage, Auswertung, selbst betriebene Modelle hinter offenen Schnittstellen",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst beschreiben, dann ändern: keine Datei auf einem Server von Hand, jede Änderung geht durch den Bestand und wird dort geprüft. \
  - Prüfen statt hoffen: Gates vor dem Rollout, Rückspielen von Sicherungen geübt, Alarmzustellung bestätigt. \
  - Aufschreiben, was getan wurde: ein Runbook je Verfahren, damit ein Lehrstuhl nicht an einem Kopf hängt.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Systembetrieb] — Linux-Server, systemd, cgroups, Namespaces, Speicher- und Prozessdruck, Boot und Wiederherstellung \
#text(weight: "bold")[Netz] — nftables, WireGuard zwischen Standorten, DNS, Zertifikate, Fernzugriff ohne öffentliche Dienste \
#text(weight: "bold")[Wartung] — automatisierte Updates, Zustandsprüfung, Alarmierung mit Zustellbestätigung, restic mit geprüfter Rückspielung \
#text(weight: "bold")[Nix] — Flakes, Modulaufbau, gepinnte Eingaben, reproduzierbare Systeme, Rückrollung \
#text(weight: "bold")[Skripte] — Python, Go, Shell; Auswertung, Berichte, Dokumentation \
#text(weight: "bold")[Nicht vorhanden] — Windows-Server, Active Directory, Hyper-V, PowerShell, Lizenzserver, Debian im Regelbetrieb, Ansible, Ticketsysteme im Hochschulbetrieb \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Umzug nach Erlangen möglich
