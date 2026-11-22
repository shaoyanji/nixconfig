#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systemadministration, Speicherung und Betrieb]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung, Speicherung und Anwenderbetreuung, wohnhaft rund 30 km von Freiburg und sofort verfügbar. Betreibt dreizehn Server über drei Hardware-Generationen und mehrere Standorte: Rechte als Rollen je Host, Netz und Firewall als Code, jede Änderung mit Gate und Rückrollung. Gesichert wird mit restic auf ein NAS, Wiederherstellungen werden geprüft statt angenommen. Überwacht wird über ein Sentinel-Ledger alle 15 Minuten mit bestätigter Alarmzustellung. Sicherheitshygiene heißt hier: keine öffentliche Schnittstelle, sops und age für Geheimnisse, eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten. Proxmox, Kubernetes, Ceph, Microsoft 365 und Azure sind nicht Teil dieser Erfahrung; Windows betreue ich auf Workstation-Ebene. Deutsch C1, Englisch Muttersprache.]

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
#entry("Bountystash — Gründer", "2020 – 2025", (
  "Betrieb dreizehn NixOS-Hosts über drei Hardware-Generationen und mehrere Standorte, inklusive Beschaffung, Installation und Inbetriebnahme",
  "Sicherte Daten mit restic auf ein NAS und prüfte Wiederherstellungen statt sie anzunehmen",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Verwaltete Zugriffsrechte deklarativ: Rollen als Feature-Liste je Host, kein Konto von Hand angelegt",
  "Konfigurierte Netz und Firewall als Code mit nftables, dazu DNS und ein WireGuard-Tailnet zwischen den Standorten",
  "Verschlüsselte Geheimnisse mit sops und age und betrieb eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Automatisierte Betriebsprozesse, Auswertungen und Deploy-Ketten in Shell, Python und Go",
  "Betreute Nutzende bei Hard- und Softwarefragen und dokumentierte jede Prozedur als Runbook",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Dokumentierte und betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
  "Schrieb C++-Anwendungssoftware zur Anbindung der Laborgeräte sowie Python-Werkzeuge für Analyse und 3D-Geometrie",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig", "seit 2023", (
  "Deklarierte die gesamte Flotte in einem Flake: jeder Host eine Feature-Liste, jeder Dienst ein Modul, sodass die Optionsfläche ein Gate bleibt",
  "Ließ in CI dasselbe Modul-Gate je Host laufen wie auf den Maschinen, dazu ein Sentinel-Ledger aus Job-Status, Generation-Alter, Disk- und PSI-Druck",
  "Betrieb eine autarke KI-Plattform auf eigener Hardware mit Go-Router, Modellwechsel auf Abruf und Zugang nur über das Tailnet",
))

#section("Kenntnisse")
#text(weight: "bold")[Linux und Server] — NixOS und Debian-nah, systemd, Rechteverwaltung, Ressourcenlimits, Boot-Konfiguration, reproduzierbare Installation \
#text(weight: "bold")[Speicherung und Sicherung] — restic, NAS, Aufbewahrung, geprüfte Wiederherstellungen \
#text(weight: "bold")[Netzwerk] — nftables, WireGuard, DNS, TCP/IP, IPv6-Grundlagen \
#text(weight: "bold")[Überwachung] — Gatus, JSONL-Ledger, Alarmzustellung, Disk- und PSI-Druck \
#text(weight: "bold")[Automatisierung] — Shell, Python, Go, Git, CI-Gates, Task-Runner \
#text(weight: "bold")[Nicht vorhanden] — Proxmox VE, Kubernetes, Ceph, Microsoft 365, Azure, Windows Server \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache \
#text(weight: "bold")[Verfügbarkeit] — Gutach im Breisgau, rund 30 km von Freiburg, kein Umzug nötig, Eintritt sofort
