// Alexander Thamm GmbH — Principal DevOps Engineer. Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#2b1f5c"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2b1f5c")
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
    #text(size: 10pt)[Plattformarchitektur · Daten- und KI-Pipelines · deklarierte Systeme]
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
Ich baue Plattformen, die ein Team benutzen kann, ohne mich zu fragen, und die ein Prüfer nachvollziehen kann,
ohne mich zu kennen: dreizehn Linux-Hosts aus einer Deklaration, jede Änderung durch ein Gate, das in der CI
und auf dem Host identisch ist, Rollback als Zeiger auf die vorige Generation. Dazu betreibe ich eine lokale
Inferenz-Plattform auf eigener Hardware — Modelle hinter einem Router, On-Demand-Start, Auslastungsschutz —
und habe davor Datenpipelines und Ertragsmodelle für ein Energieportfolio verantwortet. Führungsverantwortung
habe ich als Gründer getragen, nicht als disziplinarischer Vorgesetzter eines Ingenieurteams; das steht im
Anschreiben, bevor es im Gespräch steht.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Plattform* — deklarierter Zustand, gepinnte Inputs, Rollback, Rebuild statt Reparatur],
  [*Daten* — Python, pandas, NumPy, PostgreSQL, Ingest und Qualitätsprüfung],
  [*KI-Betrieb* — lokale Modelle, Router, On-Demand-Start, GPU-Auslastung, Endpunkte],
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump, strace],
  [*Hochverfügbarkeit* — Gates vor dem Rollout, Generation-Rollback, Telemetrie alle 15 Minuten],
  [*Sicherheit* — nftables Default-Deny, SOPS/age, SSH-CA, Minimalrechte],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Dokumentation* — Architekturentscheidungen, Runbooks, Übergabe ohne Rückfrage])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Verantwortete Architektur und Betrieb einer Plattform aus dreizehn Linux-Hosts, vollständig deklarativ und ohne Handarbeit auf dem Zielsystem.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Betrieb eine lokale Inferenz-Plattform auf eigener Hardware: mehrere Modelle hinter einem Router, On-Demand-Start, ein Schutz, der schwere Jobs gegen interaktive Anfragen abwägt.
- Entwickelte Datenwerkzeuge in Python für Ingest, Normalisierung und Qualitätsprüfung, mit Tests statt Einmal-Skripten.
- Baute einen Dienst in Go mit append-only Ereignissen in PostgreSQL und einer Terminal-Oberfläche aus einem Binary.
- Überwachte den Betrieb mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Härtete Systeme mit nftables als Default-Deny, SOPS/age-verschlüsselten Secrets pro Host und einer SSH-CA mit kurzlebigen Zertifikaten.
- Dokumentierte Architekturentscheidungen und Betriebswissen so, dass Dritte sie ohne Rückfrage nutzen konnten.
- Arbeitete fünf Jahre ortsunabhängig und übergab schriftlich statt mündlich.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD: Messdaten, Telemetrie-Abgleich, Abweichungsanalysen.
- Führte mobile Felderfassung ein und glich fehlende Sensordaten systematisch aus.
- Berichtete Anlagenzustand und Abweichungen an Eigentümer und Banken, in prüfbarer Form.
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie und Risikomanagement, mit Datenmodellen als Grundlage der Empfehlung.
- Betreute eine Projektpipeline über 100 Mio. USD.

#job("Wissenschaftliche Hilfskraft", "Fraunhofer ISE", "März 2012 – Sept. 2012")
- Vermaß Heliostat-Ungenauigkeiten mit Interferometrie und schrieb die C++-Anwendung zur Geräteanbindung.
- Schrieb Python-Werkzeuge für Messdatenanalyse und 3D-Geometrie.

#job("Associate Technical Professional", "Halliburton", "Juni 2010 – Sept. 2011")
- Behob Geräte- und Prozessprobleme vor Ort, unter Zeitdruck und ohne zweiten Versuch.
- Leitete die Sicherheitsschulung der Crew.

#section("Ausgewählte Projekte")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[eisen] #text(size: 8pt, fill: muted)[— souveräne Inferenz]
    #linebreak()
    Lokale Modelle auf eigener GPU: OpenAI-kompatible Endpunkte, Sprach- und Bildpfade, Router und
    Auslastungsschutz, damit kein Prompt das Haus verlässt.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Plattform as Code]
    #linebreak()
    Ein Flake beschreibt dreizehn NixOS-Hosts, Dienste, Secrets, Telemetrie und eine Task-Oberfläche;
    CI und Host führen dasselbe Gate aus.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— Datenprodukt]
    #linebreak()
    Öffentliche Schwachstellenlisten als bereinigte Zeitreihe: Ingest, Normalisierung, Exposition nach
    Behebungsaufwand.
  ],
  [
    #text(weight: "bold")[Masterarbeit] #text(size: 8pt, fill: muted)[— Prognose]
    #linebreak()
    Zeit-Kreuzkorrelation von Windgeschwindigkeit und neuronale Netze auf Langzeit-Wetterdaten.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Erneuerbare-Energien-Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · remote erprobt seit 2020]
