// VertiGIS — Cloud Engineer (m/w/x), Cloud-Betrieb von SaaS-Lösungen. Eigenständiges Typst.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.45em)
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
    #text(size: 10pt)[Linux- und Cloud-Betriebsingenieur]
  ],
  [
    #align(right)[
      #text(size: 8pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
      #linebreak()
      #text(size: 8pt)[matt\@bountystash.com · github.com/shaoyanji · bountystash.com]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profil")
Zehn Jahre Betrieb und Software. Ich halte dreizehn Linux-Hosts in einer Deklaration: gewünschter Zustand
im Repository, jede Maschine zieht ihn von dort, jede Änderung läuft durch ein Gate in CI und auf dem Host,
und der Rückweg ist ein Zeiger auf die vorige Generation. Betrieb heißt bei mir messen statt behaupten:
ein Ledger alle fünfzehn Minuten, journald, PSI, Meldung auf jeden Zustand ungleich ok. Dazu Automatisierung
in Go, Python, Bash und Nix, Netzwerk als Handwerk und Sicherheit als Voreinstellung statt Nachrüstung.
Azure und Bicep habe ich nicht betrieben; das steht hier vor dem ersten Gespräch, nicht danach.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump],
  [*Automatisierung* — Deklaration, Gates, Go, Python, Bash],
  [*Betrieb* — Monitoring als Ledger, Alerting, Log-Analyse, Runbooks],
  [*Netzwerk* — WireGuard, nftables, DNS, MTU, TLS/PKI],
  [*Sicherheit* — Default-Deny, SOPS/age, Minimalrechte, KEV-Daten],
  [*Bare Metal* — PXE/iVentoy, Erstkonfiguration, Rebuild],
  [*Cloud* — Oracle-Cloud-Hosts, ein Lambda-Projekt; Azure nicht betrieben],
  [*Daten* — PostgreSQL, append-only Events, REST])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Hielt dreizehn Linux-Hosts in einer Deklaration; keine Handarbeit auf dem Zielhost, ein Rebuild ist ein beschriebener Pfad.
- Führte jede Änderung durch ein Gate, das in der CI und auf dem Host läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen, Rollback ist ein Zeigerwechsel.
- Betrieb Monitoring als Aufzeichnung: Jobstatus, Generation Age, Disk-Druck und PSI alle fünfzehn Minuten, Meldung auf jeden Zustand ungleich ok.
- Analysierte Störungen mit journald, cgroups und tcpdump über Host-, Unit- und Zeitgrenzen hinweg und schrieb Ursache und Behebung auf.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash hinter einer Task-Schnittstelle, darunter Go-Dienste mit PostgreSQL.
- Provisionierte Bare Metal über PXE und iVentoy bis zur Erstkonfiguration und zum Rebuild.
- Betrieb das Netzwerk als Code: WireGuard zwischen den Hosts, nftables als Default-Deny, eigene DNS-Zone, MTU-Fehler mit tcpdump gefunden statt geraten.
- Härtete Zugänge: SOPS/age-verschlüsselte Secrets pro Host, SSH-CA mit kurzlebigen Zertifikaten, TLS aus eigener Zertifizierungsstelle, Rechte nach dem Minimum.
- Machte Kosten zur Entwurfsbedingung: ARM statt x86, MicroVMs statt VMs, Build-Cache statt Neuübersetzung.
- Baute Schwachstellenberichte als Daten: CISA-KEV als Zeitreihe, Exposition nach Behebungsaufwand geclustert.
- Betrieb Web-Dienste hinter nginx mit TLS, Reverse Proxy und Zertifikaten aus einer eigenen Zertifizierungsstelle; plante Wartungsfenster so, dass ein Rückweg immer existiert.
- Entwickelte einen Algorithmus für Optionshandel und Hedging auf Wetterderivaten und beriet Mandanten als interner Risk Manager.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften, inklusive Arbeitsplätzen, Netz und Wi-Fi.
- Unterstützte Feldtechniker und Büro direkt, mit Einweisung statt Ticket-Weiterleitung.
- Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen in einem Portfolio über 100 Mio. USD.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energie strategie, Cybersecurity-Software und Risikomanagement.
- Betreute eine Projektpipeline über 100 Mio. USD.

#job("Wissenschaftliche Hilfskraft", "Fraunhofer ISE", "März 2012 – Sept. 2012")
- Vermaß Heliostat-Ungenauigkeiten mit Interferometrie und schrieb die C++-Anwendung zur Geräteanbindung.
- Schrieb Python-Werkzeuge für Analyse und 3D-Geometrie.

#job("Associate Technical Professional", "Halliburton", "Juni 2010 – Sept. 2011")
- Leitete zwei Frac-Crews mit über 3 Mio. USD Auftragsvolumen pro Woche und verantwortete die Sicherheitsschulung der Crew.
- Behob Chemikalien- und Geräteprobleme vor Ort, unter Zeitdruck und ohne zweiten Versuch.

#section("Ausgewählte Projekte")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— deklarierte Flotte]
    #linebreak()
    Ein Flake deklariert dreizehn NixOS-Hosts, nginx-Vhosts mit TLS, eine SSH-CA, SOPS-Secrets und eine
    Task-Oberfläche; CI und Host führen dasselbe Modul-Gate aus.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go-Dienst]
    #linebreak()
    Aus einer Anfrage wird eine unveränderliche, inhaltsadressierte Spezifikation: append-only Events,
    Terminal-Oberfläche und curl-Endpunkte aus einem Binary, persistiert in PostgreSQL.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— Betriebsdaten]
    #linebreak()
    CISAs Katalog bekannter ausgenutzter Schwachstellen als Zeitreihe in reinem SVG, Exposition nach
    Aufwand geclustert.
  ],
  [
    #text(weight: "bold")[Masterarbeit] #text(size: 8pt, fill: muted)[— Wetter und Volatilität]
    #linebreak()
    Zeit-Kreuzkorrelation von Windgeschwindigkeit und neuronale Netze auf Langzeit-Wetterdaten.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Erneuerbare-Energien-Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · 1,8/5,0]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.6pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis · kein Sponsoring nötig]
