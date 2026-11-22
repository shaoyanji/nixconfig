// shopware AG — Cloud Infrastructure Engineer – AWS (m/w/d). Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#14456b"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#14456b")
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
    #text(size: 10pt)[Linux- und Cloud-Infrastruktur · deklarativ betrieben]
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
Ich betreibe Infrastruktur als Deklaration: dreizehn Linux-Hosts aus einem Repository, jede Maschine zieht
ihren Zustand von dort, jede Änderung läuft durch ein Gate, das in CI und auf dem Host identisch ist, und
der Rückweg ist ein Zeiger auf die vorige Generation. Netzwerk ist für mich Handwerk — WireGuard,
nftables, DNS, MTU, tcpdump — und Monitoring eine Aufzeichnung statt eines Dashboards. Fünf Jahre
vollständig ortsunabhängig gearbeitet, mit schriftlicher Übergabe statt Zuruf. Was ich nicht mitbringe:
AWS-Architektur, Terraform und Prometheus/Grafana. Das steht im Anschreiben, bevor es im Gespräch steht.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump],
  [*IaC* — deklarative Module, gepinnte Inputs, Gate vor Rollout, Rollback per Generation],
  [*Netzwerk* — WireGuard, nftables Default-Deny, eigene DNS-Zone, TLS/PKI, MTU-Analyse],
  [*Monitoring* — Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok, Log-Analyse],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Kosten* — ARM statt x86, MicroVMs, Build-Cache als Entwurfsbedingung],
  [*Sicherheit* — SOPS/age, kurzlebige SSH-Zertifikate, Minimalrechte, KEV-Daten],
  [*Remote* — fünf Jahre verteiltes Arbeiten, Dokumentation als Übergabeformat])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Betreute dreizehn Linux-Hosts deklarativ: gewünschter Zustand im Repository, keine Handarbeit auf dem Zielhost, Rebuild als beschriebener Pfad.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Automatisierte die Infrastruktur mit Modulen und gepinnten Inputs — dieselbe Rolle, die Terraform in einer AWS-Umgebung einnimmt, nur mit anderen Werkzeugen.
- Gestaltete und betrieb das Netzwerk: WireGuard zwischen Hosts, nftables als Default-Deny, eigene DNS-Zone, MTU- und Path-Fehler mit tcpdump gefunden.
- Überwachte den Zustand mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Bereitete Betriebs- und Kostendaten als Reports auf: wo eine Instanz zu groß ist, welcher Dienst zu viel Speicher hält, welche Grenze zu eng sitzt.
- Evaluierte und führte Open-Source-Lösungen ein: nginx, WireGuard, nftables, PostgreSQL, jeweils mit Betriebs- und Rückwegkonzept.
- Härtete Systeme: SOPS/age-Secrets pro Host, TLS aus eigener CA, kurzlebige SSH-Zertifikate, Rechte nach dem Minimum.
- Schrieb Go-, Python- und Bash-Werkzeuge hinter einer Task-Schnittstelle, inklusive Go-Diensten mit PostgreSQL.
- Arbeitete fünf Jahre vollständig ortsunabhängig und dokumentierte so, dass Übergabe ohne Rückfrage möglich war.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften: Arbeitsplätze, Netz, Wi-Fi, Anwendungen.
- Unterstützte Feldtechniker und Büro direkt, mit Einweisung statt Ticket-Weiterleitung.
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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Infrastruktur als Code]
    #linebreak()
    Ein Flake beschreibt dreizehn NixOS-Hosts, nginx mit TLS, eine SSH-CA, SOPS-Secrets und eine
    Task-Oberfläche; CI und Host führen dasselbe Modul-Gate aus.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go-Dienst]
    #linebreak()
    Unveränderliche, inhaltsadressierte Spezifikation aus einer Anfrage: append-only Events und
    Terminal-Oberfläche aus einem Binary, gespeichert in PostgreSQL.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— Betriebsreporting]
    #linebreak()
    CISAs Katalog bekannter ausgenutzter Schwachstellen als Zeitreihe in reinem SVG, Exposition nach
    Behebungsaufwand geclustert.
  ],
  [
    #text(weight: "bold")[risk-calc] #text(size: 8pt, fill: muted)[— Go und Pipelines]
    #linebreak()
    Satz von Green auf stochastische Polygone: ein Go-Fuzzer erzeugt Formen, eine Pipeline aus Nushell
    und Awk treibt die Berechnung.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Erneuerbare-Energien-Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis · Umzug nicht erforderlich, Stelle ist remote]
