#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Plattform und Control Plane — deklarativer Flottenbetrieb, Werkzeuge in Go]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Plattformingenieur, der die Werkzeuge selbst gebaut hat, statt sie einzukaufen: fünf Jahre Betrieb einer Linux-Flotte mit dreizehn Hosts über drei Hardware-Generationen, deklarativ beschrieben, jede Änderung durch ein Gate geprüft und als Generation rückrollbar. Monitoring ist eigene Messung — ein Ledger mit Messwerten alle fünfzehn Minuten, Gatus-Prüfungen, Alarmzustellung mit Bestätigung —, nicht ein Dashboard-Abo. Automatisiert in Go und Python, abgesichert mit nftables als Code, sops und age sowie einer eigenen CA mit kurzlebigen Zertifikaten. Wohnsitz in Baden-Württemberg, Bad Friedrichshall in rund zwei Stunden erreichbar. Nicht vorhanden: Kubernetes-Architektur, Operator-Pattern, Istio und Calico, Helm und Kustomize, Terraform und Pulumi.]

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
  "Betrieb dreizehn Linux-Hosts über drei Hardware-Generationen, inklusive PXE-Installation, Inbetriebnahme und Außerbetriebnahme",
  "Beschrieb Hosts und Dienste deklarativ mit NixOS: ein Modul je Dienst, eine Feature-Liste je Host, kein handgeänderter Zustand auf einer Maschine",
  "Prüfte jede Änderung vor dem Ausrollen gegen denselben evaluierten Zustand, der ausgerollt wurde, und hielt jede Generation rückrollbar",
  "Baute Monitoring als eigene Messung: Gatus-Prüfungen und ein JSONL-Ledger alle 15 Minuten mit Jobstatus, Generation-Alter, Disk- und PSI-Druck",
  "Schrieb die Werkzeuge in Go und Python: Alarm-Bridge mit Zustellbestätigung, Router für Modellanfragen, Auswertungen über Messreihen",
  "Härtete die Plattform: nftables als Code, DNS, Segmentierung, WireGuard-Mesh ohne öffentlichen Listener, sops/age je Host, eigene CA mit kurzlebigen Zertifikaten",
  "Arbeitete an den Linux-Interna: cgroup-Limits, Namespaces, PSI, systemd-Härtung, Boot und Wiederherstellung ohne Konsole",
  "Hielt Betriebswissen in Runbooks und jede Änderung in Git, damit die Plattform nicht an eine Person gebunden ist",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute 10 MW Solar-PV-Anlagen kaufmännisch: Finanzmodelle, Ertrags- und Kostenanalyse, Berichte an die Geschäftsführung",
  "Verantwortete Software und IT-Administration des Unternehmens samt der Systeme, in denen Anlagendaten zusammenliefen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Band Laborgeräte über C++-Anwendungen an und wertete Messreihen mit Python aus",
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
))

#section("Projekte")
#entry("nixconfig — Plattform mit Prüfung vor dem Ausrollen", "seit 2023", (
  "Eine Flake beschreibt Hosts, Dienste und Rollen; ein Gate prüft Module und Assertions vor jedem Rollout",
  "Health-Checks, Job-Ledger und Agenten-Protokoll laufen auf derselben Plattform, die sie beobachten",
  "Veröffentlichen, Ausrollen und Rückrollen sind Tasks, keine Handgriffe auf einem Host",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft und Technikbewertung",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Linux] — systemd, cgroups, Namespaces, PSI, nftables, DNS, Speicher und Kapazität, PXE, Boot und Recovery \
#text(weight: "bold")[Deklarativer Betrieb] — NixOS-Module, gepinnte Inputs, reproduzierbare Builds, Rückrollung über Generationen \
#text(weight: "bold")[Werkzeuge] — Go, Python, Shell; Monitoring, Alarmierung mit Zustellbestätigung, Automatisierung interner Abläufe \
#text(weight: "bold")[Sicherheit] — sops und age, eigene CA, kurzlebige Zertifikate, Segmentierung, keine offenen Sockets \
#text(weight: "bold")[Betrieb] — Git als einzige Quelle, CI-Gates, Runbooks, Auditspur über Messdaten \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes-Architektur, Operator-Pattern, Istio/Calico, Helm/Kustomize, Terraform/Pulumi, Concourse/Flux \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Wohnsitz Baden-Württemberg · Niederlassungserlaubnis
