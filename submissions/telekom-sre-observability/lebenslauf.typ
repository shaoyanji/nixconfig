#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Betriebstelemetrie, Linux-Plattformen und Zuverlässigkeit]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Telemetrie. Betreibt dreizehn Server über drei Hardware-Generationen als einen deklarativen Zustand: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate, jeder Stand als Generation rückrollbar. Baute die Betriebstelemetrie selbst, weil es keinen Monitoring-Stack gab: ein Sentinel-Job schreibt Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger, Gatus prüft Endpunkte, und eine in Go geschriebene Bridge bestätigt eine Alarmzustellung erst, wenn die Nachricht ankommt. Diagnostiziert Störungen aus diesen Daten und den Systemlogs, bevor Nutzende sie melden. Arbeitet an den Linux-Interna — cgroup-Limits, PSI, systemd-Härtung, Namespaces. OpenTelemetry, verteiltes Tracing, Prometheus, Grafana, Loki, AlertManager und Kubernetes sind nicht Teil dieser Erfahrung. Wohnhaft in Baden-Württemberg, Karlsruhe rund anderthalb Stunden entfernt. US-Staatsangehörigkeit mit Niederlassungserlaubnis. Deutsch C1, Englisch Muttersprache.]

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
  "Betrieb dreizehn NixOS-Hosts über drei Hardware-Generationen und mehrere Standorte, von der Beschaffung bis zur Inbetriebnahme",
  "Baute die Betriebstelemetrie selbst: Sentinel-Job mit Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine in Go geschriebene Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Diagnostizierte Störungen aus Ledger und Systemlogs, bevor Nutzende sie meldeten, und dokumentierte jede Ursache im Runbook",
  "Hielt Dienste über systemd-Optionen und cgroup-Limits klein und behandelte PSI-Speicherdruck als Messgröße erster Ordnung",
  "Beschrieb Plattform und Dienste deklarativ in einem Flake: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit",
  "Hielt jeden Stand als Generation und rollte bei Bedarf zurück; prüfte im CI denselben Zustand, der ausgerollt wird",
  "Konfigurierte Netze und Firewall als Code mit nftables, dazu DNS und ein WireGuard-Tailnet ohne öffentliche Schnittstelle",
  "Sicherte mit restic auf NAS-Ziele und führte Wiederherstellungen durch statt Sicherungsläufe zu zählen",
  "Verwaltete Geheimnisse mit sops und age und betrieb eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Schrieb Werkzeuge in Shell, Python und Go und dokumentierte jede Prozedur als Runbook",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Band Laborgeräte über C++-Anwendungen an und wertete Messreihen in Python aus",
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig — deklarierte Flotte mit Gates", "seit 2023", (
  "Ein Modul je Dienst, eine Feature-Liste je Host; ein Gate prüft Module und Assertions vor jedem Ausrollen",
  "Sentinel-Ledger über Jobstatus, Generation-Alter, Disk- und PSI-Druck, dazu eine Go-Bridge mit Zustellbestätigung",
  "Dienste hinter einem Tailnet ohne öffentliche Schnittstelle, Zertifikate über die eigene CA",
))
#entry("Autarke KI-Plattform auf eigener Hardware", "2024 – 2025", (
  "Betrieb Modellserver, Router und Weboberfläche auf eigenen Maschinen, ohne Cloud-Abhängigkeit",
  "Schrieb den Router in Go und isolierte jede Modell-Lane mit eigenen Limits und eigenem Zugang",
))

#section("Kenntnisse")
#text(weight: "bold")[Telemetrie] — eigenes JSONL-Ledger im 15-Minuten-Takt, Gatus-Prüfungen, Zustellbestätigung, Retention durch Rotation, Auswertung in Go und Python \
#text(weight: "bold")[Linux-Plattform] — NixOS und Debian-nah, systemd, cgroup-Limits, PSI, Namespaces, reproduzierbare Installation \
#text(weight: "bold")[Zuverlässigkeit] — Rückrollung je Generation, geprüfte Wiederherstellungen mit restic, Fehlersuche aus Daten und Logs \
#text(weight: "bold")[Netz und Security] — nftables als Code, DNS, Segmentierung, WireGuard, eigene CA, sops und age \
#text(weight: "bold")[Automatisierung] — Shell, Python, Go, Git als einzige Quelle, CI-Gates, Runbooks \
#text(weight: "bold")[Nicht vorhanden] — OpenTelemetry, verteiltes Tracing, Prometheus, Grafana, Loki, AlertManager, Kubernetes \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Wohnsitz Baden-Württemberg · US-Staatsangehörigkeit mit Niederlassungserlaubnis
