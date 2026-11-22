// citeq — DevOps Engineer (m/w/d), Stadt Münster. Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#8a2f1d"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#8a2f1d")
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
    #text(size: 10pt)[Linux-Plattformen · Webhosting · souveräner Betrieb]
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
Ich betreibe Web- und Systemplattformen, deren Zustand aus einer Deklaration entsteht: dreizehn Linux-Hosts
aus einem Repository, nginx mit TLS, jede Änderung durch ein Gate, das in CI und auf dem Host identisch ist,
Rollback als Zeiger auf die vorige Generation. Für kommunale IT zählt dabei nicht nur, dass es läuft, sondern
dass der Betrieb erklärbar bleibt — wer geändert hat, mit welcher Begründung, und wie man zurückkommt. Genau
so habe ich fünf Jahre gearbeitet. Deutsch C1, Englisch Muttersprache, US-Staatsbürger mit deutscher
Niederlassungserlaubnis.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, journald, cgroups/PSI, tcpdump, strace],
  [*Webhosting* — nginx, TLS mit eigener CA, virtuelle Hosts, Logauswertung],
  [*Deklarativer Betrieb* — gepinnte Inputs, Rebuild statt Reparatur, Generation-Rollback],
  [*Container* — gepinnte Bauumgebungen, MicroVMs als Gäste, Slices mit Grenzen],
  [*Sicherheit* — nftables Default-Deny, SOPS/age, SSH-CA, Minimalrechte],
  [*Netzwerk* — WireGuard, eigene DNS-Zone, MTU-Analyse, PKI],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Dokumentation* — Runbooks, Änderungsnotizen, prüfbares Betriebswissen])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Betreute dreizehn Linux-Hosts deklarativ: gewünschter Zustand im Repository, keine Handarbeit auf dem Zielhost, Rebuild als beschriebener Pfad.
- Betrieb Webdienste mit nginx, TLS über eine eigene Zertifizierungsstelle und getrennten virtuellen Hosts pro Dienst.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Härtete den Betrieb mit nftables als Default-Deny, SOPS/age-verschlüsselten Secrets pro Host und einer SSH-CA mit kurzlebigen Zertifikaten.
- Überwachte Dienste mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Nutzte Container als gepinnte Bauumgebungen und MicroVMs als deklarierte Gäste, um Lasten zu trennen.
- Analysierte Störungen mit journald, cgroups und tcpdump und dokumentierte Ursache und Rückweg.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash hinter einer Task-Oberfläche.
- Dokumentierte Betriebswissen so, dass Dritte es ohne Rückfrage nutzen konnten.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften: Arbeitsplätze, Netz, Wi-Fi, Anwendungen.
- Unterstützte Anwender direkt, mit Einweisung statt Ticket-Weiterleitung.
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie und Risikomanagement.
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
    Ein Ledger prüft alle fünfzehn Minuten Jobstatus, Generation Age, Disk-Druck und PSI und meldet
    jeden Zustand ungleich ok.
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · Umzug nach Münster eingeplant]
