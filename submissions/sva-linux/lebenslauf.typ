// SVA — DevOps Engineer / Consultant Linux (j734). Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#7a1f2b"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#7a1f2b")
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
    #text(size: 10pt)[Enterprise Linux · Automatisierung · Kundenprojekte]
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
Ich administriere Enterprise Linux seit über zehn Jahren und beschreibe es lieber, als es zu reparieren:
dreizehn Hosts aus einer Deklaration, jede Änderung durch ein Gate, das in CI und auf dem Host identisch ist,
jeder Rückweg ein Zeiger auf die vorige Generation. Dazu kommen Netzwerk und Härtung aus der Praxis —
nftables als Default-Deny, WireGuard, eigene CA, Secrets pro Host verschlüsselt — und eine Telemetrie, die
alle fünfzehn Minuten prüft, statt auf eine Meldung zu warten. Beratung ist mir vertraut: zwei Jahre
Mandantenprojekte, davor IT-Verantwortung für ein Unternehmen mit Tochtergesellschaften. Ich wohne 25
Kilometer von der Freiburger Geschäftsstelle entfernt.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Enterprise Linux* — NixOS, RHEL-Denke, systemd, journald, cgroups/PSI, tcpdump],
  [*Automatisierung* — deklarierter Zustand, gepinnte Inputs, Rebuild statt Reparatur],
  [*Telemetrie* — Ledger alle 15 Minuten, Alerting, Kapazitäts- und Lastblick],
  [*Netzwerk* — nftables Default-Deny, WireGuard, DNS-Zone, TLS/PKI, MTU-Analyse],
  [*Sicherheit* — SOPS/age pro Host, SSH-CA mit kurzlebigen Zertifikaten, Minimalrechte],
  [*Kundenarbeit* — Anforderungen aufnehmen, Variante erklären, Übergabe dokumentieren],
  [*Werkzeuge* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Dokumentation* — Runbooks, Entscheidungen mit Begründung, prüfbares Betriebswissen])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Administrierte dreizehn Linux-Hosts deklarativ: Installation, Updates, Sicherheitspatches, Rebuild, Außerbetriebnahme.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Betrieb zentrale Dienste für Kunden und eigene Projekte: nginx mit TLS, Datenbank, DNS, Mail-Weiterleitung.
- Setzte nftables als Default-Deny mit expliziten Freigaben und WireGuard für Verbindungen zwischen Standorten ein.
- Überwachte Systeme mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Analysierte Störungen mit journald, cgroups, tcpdump und strace bis zur Ursache und dokumentierte Behebung und Rückweg.
- Isolierte Arbeitslasten über MicroVMs und systemd-Slices mit Speichergrenzen.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash hinter einer einheitlichen Oberfläche.
- Übergab Projekte schriftlich: Runbooks, Architekturentscheidungen, Betriebsgrenzen.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften: Arbeitsplätze, Netz, Wi-Fi, Anwendungen.
- Verantwortete Software-Rollouts, Updates und Anwenderbetreuung für Techniker und Büro.
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie und Risikomanagement — Projektgeschäft mit Terminen beim Kunden.
- Übersetzte technische und kaufmännische Anforderungen in umsetzbare Empfehlungen.
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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Plattform as Code]
    #linebreak()
    Ein Flake beschreibt dreizehn NixOS-Hosts, nginx mit TLS, eine SSH-CA, SOPS-Secrets, Telemetrie und
    eine Task-Oberfläche; CI und Host führen dasselbe Gate aus.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Betriebsblick]
    #linebreak()
    Ein Ledger prüft Jobstatus, Generation Age, Disk-Druck und PSI und meldet jeden Zustand ungleich ok.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go-Dienst]
    #linebreak()
    Unveränderliche, inhaltsadressierte Spezifikation aus einer Anfrage: append-only Events und
    Terminal-Oberfläche aus einem Binary, gespeichert in PostgreSQL.
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · 25 km bis Freiburg, Präsenz vor Ort möglich]
