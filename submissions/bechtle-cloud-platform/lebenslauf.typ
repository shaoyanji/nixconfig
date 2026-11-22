// Bechtle AG / KubeOps — Cloud Platform Engineer (w/m/d), Remote. Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#1b3a57"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1b3a57")
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
    #text(size: 10pt)[Linux-Plattformen · Automatisierung · Remote-Betrieb]
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
Ich baue Plattformen, deren Zustand aus einer Deklaration entsteht und deren Änderungen prüfbar bleiben:
dreizehn Linux-Hosts aus einem Repository, jede Änderung durch ein Gate, das in CI und auf dem Host identisch
ist, jeder Rückweg ein Zeiger auf die vorige Generation. Automatisierung ist dabei die Bedingung, nicht die
Kür — und Dokumentation der Teil, der eine Übergabe ohne Rückfrage möglich macht. Fünf Jahre habe ich
vollständig ortsunabhängig gearbeitet, mit schriftlicher Übergabe statt Zuruf. Kubernetes und Terraform habe
ich nicht produktiv verantwortet; die Schicht darunter, den Betrieb und die Arbeitsweise bringe ich mit. Ich
bin bereit zur Sicherheitsüberprüfung SÜ2.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, journald, cgroups/PSI, nftables, tcpdump],
  [*IaC* — deklarierter Zustand, gepinnte Inputs, Rebuild statt Reparatur],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Gates / CI* — Prüfung identisch in CI und Host, kein Rollout ohne Check],
  [*Container* — gepinnte Bauumgebungen, MicroVMs als Gäste; kein K8s-Betrieb],
  [*Souveränität* — lokale Inferenz auf eigener Hardware, Daten bleiben im Haus],
  [*Sicherheit* — SOPS/age, SSH-CA, Default-Deny, Minimalrechte],
  [*Remote* — fünf Jahre ortsunabhängig, schriftliche Übergabe als Standard])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Betreute dreizehn Linux-Hosts deklarativ: gewünschter Zustand im Repository, keine Handarbeit auf dem Zielhost, Rebuild als beschriebener Pfad.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash hinter einer einheitlichen Task-Oberfläche.
- Isolierte Arbeitslasten über MicroVMs als deklarierte Gäste und systemd-Slices mit Speichergrenzen; nutzte Container als gepinnte Bauumgebungen.
- Betrieb eine lokale Inferenz-Plattform auf eigener Hardware: mehrere Modelle hinter einem Router, On-Demand-Start, Auslastungsschutz.
- Überwachte den Betrieb mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Härtete Systeme mit nftables als Default-Deny, SOPS/age-verschlüsselten Secrets pro Host und einer SSH-CA mit kurzlebigen Zertifikaten.
- Dokumentierte Architekturentscheidungen und Betriebswissen so, dass Dritte sie ohne Rückfrage nutzen konnten.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD.
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften.
- Führte Software-Rollouts durch und dokumentierte sie nachvollziehbar.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie und Risikomanagement, mit Datenmodellen als Grundlage.
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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Plattform als Code]
    #linebreak()
    Ein Flake beschreibt dreizehn Hosts, Dienste, Secrets, Telemetrie und eine Task-Oberfläche; CI und Host
    führen dasselbe Gate aus.
  ],
  [
    #text(weight: "bold")[eisen] #text(size: 8pt, fill: muted)[— souveräne Inferenz]
    #linebreak()
    Lokale Modelle auf eigener GPU mit OpenAI-kompatiblen Endpunkten: Datenhoheit als Betriebsentscheidung,
    nicht als Folie.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Betriebsblick]
    #linebreak()
    Ein Ledger prüft Jobstatus, Generation Age, Disk-Druck und PSI und meldet jeden Zustand ungleich ok.
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis · Bereitschaft zur Sicherheitsüberprüfung SÜ2 · Präsenztage und Remote im Wechsel möglich]
