#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systembetrieb und Automatisierung — Open Source, Monitoring, Remote]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit fünf Jahren Alleinbetrieb einer Flotte aus dreizehn Hosts über drei Hardware-Generationen: installieren, betreiben, messen, reparieren, dokumentieren. Deklarativ beschrieben, jede Änderung durch ein Gate geprüft, jeder Stand rückrollbar. Monitoring war eigene Arbeit — Ledger mit Messwerten alle fünfzehn Minuten, Prüfungen, Alarmzustellung mit Bestätigung — und Betriebshandbücher gehören zum Ergebnis, nicht zur Kür. Automatisiert in Python und Go. Open Source ist Arbeitsgrundlage, nicht Beiwerk. Fünf Jahre remote gearbeitet, mit asynchroner Dokumentation statt Büropräsenz. Nicht vorhanden: Kubernetes, OpenShift und OpenStack im Betrieb, GitLab CI/CD, Debian/RHEL/SLES im Produktivbetrieb, PostgreSQL- oder MySQL-Administration, LDAP/AD.]

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
  "Betrieb dreizehn Linux-Hosts über drei Hardware-Generationen: Installation per PXE, Inbetriebnahme, Wartung, Außerbetriebnahme",
  "Arbeitete mit systemd-naher Konfiguration, cgroups, Namespaces sowie PSI- und Disk-Druck als Messgrößen für Engpässe",
  "Beschrieb Hosts und Dienste deklarativ mit NixOS; jede Änderung ein Commit mit Gate und Rückrollung über Generationen",
  "Baute Monitoring selbst: Prüfungen, Ledger alle 15 Minuten, Alarmierung in Go mit Zustellbestätigung",
  "Automatisierte wiederkehrende Abläufe in Python und Go statt sie zu dokumentieren — von Rollout bis Auswertung",
  "Schrieb Betriebshandbücher und Runbooks für jede Prozedur und erklärte Nutzenden den Umgang mit den Diensten",
  "Betrieb über fünf Jahre vollständig remote, mit schriftlicher Übergabe als Standard",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute 10 MW Solar-PV-Anlagen kaufmännisch und verantwortete Software sowie IT-Administration des Unternehmens",
  "Erstellte Finanzmodelle, wertete Betriebsdaten aus und berichtete an die Geschäftsführung",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Band Laborgeräte über C++-Anwendungen an und wertete Messreihen mit Python aus",
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
))

#section("Projekte")
#entry("nixconfig — Flotte mit Prüfung vor dem Ausrollen", "seit 2023", (
  "Eine Flake beschreibt Hosts, Dienste und Rollen; ein Gate prüft Module und Assertions vor jedem Rollout",
  "Health-Checks, Job-Ledger und Agenten-Protokoll laufen auf derselben Plattform, die sie beobachten",
  "Veröffentlichen, Ausrollen und Rückrollen sind Tasks, keine Handgriffe auf einem Host",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft und Technikbewertung",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Linux] — Installation und Boot, systemd, cgroups, Namespaces, Speicher und Kapazität, nftables, DNS \
#text(weight: "bold")[Automatisierung] — Python, Go, Shell, Nix; Rollout, Auswertung, wiederkehrende Abläufe \
#text(weight: "bold")[Monitoring] — Prüfungen, strukturierte Ledger, PSI- und Disk-Druck, Alarmzustellung bestätigt \
#text(weight: "bold")[CI/CD] — Git als einzige Quelle, Gate vor dem Rollout, reproduzierbare Builds, Rückrollung \
#text(weight: "bold")[Dokumentation] — Betriebshandbücher, Runbooks, Schulung von Nutzenden, asynchrone Zusammenarbeit \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes/OpenShift/OpenStack im Betrieb, GitLab CI/CD, Debian/RHEL/SLES produktiv, PostgreSQL/MySQL-Administration, LDAP/AD \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Wohnsitz Baden-Württemberg · Niederlassungserlaubnis · 100 % Remote erprobt
