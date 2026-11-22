#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Plattformbetrieb, Automatisierung und Energiedaten]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb und Automatisierung, davon eine Forschungsstation am Fraunhofer ISE und vier Jahre in der Steuerung von Solar-Assets. Betreibt dreizehn Server über drei Hardware-Generationen als deklarierte Infrastruktur: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung. Entwickelt Automatisierungen und Schnittstellen in Go und Python, darunter eine Alarm-Bridge mit Zustellbestätigung und einen Router für Modellanfragen. Überwacht mit einem Sentinel-Ledger alle 15 Minuten, prüft Endpunkte mit Gatus und optimiert Monitoring auf Signale, die Ausfälle erklären statt sie zu wiederholen. Verantwortet Netze und Firewall als Code mit nftables, DNS und WireGuard. Kennt die Energieseite aus Ertragsdaten, Abweichungsanalysen und Anlagensteuerung. Kubernetes, Helm und GitOps sind nicht Teil dieser Erfahrung. Deutsch C1, Englisch Muttersprache.]

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
  "Entwickelte Automatisierungen und Schnittstellen in Go und Python, darunter die Alarm-Bridge und ein Router für Modellanfragen",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Optimierte Monitoring auf Signale, die Ausfälle erklären: Speicherdruck, Generation-Alter, Zustellbestätigung statt nur Statuscodes",
  "Konfigurierte Netz und Firewall als Code mit nftables, dazu DNS und ein WireGuard-Tailnet ohne öffentliche Schnittstelle",
  "Hielt jeden Stand als Generation und rollte bei Bedarf zurück; sicherte mit restic und prüfte Wiederherstellungen",
  "Verwaltete Geheimnisse mit sops und age und Host-Schlüssel über eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Dokumentierte jede Prozedur als Runbook, damit Betrieb nicht an einer Person hängt",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Steuerte 10 MW Solar-PV-Anlagen und erstellte die Finanzmodelle dahinter",
  "Wertete Ertragsdaten aus und analysierte Abweichungen gegenüber Planwerten",
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
  "Band Laborgeräte über C++-Anwendungssoftware an und wertete Messdaten mit Python aus",
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
#text(weight: "bold")[Plattform] — NixOS und Debian-nah, systemd, Ressourcenlimits, reproduzierbare Installation, deklarative Konfiguration \
#text(weight: "bold")[Automatisierung] — Go, Python, Shell, APIs, Git als einzige Quelle, CI-Gates, Rückrollung je Generation \
#text(weight: "bold")[Telemetrie] — JSONL-Ledger, Gatus, Zustellbestätigung, Kennzahlen zu Speicherdruck und Generation-Alter \
#text(weight: "bold")[Netzwerk] — nftables, DNS, WireGuard, Segmentierung, Fehlersuche mit tcpdump und ss \
#text(weight: "bold")[Energie] — Ertragsdaten, Abweichungsanalysen, Asset-Steuerung, Marktkontext \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes, Helm, GitOps, Container-Orchestrierung im Produktivbetrieb \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache
