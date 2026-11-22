#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systemadministration, PKI und Infrastruktur als Code]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Absicherung, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen vollständig als Code in Git: jeder Host eine Feature-Liste, jeder Dienst ein Modul, jede Änderung mit Gate und Rückrollung. Schlüssel und Vertrauen sind eigene Arbeit: eine SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, Geheimnisse in sops und age, kein Dienst mit öffentlicher Schnittstelle. Überwachung auf Open-Source-Basis mit Sentinel-Ledger alle 15 Minuten, Gatus-Prüfungen und einer Go-Bridge, die eine Alarmzustellung bestätigt. Gesichert wird mit restic, Wiederherstellungen werden geprüft. IDS/IPS, SIEM, SELinux- und AppArmor-Profile, Schwachstellenmanagement und Incident Response sind nicht Teil dieser Erfahrung. Deutsch C1, Englisch Muttersprache.]

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
  "Hielt die gesamte Infrastruktur als Code in Git: jeder Host eine Feature-Liste, jeder Dienst ein Modul, jede Änderung mit Gate und Rückrollung",
  "Betrieb eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten und verschlüsselte Geheimnisse mit sops und age",
  "Härtete Dienste über systemd-Unit-Optionen und Ressourcenlimits; kein Dienst hing mit öffentlicher Schnittstelle im Netz",
  "Konfigurierte Netz und Firewall als Code mit nftables, dazu DNS und ein WireGuard-Tailnet zwischen den Standorten",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Sicherte Daten mit restic auf ein NAS und prüfte Wiederherstellungen statt sie anzunehmen",
  "Automatisierte Betriebsprozesse und Auswertungen in Bash, Python und Go und dokumentierte jede Prozedur als Runbook",
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
  "Deklarierte die Flotte in einem Flake, sodass die Optionsfläche ein Gate bleibt statt Copy-and-paste zwischen Hosts",
  "Ließ in CI dasselbe Modul-Gate je Host laufen wie auf den Maschinen, dazu ein Sentinel-Ledger aus Job-Status, Generation-Alter, Disk- und PSI-Druck",
  "Betrieb eine autarke KI-Plattform auf eigener Hardware mit Go-Router, Modellwechsel auf Abruf und Zugang nur über das Tailnet",
))

#section("Kenntnisse")
#text(weight: "bold")[Linux und Server] — NixOS und Debian-nah, systemd-Härtung, Rechteverwaltung, Ressourcenlimits, Boot-Konfiguration \
#text(weight: "bold")[Kryptographie und PKI] — eigene SSH-Zertifizierungsstelle, kurzlebige Zertifikate, sops, age, WireGuard \
#text(weight: "bold")[Infrastruktur als Code] — Git als einzige Quelle, Gates je Host, Rückrollung je Generation, CI \
#text(weight: "bold")[Überwachung] — Gatus, JSONL-Ledger, Alarmzustellung mit Bestätigung, Disk- und PSI-Druck \
#text(weight: "bold")[Automatisierung] — Bash, Python, Go, Task-Runner \
#text(weight: "bold")[Nicht vorhanden] — IDS/IPS, SIEM, SELinux/AppArmor, Ansible/Puppet, FreeIPA/Keycloak, OpenStack, Kubernetes \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache \
#text(weight: "bold")[Verfügbarkeit] — Wechsel nach Hamburg machbar, hybrid passt, Eintritt nach Vereinbarung
