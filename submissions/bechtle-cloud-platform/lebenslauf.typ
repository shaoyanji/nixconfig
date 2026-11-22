#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Plattformen, Automatisierung und souveräner Betrieb]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb und Automatisierung, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen auf eigener Hardware, ohne Managed Cloud: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung. Automatisiert Bereitstellung und Betrieb mit Shell, Python und Go; dasselbe Gate läuft in CI und vor dem Ausrollen. Überwacht mit einem Sentinel-Ledger alle 15 Minuten, prüft Endpunkte mit Gatus und bestätigt eine Alarmzustellung erst, wenn die Nachricht ankommt. Sichert mit restic und führt Wiederherstellungen durch. Hält Dienste über systemd-Limits klein und behandelt Speicherdruck als Messgröße. Betrieb eine KI-Plattform auf eigener Hardware, erreichbar nur über ein WireGuard-Tailnet. Kubernetes, Docker, Terraform und GitLab- oder GitHub-Pipelines sind nicht Teil dieser Erfahrung. Bereit zur Sicherheitsüberprüfung SÜ2. Deutsch C1, Englisch Muttersprache.]

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
  "Deklarierte Plattform und Dienste in einem Flake: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit",
  "Automatisierte Bereitstellung und Betrieb mit Shell, Python und Go; das Gate in CI ist dasselbe, das den Ausrollvorgang schützt",
  "Hielt jeden Stand als Generation und rollte bei Bedarf zurück, statt einen Fehler vorwärts zu reparieren",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Sicherte mit restic auf ein NAS, führte Wiederherstellungen durch und begrenzte jeden Dienst über systemd-Limits",
  "Betrieb ohne öffentliche Schnittstelle: alles im WireGuard-Tailnet, Firewall als Code mit nftables, Geheimnisse in sops und age",
  "Betrieb eine KI-Plattform auf eigener Hardware mit Modellserver und Go-Router, Zugang nur über das Tailnet",
  "Beriet Nutzende bei der Verwendung der Dienste und dokumentierte jede Prozedur als Runbook",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Schrieb C++-Anwendungssoftware zur Anbindung von Laborgeräten und Python-Werkzeuge für Analyse und 3D-Geometrie",
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig", "seit 2023", (
  "Deklarierte die Flotte in einem Flake mit Modulen je Dienst und Gates je Host; CI prüft denselben Zustand, der ausgerollt wird",
  "Ergänzte ein Sentinel-Ledger aus Job-Status, Generation-Alter, Disk- und PSI-Druck sowie eine Go-Bridge mit Zustellbestätigung",
  "Betrieb eine autarke KI-Plattform auf eigener Hardware mit Modellserver, Go-Router und Zugang nur über das Tailnet",
))

#section("Kenntnisse")
#text(weight: "bold")[Linux-Plattform] — NixOS und Debian-nah, systemd, Ressourcenlimits, reproduzierbare Installation, Container-Grundlagen \
#text(weight: "bold")[Infrastructure as Code] — deklarative Konfiguration, Git als einzige Quelle, CI-Gates, Rückrollung je Generation \
#text(weight: "bold")[Betrieb] — Monitoring-Ledger, Gatus, Zustellbestätigung, restic mit geprüften Wiederherstellungen, Störungsdiagnose \
#text(weight: "bold")[Sicherheit] — sops, age, eigene SSH-Zertifizierungsstelle, kurzlebige Zertifikate, nftables, keine offene Schnittstelle \
#text(weight: "bold")[Automatisierung] — Shell, Python, Go, Module je Dienst, Gates je Host \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes im Produktivbetrieb, Docker, Terraform, GitLab/GitHub CI, DevSecOps-Pipelines \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache
