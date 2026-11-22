#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.58em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Betriebstelemetrie und Systemzuverlässigkeit — Linux, Edge-Hardware, Automatisierung]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre Telemetrie für dreizehn Linux-Hosts auf eigener Hardware, ohne Managed Cloud und ohne öffentliche Schnittstelle: ein Sentinel-Job schreibt alle fünfzehn Minuten Jobstatus, Alter der laufenden Generation, Speicher- und Prozessdruck in ein Ledger; Gatus prüft Endpunkte von außen; eine Go-Bridge führt einen Alarm erst dann als gemeldet, wenn die Zustellung bestätigt ist. Dazu Ressourcengrenzen je Dienst, Speicherdruck als Messgröße erster Ordnung, Sicherungen mit durchgeführten Wiederherstellungen und Rückrollung über Generationen. Prometheus, Grafana, Loki und AlertManager habe ich nicht betrieben; das steht im Anschreiben.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(6pt)
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
  #v(4pt)
]

#section("Berufserfahrung")
#entry("Bountystash — Gründer und alleiniger Betreiber", "2020 – 2025", (
  "Dreizehn Linux-Hosts über drei Hardware-Generationen, alle mit begrenzter CPU, Speicher und Plattenplatz statt geplanter Reserve",
  "Telemetrie selbst gebaut: Ledger mit Zeitstempel alle fünfzehn Minuten, Erreichbarkeits- und Antwortzeitprüfungen von außen, Auswertung von Druck und Speicher",
  "Alarmierung als Zustellproblem behandelt: Go-Bridge mit Bestätigung, damit ein ausgelöster Alarm nicht unbemerkt verfällt",
  "Speicher- und Prozessdruck, Alter der Generation und Plattenplatz als Vorlaufgrößen prüfen, weil sie einem Ausfall vorausgehen",
  "Sicherungen mit restic und tatsächlich durchgeführten Rückspielungen; Rückrollung über die vorige Generation als Routine",
  "Netz und Zugang im Code: nftables, WireGuard ohne öffentlichen Listener, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Infrastruktur als Beschreibung, nicht als Handarbeit: gepinnte Eingaben, Prüfung vor dem Rollout, erzeugte Dokumentation",
  "Werkzeuge in Python, Go und Shell für Rollout, Auswertung, Berichte und Alarmwege",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung und Verantwortung für Software und IT des Unternehmens",
  "Betriebsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau im Labor betreut, Geräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "In einem Forschungsumfeld mit geteilten Rechnern und dokumentierten Auswertungen gearbeitet",
))

#section("Projekte")
#entry("nixconfig — ein Bestand, einmal beschrieben", "seit 2023", (
  "Ein Host registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen aus demselben Graphen",
  "Trennung von Zustand und Auswertung: der Bestand beschreibt, das Ledger beobachtet, die Auswertung entscheidet",
  "Veröffentlichen, Ausrollen und Rückrollen sind Aufgaben, keine Eingriffe auf dem Host",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst messen, dann ändern: eine Änderung ohne Vorher-Nachher-Wert ist eine Vermutung. \
  - Alarmierung ist erst fertig, wenn die Zustellung bestätigt ist; alles andere ist ein Dashboard. \
  - Knappe Ressourcen sind eine Anforderung, keine Ausrede: Retention, Rotation und Abtastrate gehören ins Konzept.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Betrieb] — Linux-Server, systemd, cgroups, Namespaces, PSI und Speicherdruck, Boot und Wiederherstellung \
#text(weight: "bold")[Telemetrie] — Ledger mit Zeitstempel, Gatus-Prüfungen, Go-Alarmbrücke mit Zustellbestätigung, Vorlaufgrößen statt Ausfallmeldungen \
#text(weight: "bold")[Automatisierung] — Nix-Flakes als Infrastructure as Code, Gates, Aufgaben, erzeugte Dokumentation; Python, Go, Shell \
#text(weight: "bold")[Sicherheit] — eigene Zertifizierungsstelle, kurzlebige Zertifikate, sops und age je Host, nftables \
#text(weight: "bold")[Nicht vorhanden] — Prometheus und PromQL, Grafana, Loki und LogQL, AlertManager-Routing, Kubernetes-Monitoring, YAML-Konfiguration im großen Stil, Terraform, Ansible, OpenTelemetry \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Karlsruhe in rund eineinhalb Stunden erreichbar
