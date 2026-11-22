#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[NixOS, Linux-Härtung und deklarativer Betrieb]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Sicherheit, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen vollständig deklarativ auf NixOS: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung. Härtet Systeme mit nftables, Segmentierung und minimalen Rechten und hält Dienste ohne öffentliche Schnittstelle, weil air-gapped Betrieb die Normalform ist, nicht die Ausnahme. Betreibt eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, TLS über eigene CA und Geheimnisse in sops und age. Installiert Bare Metal über PXE und pflegt jede Prozedur als Runbook. Automatisiert in Shell, Python und Go. Kubernetes, CKA/CKS, Ceph und VMware sind nicht Teil dieser Erfahrung. Bereit zur Sicherheitsüberprüfung SÜ2, Reisebereitschaft vorhanden. Deutsch C1, Englisch Muttersprache.]

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
  "Betrieb dreizehn NixOS-Hosts über drei Hardware-Generationen und mehrere Standorte, von der Beschaffung über die Installation bis zur Inbetriebnahme",
  "Beschrieb Plattform und Dienste deklarativ in einem Flake: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit",
  "Prüfte im CI denselben Zustand, der ausgerollt wird, hielt jeden Stand als Generation und rollte bei Bedarf zurück",
  "Betrieb eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten und TLS über eigene CA statt langlebiger Schlüssel",
  "Verwaltete Geheimnisse mit sops und age und hielt sie aus Repositories und Klartextdateien heraus",
  "Härtete Systeme über systemd-Optionen, Ressourcenlimits und minimale Rechte und hielt Speicherdruck als Messgröße im Blick",
  "Konfigurierte Netze und Firewall als Code mit nftables, dazu DNS und ein WireGuard-Tailnet; kein Dienst mit öffentlicher Schnittstelle",
  "Lieferte Bare-Metal-Installationen über PXE und ein eigenes ISO-Archiv aus, damit Aufbau ohne externe Bezugsquelle reproduzierbar bleibt",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Band Alarmierung an eine in Go geschriebene Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Sicherte mit restic auf NAS-Ziele und prüfte Wiederherstellungen statt nur Sicherungsläufe zu zählen",
  "Dokumentierte jede Prozedur als Runbook, damit Betrieb nicht an einer Person hängt",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
  "Schrieb C++-Anwendungssoftware zur Anbindung von Laborgeräten und Python-Werkzeuge für Analyse und 3D-Geometrie",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig — deklarierte Flotte mit Gates", "seit 2023", (
  "Modularisierte die Flotte nach Diensten und Hosts; ein Gate je Host prüft Module und Assertions vor dem Ausrollen",
  "Ergänzte ein Sentinel-Ledger aus Job-Status, Generation-Alter, Disk- und PSI-Druck sowie eine Go-Bridge mit Zustellbestätigung",
  "Hielt Dienste hinter einem Tailnet und ohne öffentliche Schnittstelle; Zertifikate und Schlüssel laufen über die eigene CA",
))
#entry("Autarke KI-Plattform auf eigener Hardware", "2024 – 2025", (
  "Betrieb Modellserver, Router und Weboberfläche auf eigenen Maschinen, ohne Cloud-Abhängigkeit und ohne ausgehende Verbindung im Betrieb",
  "Schrieb den Router in Go und isolierte jede Modell-Lane mit eigenen Limits und eigenem Zugang",
))

#section("Kenntnisse")
#text(weight: "bold")[Nix und NixOS] — deklarativer Flottenbetrieb, Module je Dienst, Generationen und Rückrollung, MicroVM-Gäste \
#text(weight: "bold")[Linux] — NixOS und Debian-nah, systemd, Ressourcenlimits, PXE-Installation, reproduzierbare Aufbauten \
#text(weight: "bold")[Härtung] — nftables, Segmentierung, WireGuard, minimale Rechte, kein Dienst mit öffentlicher Schnittstelle \
#text(weight: "bold")[PKI und Geheimnisse] — eigene SSH-CA, kurzlebige Zertifikate, TLS über eigene CA, sops, age \
#text(weight: "bold")[Automatisierung] — Shell, Python, Go, Git als einzige Quelle, CI-Gates, Runbooks \
#text(weight: "bold")[Betrieb] — Monitoring-Ledger, Gatus, Zustellbestätigung, restic mit geprüften Wiederherstellungen \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes, CKA/CKS, Ceph, VMware und Hyper-V, DevSecOps-Scanning-Ketten \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache · Reisebereitschaft vorhanden · SÜ2 bereit
