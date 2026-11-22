#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systeme, Netze und Betrieb in Forschungsumgebungen]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Anwenderbetreuung, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen deklarativ auf NixOS, inklusive Beschaffung, Installation und Inbetriebnahme. Konfiguriert Netze und Firewall als Code mit nftables, dazu DNS, ein WireGuard-Tailnet und PXE-Installationen aus eigenem ISO-Archiv. Sichert auf NAS-Ziele mit restic und prüft Wiederherstellungen; jede Änderung ist auf die vorherige Generation rückrollbar. Überwacht mit einem Sentinel-Ledger alle 15 Minuten, prüft Endpunkte mit Gatus und bestätigt Alarmzustellungen erst bei Ankunft. In der Forschung band er Laborgeräte über C++-Anwendungen an und wertete Messreihen in Python aus. Windows: Anwenderbetreuung und Client-Support, keine Serveradministration, kein Active Directory, kein Hyper-V. Deutsch C1, Englisch Muttersprache.]

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
  "Betrieb dreizehn Hosts über drei Hardware-Generationen und mehrere Standorte, von der Beschaffung über Transport und Installation bis zur Inbetriebnahme",
  "Beschrieb Systeme und Dienste deklarativ in einem Flake: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit",
  "Verwaltete Benutzerkonten, Rechte und Zugänge über zentrale Konfiguration statt über lokale Handarbeit auf den einzelnen Maschinen",
  "Konfigurierte Netze und Firewall als Code mit nftables, dazu DNS und ein WireGuard-Tailnet ohne öffentliche Schnittstelle",
  "Lieferte Bare-Metal-Installationen über PXE und ein eigenes ISO-Archiv, damit Neuaufbauten reproduzierbar bleiben",
  "Sicherte auf NAS-Ziele mit restic und führte Wiederherstellungen durch statt nur Sicherungsläufe zu zählen",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt, dazu Gatus-Prüfungen und eine Go-Bridge mit Zustellbestätigung",
  "Hielt Dienste über systemd-Optionen und Ressourcenlimits klein und behandelte Speicherdruck als Messgröße",
  "Betreute Anwender bei Hard- und Softwarefragen, auch über Standorte hinweg, und dokumentierte jede Prozedur als Runbook",
  "Schrieb Werkzeuge in Shell, Python und Go, darunter die Alarm-Bridge und Auswertungen über das Ledger",
  "Verwaltete Geheimnisse mit sops und age und betrieb eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften, einschließlich Anwenderbetreuung",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Band Laborgeräte über selbst geschriebene C++-Anwendungen an und hielt Messplätze betriebsbereit",
  "Wertete Messreihen mit Python aus und arbeitete an 3D-Geometrie und Interferometrie zu Heliostat-Ungenauigkeiten",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig — deklarierte Flotte mit Gates", "seit 2023", (
  "Ein Modul je Dienst, eine Feature-Liste je Host; ein Gate prüft Module und Assertions, bevor etwas ausgerollt wird",
  "Sentinel-Ledger über Jobstatus, Generation-Alter, Disk- und PSI-Druck, dazu eine Go-Bridge mit Zustellbestätigung",
  "Dienste hinter einem Tailnet ohne öffentliche Schnittstelle, Zertifikate über die eigene CA",
))
#entry("Autarke KI-Plattform auf eigener Hardware", "2024 – 2025", (
  "Betrieb Modellserver, Router und Weboberfläche auf eigenen Maschinen, ohne Cloud-Abhängigkeit",
  "Schrieb den Router in Go und isolierte jede Modell-Lane mit eigenen Limits",
))

#section("Kenntnisse")
#text(weight: "bold")[Linux] — NixOS und Ubuntu-nah, systemd, Ressourcenlimits, Benutzer- und Rechteverwaltung, PXE-Installation \
#text(weight: "bold")[Netze] — nftables, DNS, Segmentierung, WireGuard-Tailnet, kein Dienst mit öffentlicher Schnittstelle \
#text(weight: "bold")[Speicher und Sicherung] — NAS-Ziele, restic, geprüfte Wiederherstellungen, ISO- und Image-Archiv \
#text(weight: "bold")[Zuverlässigkeit] — Monitoring-Ledger, Gatus, Zustellbestätigung, Rückrollung je Generation, Runbooks \
#text(weight: "bold")[Automatisierung] — Shell, Python, Go, deklarative Konfiguration, Git als einzige Quelle \
#text(weight: "bold")[Windows] — Anwenderbetreuung und Client-Support; keine Serveradministration, kein Active Directory, kein Hyper-V, kein PowerShell \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache
