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
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Anwenderbetreuung, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen als deklarierte Infrastruktur: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung. Verantwortet eine Plattform, auf die andere sich verlassen: Entwicklungs- und Testumgebungen, CI-Gates, Telemetrie und Sicherungen. Überwacht mit einem Sentinel-Ledger alle 15 Minuten, prüft Endpunkte mit Gatus und bestätigt eine Alarmzustellung erst, wenn die Nachricht ankommt. Sichert mit restic und führt Wiederherstellungen durch. Automatisiert in Bash, Python und Go; Geheimnisse liegen in sops und age, kein Dienst hängt offen im Netz. Windows Server, Hyper-V, OpenStack, Oracle, PowerShell, C\#, Azure DevOps, Docker, Kubernetes und Helm sind nicht Teil dieser Erfahrung. Deutsch C1, Englisch Muttersprache.]

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
  "Hielt das Gate in CI und das Gate vor dem Ausrollen identisch, sodass keine ungeprüfte Änderung auf eine Maschine kam",
  "Hielt jeden Stand als Generation und rollte bei Bedarf zurück, statt einen Fehler vorwärts zu reparieren",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Sicherte mit restic auf ein NAS, führte Wiederherstellungen durch und begrenzte jeden Dienst über systemd-Limits",
  "Automatisierte Betrieb, Auswertung und Werkzeuge in Bash, Python und Go",
  "Verwaltete Geheimnisse mit sops und age und Host-Schlüssel über eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Beriet Nutzende, beantwortete Support-Anfragen und dokumentierte jede Prozedur als Runbook",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Band Laborgeräte über C++-Anwendungssoftware an und wertete Messdaten mit Python aus",
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
#text(weight: "bold")[Linux] — NixOS und Debian-nah, systemd, Rechteverwaltung, Ressourcenlimits, reproduzierbare Installation \
#text(weight: "bold")[Automatisierung] — Bash, Python, Go, deklarative Konfiguration, Git als einzige Quelle, CI-Gates \
#text(weight: "bold")[Plattformbetrieb] — Entwicklungs- und Testumgebungen, Rückrollung je Generation, Runbooks, Support \
#text(weight: "bold")[Betrieb] — Monitoring-Ledger, Gatus, Zustellbestätigung, restic mit geprüften Wiederherstellungen \
#text(weight: "bold")[Sicherheit] — sops, age, eigene SSH-Zertifizierungsstelle, kurzlebige Zertifikate, nftables, keine offene Schnittstelle \
#text(weight: "bold")[Nicht vorhanden] — Windows Server, Hyper-V, OpenStack, Oracle/MSSQL, PowerShell, C\#, Azure DevOps, Docker, Kubernetes, Helm \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache
