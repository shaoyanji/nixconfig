#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systemadministration, Backup und Monitoring]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Sicherung und Anwenderbetreuung, wohnhaft rund 20 km von Freiburg und Absolvent der Universität Freiburg (M.Sc. 2014). Betreibt dreizehn Server über drei Hardware-Generationen, inklusive Beschaffung und Inbetriebnahme. Sichert mit restic auf ein NAS und führt Wiederherstellungen tatsächlich durch, statt nur den Job zu prüfen. Überwacht mit einem Sentinel-Ledger alle 15 Minuten, Gatus-Prüfungen und einer Go-Bridge, die eine Alarmzustellung bestätigt. Netz und Firewall als Code, DNS selbst konfiguriert, Rechte als Rollen je Host, Geheimnisse in sops und age. Windows betreue ich auf Workstation-Ebene; Windows-Server, macOS, VMware, Hyper-V, Kubernetes, Active Directory und BSI-Grundschutz sind nicht Teil dieser Erfahrung. Deutsch C1, Englisch Muttersprache.]

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
  "Sicherte Daten mit restic auf ein NAS und führte Wiederherstellungen durch, statt sich auf den Sicherungsjob zu verlassen",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Konfigurierte Netz und Firewall als Code mit nftables, dazu DNS und ein WireGuard-Tailnet zwischen den Standorten",
  "Verwaltete Zugriffsrechte deklarativ: Rollen als Feature-Liste je Host, kein Konto von Hand angelegt",
  "Verschlüsselte Geheimnisse mit sops und age und betrieb eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Hielt die Infrastruktur als Code in Git, mit Gate und Rückrollung je Generation, und dokumentierte jede Prozedur als Runbook",
  "Betreute Nutzende bei Hard- und Softwarefragen und leitete andere bei der Bedienung der Flotte an",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Dokumentierte und betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
  "Schrieb C++-Anwendungssoftware zur Anbindung der Laborgeräte und Python-Werkzeuge für Analyse und 3D-Geometrie",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig", "seit 2023", (
  "Deklarierte die Flotte in einem Flake: jeder Host eine Feature-Liste, jeder Dienst ein Modul, jede Änderung mit Gate und Rückrollung",
  "Ließ in CI dasselbe Modul-Gate je Host laufen wie auf den Maschinen, dazu ein Sentinel-Ledger aus Job-Status, Generation-Alter, Disk- und PSI-Druck",
  "Betrieb eine autarke KI-Plattform auf eigener Hardware mit Modellserver, Go-Router und Zugang nur über das Tailnet",
))

#section("Kenntnisse")
#text(weight: "bold")[Linux und Server] — NixOS und Debian-nah, systemd, Rechteverwaltung, Ressourcenlimits, Boot-Konfiguration \
#text(weight: "bold")[Sicherung] — restic, NAS, Aufbewahrung, durchgeführte Wiederherstellungstests \
#text(weight: "bold")[Überwachung] — JSONL-Ledger, Gatus, Alarmzustellung mit Bestätigung, Disk- und PSI-Druck \
#text(weight: "bold")[Netzwerk] — TCP/IP, DNS, nftables, WireGuard, Fehlersuche bis zur Unit \
#text(weight: "bold")[Sicherheit] — sops, age, eigene SSH-Zertifizierungsstelle, Rollen je Host, keine offene Schnittstelle \
#text(weight: "bold")[Nicht vorhanden] — Windows Server, macOS, VMware/Hyper-V/KVM, Docker/Kubernetes, Active Directory, BSI-Grundschutz \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache \
#text(weight: "bold")[Verfügbarkeit] — Gutach im Breisgau, rund 20 km von Freiburg, kein Umzug, Eintritt sofort
