// True Talent Solutions Partners — Senior System Administrator, Freiburg. Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#1f5c3a"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1f5c3a")
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
    #text(size: 10pt)[Linux-Systemadministration · Bare Metal · Sicherheit]
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
Ich administriere Linux seit über zehn Jahren und betreibe dabei Hardware, die ich selbst in Betrieb nehme:
Server provisioniert über PXE, Zustand in einem Repository, jede Änderung durch ein Gate, jeder Rückweg ein
Zeiger auf die vorige Generation. Sicherheit ist bei mir Voreinstellung statt Projekt: Default-Deny,
verschlüsselte Secrets pro Host, kurzlebige Zertifikate, Rechte nach dem Minimum. Ich arbeite 20 Kilometer
von Freiburg entfernt und suche bewusst eine Rolle vor Ort. Was ich nicht mitbringe: Proxmox und Ceph habe
ich nicht administriert, Windows und Microsoft 365 nicht betreut, und eine ISO-27001- oder C5-Zertifizierung
nicht begleitet. Das steht im Anschreiben, bevor es im Gespräch steht.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, Debian-artig, systemd, cgroups/PSI, journald, nftables],
  [*Bare Metal* — PXE/iVentoy-Provisionierung, Erstkonfiguration, Rebuild, Außerbetriebnahme],
  [*Virtualisierung* — MicroVMs als deklarierte Gäste, Slices mit Grenzen; Proxmox nicht administriert],
  [*Netzwerk* — WireGuard, nftables Default-Deny, eigene DNS-Zone, MTU-Analyse, TLS/PKI],
  [*Sicherheit* — SOPS/age, SSH-CA mit kurzlebigen Zertifikaten, Minimalrechte, KEV-Daten],
  [*Monitoring* — Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok, Log-Analyse],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Dokumentation* — Runbooks, Änderungen mit Rückweg, prüfbares Betriebswissen])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Administrierte dreizehn Linux-Hosts: Installation, Updates, Sicherheitspatches, Rebuild, Provisionierung über PXE und iVentoy.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Überwachte Systeme und Dienste mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Analysierte Störungen mit journald, cgroups und tcpdump über Host-, Unit- und Zeitgrenzen und dokumentierte Ursache und Behebung.
- Isolierte Arbeitslasten über MicroVMs und systemd-Slices mit Speichergrenzen; betrieb Dienste auf knappem Speicher auf ARM-Boards.
- Härtete Systeme: SOPS/age-verschlüsselte Secrets pro Host, SSH-CA mit kurzlebigen Zertifikaten, nftables Default-Deny, Rechte nach dem Minimum.
- Verwaltete Hardware-Lebenszyklen von der Beschaffung über die Inbetriebnahme bis zur Außerbetriebnahme.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash hinter einer Task-Oberfläche.
- Dokumentierte Betriebswissen in Runbooks und einem Repository, das als Übergabe ohne Rückfrage funktioniert.
- Baute Schwachstellenberichte als Daten: CISA-KEV als Zeitreihe, Exposition nach Behebungsaufwand geclustert.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften: Arbeitsplätze, Netz, Wi-Fi, Anwendungen.
- Unterstützte Feldtechniker und Büro direkt, mit Einweisung statt Ticket-Weiterleitung.
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis · wohnhaft 20 km von Freiburg, Präsenz vor Ort möglich]
