// STACKIT / Schwarz Digits — Infrastructure as Code / Terraform Platform Engineer. Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#0d3b66"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#0d3b66")
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
    #text(size: 10pt)[Infrastructure as Code · Linux-Plattformen · Automatisierung]
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
Infrastructure as Code heißt für mich nicht, Ressourcen aufzuschreiben, sondern einen Zustand zu
beschreiben, der überprüfbar ist: dreizehn Linux-Hosts aus einer Deklaration, gepinnte Inputs, jede Änderung
durch ein Gate, das in CI und auf dem Host identisch ist, jeder Rückweg ein Zeiger auf die vorige Generation.
Ich habe diese Arbeitsweise fünf Jahre lang in Nix betrieben — deklarativ, reproduzierbar, mit Rollback — und
kenne die Fragen, die dabei entstehen: was ist der wahre Zustand, was driftet, was passiert beim zweiten Lauf.
Terraform, Ansible und helm habe ich nicht produktiv eingesetzt, Kubernetes nicht als Administrator betreut;
die Denkweise, der Plan-vor-Apply-Zwang und die Ablehnung von Handarbeit sind dieselben. Deutsch C1, Englisch
Muttersprache, US-Staatsbürger mit deutscher Niederlassungserlaubnis.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*IaC* — deklarierter Zustand, gepinnte Inputs, Plan vor Apply, Rebuild statt Reparatur],
  [*Container* — gepinnte Bauumgebungen, MicroVMs als Gäste; kein K8s-Betrieb],
  [*Linux* — NixOS, systemd, journald, cgroups/PSI, nftables, tcpdump],
  [*Automatisierung* — Go, Python, Bash hinter einer einheitlichen Task-Oberfläche],
  [*Gates* — Prüfung identisch in CI und Host, kein Rollout ohne Check],
  [*Telemetrie* — Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok],
  [*Sicherheit* — SOPS/age pro Host, SSH-CA mit kurzlebigen Zertifikaten, Default-Deny],
  [*Netzwerk* — WireGuard, eigene DNS-Zone, TLS/PKI, MTU-Analyse],
  [*Dokumentation* — Runbooks, Entscheidungen mit Begründung, prüfbares Betriebswissen])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Beschrieb dreizehn Linux-Hosts in einem Repository; die Maschine entsteht durch Anwendung der Deklaration, nicht durch Handarbeit.
- Pinnte jeden Input und jeden Host-Untermodul-Stand, sodass ein Rebuild eine Funktion des Repositories ist und nicht des Tages.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Hielt Drift klein, indem Abweichungen nicht geduldet, sondern als Fehler behandelt und über die Deklaration behoben wurden.
- Automatisierte Provisionierung über PXE und iVentoy vom Installer-Start bis zur Erstkonfiguration.
- Überwachte den Betrieb mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Härtete Systeme mit nftables als Default-Deny, SOPS/age-verschlüsselten Secrets pro Host und einer SSH-CA mit kurzlebigen Zertifikaten.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash hinter einer Task-Oberfläche, die auch Dritte nutzen konnten.
- Dokumentierte Architekturentscheidungen und Betriebswissen so, dass eine Übergabe ohne Rückfrage möglich war.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD: Messdaten, Telemetrie-Abgleich, Abweichungsanalysen.
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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Plattform als Deklaration]
    #linebreak()
    Ein Flake beschreibt dreizehn Hosts, Dienste, Secrets, Telemetrie und eine Task-Oberfläche; CI und Host
    führen dasselbe Gate aus.
  ],
  [
    #text(weight: "bold")[netboot] #text(size: 8pt, fill: muted)[— Bare Metal als Code]
    #linebreak()
    PXE und iVentoy liefern Installer und Erstkonfiguration; eine Maschine tritt der deklarierten Flotte bei,
    statt zusammengebaut zu werden.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Drift sichtbar machen]
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · wohnhaft in Baden-Württemberg]
