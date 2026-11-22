#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.6cm, bottom: 1.6cm, left: 1.9cm, right: 1.9cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 11pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.70em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Cloud- und Linux-Plattform — Infrastructure as Code, CI/CD, Betriebssicherheit]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 10pt)[Cloud- und Linux-Plattformingenieur mit zehn Jahren Erfahrung an der Schnittstelle von Betrieb und Automatisierung. Baut Infrastruktur, deren Zustand ausschließlich aus dem Repository kommt: dreizehn NixOS-Hosts als ein Flake, jeder Host eine Feature-Liste, jeder Dienst ein Modul, Netz und Firewall als Code. Eine Server-Generation entsteht unveränderlich aus dem Repository und lässt sich mit einem Befehl zurückrollen; Gates prüfen vor dem Ausrollen denselben Zustand, der ausgerollt wird. Secrets liegen in sops und age, Zugang über eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten. Ein Sentinel schreibt Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten. Kubernetes, Terraform und Ansible sind Grundlage, nicht Produktivbetrieb. Deutsch C1, Englisch Muttersprache, bundesweit mobil.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(10pt)
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
  #v(7pt)
]

#section("Berufserfahrung")
#entry("Bountystash — Gründer und alleiniger Betreiber", "2020 – 2025", (
  "Baute und betrieb dreizehn NixOS-Hosts über drei Hardware-Generationen als eine deklarative Plattform, inklusive PXE-Installation und Inbetriebnahme",
  "Hielt den gesamten Zustand im Repository: jeder Host eine Feature-Liste, jeder Dienst ein Modul, Netz und Firewall als Code",
  "Stellte jede Server-Generation unveränderlich aus dem Repository bereit, sodass ein Rollback ein Befehl ist und kein Eingriff auf der Maschine",
  "Absicherte jede Änderung mit inventargetriebener CI und einem Modul-Gate je Host, bevor sie einen Host erreichte; dazu Prüfungen auf sops-Drift, Oberflächen und Links",
  "Betrieb Secrets ohne Dauerzustand: sops mit age, Host-Schlüssel aus einer eigenen SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten in ein Ledger schreibt, ergänzt um Gatus-Prüfungen",
  "Baute Werkzeuge in Go, Python und Shell, darunter eine Alarm-Bridge, die eine Zustellung erst bestätigt, wenn sie angekommen ist",
  "Dokumentierte jede Prozedur als Runbook, damit Betrieb nicht an einer Person hängt",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Verantwortete Software und IT-Administration des Unternehmens und seiner Tochtergesellschaften, inklusive der Systeme mit den Anlagendaten",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen kaufmännisch",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Band Laborgeräte über C++-Anwendungen an und wertete Messreihen mit Python aus",
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
))

#section("Projekte")
#entry("nixconfig — Plattform mit Prüfung vor dem Ausrollen", "seit 2023", (
  "Ein Flake beschreibt Hosts, Dienste und Rollen; ein Gate prüft Module und Assertions vor jedem Rollout",
  "Health-Checks, Job-Ledger und Agenten-Protokoll laufen auf derselben Plattform, die sie beobachten",
  "Veröffentlichen, Ausrollen und Rückrollen sind Tasks, keine Handgriffe auf einem Host",
))
#entry("bountystash — unveränderliche Spezifikationen als Go-Dienst", "2020 – 2025", (
  "Ein Go-Dienst macht aus einer Anfrage eine inhaltsadressierte, unveränderliche Spezifikation mit Append-only-Events",
  "Modellierte jede Anfrage als Ereignisprotokoll, damit Ergebnisse reproduzierbar bleiben statt veränderlicher Datensatz",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2; Ingenieurausbildung mit Mess- und Versuchstechnik",))

#section("Kenntnisse")
#text(weight: "bold")[Linux und Plattform] — NixOS und Debian-nah, systemd, cgroups, Namespaces, PXE, reproduzierbare Builds über Binary-Cache und Remote-Builder \
#text(weight: "bold")[Infrastructure as Code] — Zustand vollständig im Repository, unveränderliche Generationen, Rückrollung per Befehl, Gate vor dem Deploy \
#text(weight: "bold")[CI/CD] — inventargetriebene Pipelines, Modul-Gate je Host, sops-Drift, Oberflächen- und Linkprüfungen \
#text(weight: "bold")[Netzwerk] — nftables als Code, DNS, Segmentierung, WireGuard-Tailnet, TCP-Grundlagen \
#text(weight: "bold")[Sicherheit] — sops und age, eigene SSH-CA mit kurzlebigen Zertifikaten, kein Dienst mit öffentlicher Schnittstelle, minimale Rechte \
#text(weight: "bold")[Code] — Go, Python, Shell; Git als einzige Quelle \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes im Produktivbetrieb (on premise), Terraform, Ansible, ArgoCD und Flux, Hochverfügbarkeit und Failover im Kundenmaßstab, BSI-Grundschutz-Zertifizierung \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · US-Staatsangehörigkeit mit Niederlassungserlaubnis · bundesweit mobil
