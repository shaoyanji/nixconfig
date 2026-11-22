#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.6cm, bottom: 1.6cm, left: 1.9cm, right: 1.9cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 11.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.75em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Plattform und Zuverlässigkeit — Automatisierung, Telemetrie, deklarativer Betrieb]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Plattformingenieur mit fünf Jahren Verantwortung für eine Linux-Flotte, die niemand sonst betrieben hat: dreizehn Hosts über drei Hardware-Generationen, jeder Dienst ein Modul, jede Änderung ein Commit mit Prüfung und Rückrollung. Automatisiert in Go und Python, weil Handarbeit auf Dauer Fehler produziert, und gebaut mit Telemetrie, weil ein Ausfall ohne Messdaten nur eine Vermutung ist. Dazu vier Jahre Energiewirtschaft: 10 MW Solar-PV kaufmännisch betreut, M.Sc. Erneuerbare-Energien-Management in Freiburg. Wohnsitz in Baden-Württemberg, Karlsruhe in rund anderthalb Stunden erreichbar. Nicht vorhanden: Kubernetes im Produktivbetrieb, Helm und GitOps-Werkzeuge, Betrieb in einem regulierten KRITIS-Umfeld.]

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
  "Betrieb dreizehn Linux-Hosts über drei Hardware-Generationen, von der Beschaffung bis zur Außerbetriebnahme",
  "Beschrieb Hosts und Dienste deklarativ mit NixOS: ein Modul je Dienst, eine Feature-Liste je Host, kein handgeänderter Zustand auf einer Maschine",
  "Prüfte jede Änderung vor dem Ausrollen im CI gegen denselben evaluierten Zustand, der ausgerollt wurde; Rückrollung über Generationen statt Neuaufbau",
  "Baute die Telemetrie selbst: Gatus-Prüfungen und ein JSONL-Ledger alle 15 Minuten mit Jobstatus, Generation-Alter, Disk- und PSI-Druck",
  "Wertete diese Daten in Go und Python aus und band Alarmierung an eine Bridge, die eine Zustellung erst bestätigt, wenn sie angekommen ist",
  "Härtete den Rand: nftables-Regeln, Tailnet ohne öffentlichen Listener, Secrets mit sops/age je Host, Zugriff über kurzlebige Zertifikate der eigenen SSH-CA",
  "Prüfte Wiederherstellungen mit restic, statt Sicherungsläufe zu zählen, und hielt jede Generation rückrollbar",
  "Dokumentierte jede Prozedur als Runbook, damit Betriebswissen nicht an eine Person gebunden ist",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute 10 MW Solar-PV-Anlagen kaufmännisch: Finanzmodelle über die Laufzeit, Ertrags- und Kostenanalyse, Berichte an die Geschäftsführung",
  "Übersetzte Betriebsdaten in Entscheidungen: Abweichungen vom Plan, Ursachen, Maßnahmen",
  "Verantwortete Software und IT-Administration des Unternehmens samt der Systeme, in denen Anlagendaten zusammenliefen",
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
#text(weight: "bold")[Linux-Plattform] — systemd, cgroups und Namespaces, Netzwerk, nftables, Speicher und Kapazität, Boot und Wiederherstellung \
#text(weight: "bold")[Deklarativer Betrieb] — NixOS-Module, gepinnte Inputs, reproduzierbare Builds, Rückrollung über Generationen \
#text(weight: "bold")[Automatisierung] — Go, Python, Shell; Plattformwerkzeuge statt manueller Schritte \
#text(weight: "bold")[Zuverlässigkeit] — Prüfung vor dem Rollout, Health-Checks, geprüfte Wiederherstellungen, Alarmzustellung bestätigt \
#text(weight: "bold")[Telemetrie] — strukturierte Ledger, PSI- und Disk-Druck, Auswertung in Go und Python \
#text(weight: "bold")[Energie] — Ertragsdaten, Wirtschaftlichkeit, Anlagenkontext aus vier Jahren Asset-Management \
#text(weight: "bold")[Nicht vorhanden] — Kubernetes im Produktivbetrieb, Helm, GitOps-Werkzeuge, KRITIS-Regulatorik \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Wohnsitz Baden-Württemberg · US-Staatsangehörigkeit mit Niederlassungserlaubnis
