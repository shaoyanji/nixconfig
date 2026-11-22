#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Plattformbetrieb, Linux-Interna und Werkzeuge in Go]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Werkzeugbau. Betreibt dreizehn Server über drei Hardware-Generationen als einen deklarativen Zustand: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate, jeder Stand als Generation rückrollbar. Die Betriebsdisziplin ist die einer Plattform: nichts wird von Hand geändert, jede Abweichung ist ein Fehler im Repository, und der Weg zurück ist immer offen. Arbeitet an den Linux-Interna — cgroup-Limits, PSI, systemd-Härtung, Namespaces — und schreibt Werkzeuge in Go, darunter eine Alarm-Bridge mit Zustellbestätigung und den Router einer autarken KI-Plattform. Baut Monitoring selbst: Sentinel-Ledger alle 15 Minuten, Gatus, Zustellbestätigung. Kubernetes-Architektur, Operator-Pattern, Istio/Calico, Helm/Kustomize, Terraform/Pulumi und Concourse/Flux sind nicht Teil dieser Erfahrung. US-Staatsangehörigkeit mit Niederlassungserlaubnis. Deutsch C1, Englisch Muttersprache.]

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
  "Betrieb dreizehn Hosts über drei Hardware-Generationen und mehrere Standorte, von der Beschaffung bis zur Inbetriebnahme",
  "Beschrieb den gesamten Zustand deklarativ in einem Flake: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit",
  "Prüfte im CI denselben Zustand, der ausgerollt wird, und hielt jeden Stand als Generation, auf die sich zurückrollen lässt",
  "Hielt den Betrieb frei von Handarbeit: keine lokal geänderten Maschinen, keine Konfiguration, die nur auf einem Host existiert",
  "Schrieb interne Werkzeuge, die wiederkehrende Arbeit ersetzten: Alarm-Bridge, Ledger-Auswertung, PXE-Auslieferung, Task-Einstiegspunkte",
  "Begrenzte Dienste über systemd-Optionen und cgroup-Limits und behandelte PSI-Speicherdruck als Messgröße",
  "Konfigurierte Netze und Firewall als Code mit nftables, dazu DNS, Segmentierung und ein WireGuard-Tailnet ohne öffentliche Schnittstelle",
  "Baute Monitoring selbst: ein Sentinel-Job schreibt Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger",
  "Band Alarmierung an eine in Go geschriebene Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Verwaltete Geheimnisse mit sops und age und betrieb eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Dokumentierte jede Prozedur als Runbook, damit Betrieb nicht an einer Person hängt",
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
#text(weight: "bold")[Linux-Interna] — systemd, cgroup-Limits, PSI, Namespaces, Boot-Konfiguration, PXE-Installation \
#text(weight: "bold")[Plattformbetrieb] — Nix und NixOS, Module je Dienst, Generationen, Rückrollung, Gates in CI, Git als einzige Quelle \
#text(weight: "bold")[Go und Werkzeuge] — Alarm-Bridge mit Zustellbestätigung, Router der KI-Plattform, Auswertungen über Ledger-Daten \
#text(weight: "bold")[Monitoring] — eigenes JSONL-Ledger im 15-Minuten-Takt, Gatus, Zustellbestätigung, Störungsdiagnose aus Daten \
#text(weight: "bold")[Netz und Security] — nftables als Code, DNS, Segmentierung, WireGuard, eigene CA, sops und age \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes-Architektur, Operator-Pattern, Istio/Calico, Helm/Kustomize, Terraform/Pulumi, Concourse/Flux \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · US-Staatsangehörigkeit mit Niederlassungserlaubnis
