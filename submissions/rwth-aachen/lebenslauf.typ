// RWTH Aachen — IT-Beschäftigte*r Data & DevOps (V000011705). Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#0f3d3e"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#0f3d3e")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 7pt, below: 2pt)[
  #text(size: 9.6pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 10pt)[Datenpipelines · PostgreSQL · reproduzierbare Auswertungsumgebungen]
  ],
  [
    #align(right)[
      #text(size: 8.5pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
      #linebreak()
      #text(size: 8.5pt)[matt\@bountystash.com · github.com/shaoyanji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profil")
Datenarbeit in der Forschung endet selten an der Auswertung; sie endet an der Frage, ob ein Ergebnis in
zwei Jahren noch einmal herauskommt. Ich baue deshalb Umgebungen, in denen die Antwort auf Versionen
zurückgeht: Auswertungen als Code, Datenbanken mit Schema und Migration, Rechner deklarativ beschrieben,
dieselbe Umgebung für alle Beteiligten. Ich habe am Fraunhofer ISE Messdaten ausgewertet und die Werkzeuge
dafür selbst geschrieben, danach Jahre mit Betriebsdaten und Telemetrie gearbeitet und Postgres-Dienste
gebaut. Deutsch C1, Englisch Muttersprache, US-Staatsbürger mit deutscher Niederlassungserlaubnis.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Python* — pandas, NumPy, Datenaufbereitung, Messdatenanalyse, Skripte mit Tests],
  [*PostgreSQL* — Schema, Migrationen, Abfragen, append-only Daten, Betrieb],
  [*Datenpipelines* — Ingest, Normalisierung, Qualitätsprüfung, Zeitreihen],
  [*Reproduzierbarkeit* — gepinnte Umgebungen, deklarierte Rechner, Rebuild statt Reparatur],
  [*Linux* — NixOS, systemd, journald, cgroups, nftables, Shell-Automatisierung],
  [*Statistik und ML* — Zeit-Kreuzkorrelation, neuronale Netze, Validierung],
  [*Schnittstellen* — REST, JSON, CSV, SQL; Datenübergabe an Fachbereiche],
  [*Dokumentation* — Runbooks, Methodennotizen, nachvollziehbare Entscheidungen])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Baute einen Dienst in Go, der Anfragen als unveränderliche, inhaltsadressierte Spezifikation ablegt; Events append-only, gespeichert in PostgreSQL.
- Entwickelte Datenwerkzeuge in Python für Auswertung, Normalisierung und Qualitätsprüfung, mit Tests statt Einmal-Skripten.
- Beschrieb dreizehn Linux-Hosts deklarativ, sodass eine Auswertungsumgebung auf jedem Host identisch und in definierter Zeit wiederherstellbar ist.
- Automatisierte Beschaffung, Aufbereitung und Auslieferung von Zeitreihen — unter anderem CISAs KEV-Katalog als Wochenreihe.
- Überwachte Rohrleitungen und Dienste mit einem Ledger alle fünfzehn Minuten und meldete jeden Zustand ungleich ok.
- Dokumentierte Methoden und Entscheidungen so, dass Dritte die Auswertung ohne Rückfrage wiederholen konnten.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Verantwortete Ertragsmodelle und Datenqualität für ein Solarportfolio über 100 Mio. USD: Messdaten, Telemetrie-Abgleich, Abweichungsanalysen.
- Führte mobile Felderfassung ein und glich fehlende Sensordaten systematisch aus, statt Lücken zu schätzen.
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften.
- Erstellte Finanzmodelle, die Bankprüfungen bestanden.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie und Risikomanagement, mit Datenmodellen als Grundlage der Empfehlung.
- Betreute eine Projektpipeline über 100 Mio. USD.

#job("Wissenschaftliche Hilfskraft", "Fraunhofer ISE", "März 2012 – Sept. 2012")
- Vermaß Heliostat-Ungenauigkeiten mit Interferometrie und schrieb die C++-Anwendung zur Geräteanbindung.
- Schrieb Python-Werkzeuge für Messdatenanalyse und 3D-Geometrie und wertete die Messreihen statistisch aus.
- Arbeitete in einem Forschungsteam mit festen Messkampagnen — Ergebnisse mussten reproduzierbar sein, nicht nur plausibel.

#job("Associate Technical Professional", "Halliburton", "Juni 2010 – Sept. 2011")
- Behob Geräte- und Prozessprobleme vor Ort, unter Zeitdruck und ohne zweiten Versuch.
- Leitete die Sicherheitsschulung der Crew.

#section("Ausgewählte Projekte")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— Datenprodukt]
    #linebreak()
    Öffentliche Schwachstellenlisten als bereinigte Zeitreihe: Ingest, Normalisierung, Exposition nach
    Behebungsaufwand, Ausgabe als SVG ohne Abhängigkeiten.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— reproduzierbare Umgebung]
    #linebreak()
    Ein Flake beschreibt dreizehn Hosts, Dienste, Secrets und eine Task-Oberfläche; CI und Host führen
    dasselbe Gate aus.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go und PostgreSQL]
    #linebreak()
    Unveränderliche Spezifikationen aus Anfragen, append-only Events, Abfragen über einen Index statt
    Tabellenscans.
  ],
  [
    #text(weight: "bold")[Masterarbeit] #text(size: 8pt, fill: muted)[— Prognose]
    #linebreak()
    Zeit-Kreuzkorrelation von Windgeschwindigkeit und neuronale Netze auf Langzeit-Wetterdaten,
    mit Validierung außerhalb des Trainingszeitraums.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Erneuerbare-Energien-Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · ab sofort verfügbar]
