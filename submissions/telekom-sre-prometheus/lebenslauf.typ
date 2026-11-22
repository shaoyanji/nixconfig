#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Betrieb, Telemetrie und Zuverlässigkeit]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Anwenderbetreuung, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen auf eigener Hardware, ohne Managed Cloud, mit begrenzten Ressourcen. Baute die Betriebstelemetrie selbst: ein Sentinel-Job schreibt alle 15 Minuten Jobstatus, Generation-Alter, Disk- und PSI-Druck in ein JSONL-Ledger; Gatus prüft Endpunkte; eine Go-Bridge bestätigt eine Alarmzustellung erst, wenn die Nachricht ankommt. Hält Dienste über systemd-Optionen und Ressourcenlimits klein und behandelt Speicherdruck als Messgröße erster Ordnung. Sichert mit restic und führt Wiederherstellungen durch, jede Änderung ist auf die vorherige Generation rückrollbar. Prometheus, Grafana, Loki, AlertManager und Kubernetes sind nicht Teil dieser Erfahrung; die Telemetrie ist eigenbau, nicht der genannte Stack. Wohnhaft in Baden-Württemberg, Karlsruhe als Standort bevorzugt. Deutsch C1, Englisch Muttersprache.]

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
  "Baute die Betriebstelemetrie selbst: Sentinel-Job mit Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Optimierte den Betrieb unter knappen Ressourcen: systemd-Limits je Dienst, Speicherdruck als Messgröße, Retention über Rotation statt Wachstum",
  "Diagnostizierte Störungen aus dem Ledger und den Systemlogs, bevor Nutzende sie meldeten, und dokumentierte jede Ursache",
  "Betrieb ohne öffentliche Schnittstelle: alles im WireGuard-Tailnet, Netze und Firewall als Code mit nftables",
  "Sicherte mit restic auf ein NAS und führte Wiederherstellungen durch; jede Änderung ist auf die vorherige Generation rückrollbar",
  "Verwaltete Geheimnisse mit sops und age, Host-Schlüssel über eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Schrieb Werkzeuge in Go und Python, darunter die Alarm-Bridge und Auswertungen über das Ledger",
  "Dokumentierte jede Prozedur als Runbook, damit Betriebswissen nicht an eine Person gebunden ist",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
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
  "Deklarierte die Flotte in einem Flake: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate",
  "Ergänzte das Sentinel-Ledger um PSI-Druck und Generation-Alter, weil ein grüner Job-Status allein keinen Ausfall erklärt",
  "Betrieb eine autarke KI-Plattform auf eigener Hardware mit Modellserver, Go-Router und Zugang nur über das Tailnet",
))

#section("Kenntnisse")
#text(weight: "bold")[Telemetrie] — eigenes JSONL-Ledger, Endpunktprüfungen, Zustellbestätigung, Retention durch Rotation, Auswertung mit Go und Python \
#text(weight: "bold")[Betrieb] — NixOS und Debian-nah, systemd, Ressourcenlimits, Speicherdruck, Boot-Konfiguration, reproduzierbare Installation \
#text(weight: "bold")[Zuverlässigkeit] — Rückrollung je Generation, geprüfte Wiederherstellungen mit restic, Fehlersuche in Logs und Paketen \
#text(weight: "bold")[Sicherheit] — sops, age, eigene SSH-Zertifizierungsstelle, kurzlebige Zertifikate, nftables, keine offene Schnittstelle \
#text(weight: "bold")[Automatisierung] — deklarative Konfiguration, Git als einzige Quelle, CI-Gates, Shell, Python, Go \
#text(weight: "bold")[Nicht vorhanden] — Prometheus/PromQL, Grafana, Loki/LogQL, AlertManager, Kubernetes, Terraform, Ansible, OpenTelemetry \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache
