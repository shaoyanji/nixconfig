#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Plattformen, Automatisierung und Betriebssicherheit]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Anwenderbetreuung, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen als deklarierte Infrastruktur: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung. Verantwortet Verfügbarkeit als Messgröße: Sentinel-Ledger alle 15 Minuten mit Jobstatus, Generation-Alter, Disk- und PSI-Druck, Endpunktprüfungen mit Gatus, Alarmzustellung erst nach Bestätigung. Diagnostiziert Störungen in verteilten Diensten aus Ledger und Systemlogs, bevor Nutzende sie melden. Betrieb eine KI-Plattform auf eigener Hardware mit Modellserver und Go-Router, erreichbar nur über ein WireGuard-Tailnet. Sichert mit restic und führt Wiederherstellungen durch. Kubernetes, Terraform, ArgoCD, GitLab CI, Prometheus, Grafana und ELK sind nicht Teil dieser Erfahrung. Deutsch C1, Englisch Muttersprache.]

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
  "Diagnostizierte Störungen in verteilten Diensten aus Ledger und Systemlogs, bevor Nutzende sie meldeten",
  "Betrieb eine KI-Plattform auf eigener Hardware: Modellserver, Go-Router, Zugang ausschließlich über das Tailnet",
  "Sicherte mit restic auf ein NAS, führte Wiederherstellungen durch und begrenzte jeden Dienst über systemd-Limits",
  "Dokumentierte jede Prozedur als Runbook, damit Betriebswissen nicht an eine Person gebunden ist",
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
#text(weight: "bold")[Linux-Plattform] — NixOS und Debian-nah, systemd, Container-Grundlagen, Ressourcenlimits, reproduzierbare Installation \
#text(weight: "bold")[Automatisierung] — deklarative Konfiguration, Git als einzige Quelle, CI-Gates, Shell, Python, Go \
#text(weight: "bold")[Betrieb] — Monitoring-Ledger, Gatus, Zustellbestätigung, Störungsdiagnose, restic mit geprüften Wiederherstellungen \
#text(weight: "bold")[Verfügbarkeit] — Rückrollung je Generation, Limits je Dienst, Speicherdruck als Messgröße, Runbooks \
#text(weight: "bold")[Sicherheit] — sops, age, eigene SSH-Zertifizierungsstelle, kurzlebige Zertifikate, nftables, keine offene Schnittstelle \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes, Terraform, ArgoCD, GitLab CI, Prometheus, Grafana, ELK \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · US-Staatsangehörigkeit mit Niederlassungserlaubnis, kein Visum nötig · Karlsruhe rund 1,5 h entfernt
