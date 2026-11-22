// secunet Security Networks — Senior Software Engineer Infrastructure / Linux Security (j3550). Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#0b3d5c"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#0b3d5c")
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
    #text(size: 10pt)[Linux-Infrastruktur · Systemsicherheit · deklarierte Systeme]
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
Ich baue und betreibe Linux-Infrastruktur, deren Sicherheitseigenschaften nachprüfbar sind statt behauptet:
dreizehn Hosts aus einer Deklaration, jede Änderung durch ein Gate, das in CI und auf dem Host identisch ist,
jeder Rückweg ein Zeiger auf die vorige Generation. Firewall-Regeln, Zertifikate und Secrets sind dabei
Konfiguration mit Historie, nicht Handarbeit auf dem Zielsystem. Ich bin US-Staatsbürger mit deutscher
Niederlassungserlaubnis, arbeite auf Deutsch auf C1-Niveau und bin bereit, die Sicherheitsüberprüfung nach
SÜG Stufe 2 zu durchlaufen. Kubernetes und OpenShift habe ich nicht produktiv administriert; die
Grundlagen und der Betrieb darunter sind vorhanden.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump, strace],
  [*Firewall* — nftables als Default-Deny, WireGuard, Portfreigaben als Code],
  [*PKI/TLS* — eigene CA, SSH-CA mit kurzlebigen Zertifikaten, Rotation],
  [*Secrets* — SOPS/age pro Host, Rechte nach dem Minimum, kein Klartext im Repo],
  [*Deklarative Systeme* — gepinnte Inputs, reproduzierbarer Rebuild, Rollback per Generation],
  [*Härtung* — Minimaldienste, Kernel-Parameter, Rechteprüfung, Abhängigkeitsprüfung],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer einheitlichen Task-Oberfläche],
  [*Betrieb* — Ledger alle 15 Minuten, Alerting, Incident-Analyse, Runbooks])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Betreute dreizehn Linux-Hosts deklarativ: gewünschter Zustand im Repository, keine Handarbeit auf dem Zielhost, Rebuild als beschriebener Pfad.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Setzte nftables als Default-Deny mit expliziten Freigaben und WireGuard für Verbindungen zwischen Standorten ein.
- Betrieb eine eigene Zertifizierungsstelle für TLS sowie eine SSH-CA mit kurzlebigen Zertifikaten statt langlebiger Schlüssel.
- Verschlüsselte Secrets pro Host mit SOPS und age und hielt sie außerhalb des Repositories im Klartext.
- Härtete Dienste durch Minimalumfang, Rechteprüfung und Kernel-Parameter; prüfte Abhängigkeiten auf bekannte Schwachstellen.
- Überwachte den Betrieb mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Analysierte Störungen mit journald, cgroups, tcpdump und strace bis zur Ursache und dokumentierte Behebung und Rückweg.
- Isolierte Arbeitslasten über MicroVMs als deklarierte Gäste und systemd-Slices mit Speichergrenzen.
- Baute Schwachstellenberichte als Daten: CISAs KEV-Katalog als Zeitreihe, Exposition nach Behebungsaufwand geclustert.

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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— gehärtete Plattform]
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
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— Schwachstellenlage]
    #linebreak()
    CISAs Katalog bekannter ausgenutzter Schwachstellen als Zeitreihe in reinem SVG, Exposition nach
    Behebungsaufwand geclustert.
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · Bereitschaft zur Sicherheitsüberprüfung SÜG Stufe 2]
