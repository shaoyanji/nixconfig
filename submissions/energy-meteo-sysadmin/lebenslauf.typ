// energy & meteo systems — Systemadministrator:in. Eigenständige Typst-Quelle, kein JSON.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#14532d"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#14532d")
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
    #text(size: 10pt)[Linux-Systemadministration · Erneuerbare Energien]
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
Ich administriere Linux-Systeme seit über zehn Jahren und habe dabei nie nur administriert: Wo eine
Aufgabe wiederkehrte, wurde sie automatisiert, dokumentiert und geprüft. Dreizehn Hosts laufen aus einer
Deklaration im Repository, Updates und Sicherheitspatches gehen durch ein Gate, und Monitoring ist eine
Aufzeichnung statt eines Dashboards. Fachlich komme ich aus der erneuerbaren Energie: Master in
Erneuerbare-Energien-Management in Freiburg (Note 1,8), Solarforschung am Fraunhofer ISE, danach
Asset-Management von 10 MW PV. Dass Sie Wind- und Solarprognosen liefern, ist deshalb kein Zufallstreffer,
sondern die Schnittmenge, in der ich arbeiten will.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, Debian-artige Systeme, systemd, cgroups/PSI, journald],
  [*Support* — 1st/2nd Level für Techniker und Büro, Einweisung statt Ticketweiterleitung],
  [*Automatisierung* — Python, Go, Bash, Nix; wiederkehrende Schritte als Skript],
  [*Monitoring* — Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok, Log-Analyse],
  [*Sicherheit* — Patch- und Update-Tests, Default-Deny, SOPS/age, Minimalrechte],
  [*Lifecycle* — Bare-Metal-Provisionierung über PXE, Erstkonfiguration, Rebuild],
  [*Dokumentation* — Runbooks, Änderungen mit Rückweg, Wissen im Repository],
  [*Energie* — PV-Asset-Management, Wetter- und Ertragsdaten, Prognosegüte])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Administrierte dreizehn Linux-Hosts: Installation, Updates, Sicherheitspatches, Rebuild, alles aus einer Deklaration statt per Handarbeit.
- Testete Updates vor dem Ausrollen in einem Gate; eine fehlgeschlagene Prüfung lässt die vorige Generation laufen, der Rückweg ist ein Zeigerwechsel.
- Überwachte die Systemlandschaft mit einem Ledger alle fünfzehn Minuten: Jobstatus, Generation Age, Disk-Druck und PSI, Meldung auf jeden Zustand ungleich ok.
- Analysierte Störungen mit journald, cgroups und tcpdump und dokumentierte Ursache und Behebung, damit der nächste Fall schneller geht.
- Evaluierte und führte Open-Source-Lösungen ein: nginx, WireGuard, nftables, PostgreSQL; jeweils mit Betriebs-, Update- und Rückwegkonzept.
- Automatisierte wiederkehrende Aufgaben in Python, Go und Bash und stellte sie hinter eine einheitliche Kommando-Oberfläche.
- Verwaltete Hardware-Lebenszyklen von der Provisionierung über PXE und iVentoy bis zur Außerbetriebnahme.
- Härtete Systeme: SOPS/age-verschlüsselte Secrets, kurzlebige SSH-Zertifikate, nftables als Default-Deny, Rechte nach dem Minimum.
- Dokumentierte Betriebswissen so, dass es prüfbar bleibt: Runbooks, Budgets für Dokumentationslänge, ein Gate für Sprache.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften: Arbeitsplätze, Netz, Wi-Fi, Anwendungen.
- War direkter Ansprechpartner für Feldtechniker und Büro, mit Einweisung und Geduld statt Ticket-Weiterleitung.
- Führte Software-Rollouts und Updates auf Client-Systeme durch und dokumentierte sie.
- Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen in einem Portfolio über 100 Mio. USD.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie, Risikomanagement und Cybersecurity-Software.
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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Systemlandschaft]
    #linebreak()
    Ein Flake beschreibt dreizehn NixOS-Hosts, nginx mit TLS, eine SSH-CA, SOPS-Secrets und eine
    Task-Oberfläche; CI und Host führen dasselbe Modul-Gate aus.
  ],
  [
    #text(weight: "bold")[Masterarbeit] #text(size: 8pt, fill: muted)[— Wetter und Prognose]
    #linebreak()
    Zeit-Kreuzkorrelation von Windgeschwindigkeit und neuronale Netze auf Langzeit-Wetterdaten, publiziert
    über die Universität Freiburg.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— Schwachstellenbericht]
    #linebreak()
    CISAs Katalog bekannter ausgenutzter Schwachstellen als Zeitreihe in reinem SVG, Exposition nach
    Behebungsaufwand geclustert.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go-Dienst]
    #linebreak()
    Unveränderliche, inhaltsadressierte Spezifikation aus einer Anfrage: append-only Events und
    Terminal-Oberfläche aus einem Binary, gespeichert in PostgreSQL.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Erneuerbare-Energien-Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(size: 8pt, fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis · Home-Office erprobt]
