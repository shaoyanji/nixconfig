// Mittwald CM Service — DevOps Engineer (m/w/d). Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#1f3a8a"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1f3a8a")
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
    #text(size: 10pt)[Linux- und Plattformbetrieb · Bare Metal bis Rollback]
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
Ich betreibe Hosting-Infrastruktur, seit es noch keine Cloud dafür gab: dreizehn Linux-Hosts auf eigener
und gemieteter Hardware, provisioniert über PXE, deklariert in einem Repository, jede Änderung durch ein
Gate, jeder Rückweg ein Zeiger auf die vorige Generation. Ich kenne den Unterschied zwischen einem Dienst,
der läuft, und einem Dienst, dessen Zustand ich belegen kann — deshalb schreibe ich Telemetrie in ein
Ledger statt in ein Dashboard. Go, Python und Bash sind meine Werkzeuge, wenn eine Handbewegung zum
zweiten Mal nötig wird. Was ich nicht mitbringe: Kubernetes und Helm im Betrieb. Ihre Anzeige sagt, dass
Sie das beibringen — darauf bewerbe ich mich, nicht auf eine Rolle, die ich schon kann.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, nftables, tcpdump],
  [*Hosting* — Web-Dienste hinter nginx mit TLS, Reverse Proxy, Zertifikaten aus eigener CA],
  [*Bare Metal* — PXE/iVentoy-Provisionierung, Erstkonfiguration, Rebuild, Außerbetriebnahme],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Telemetrie* — Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok, Incident-Notizen],
  [*Betrieb* — Wartungsfenster mit Rückweg, Runbooks, dokumentierte Änderungen],
  [*Sicherheit* — SOPS/age, kurzlebige SSH-Zertifikate, Default-Deny, Minimalrechte],
  [*Skalierung* — Instanzen als deklarierte Funktion, nicht als Handarbeit pro Maschine])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Betreute dreizehn Linux-Hosts als Hosting-Plattform: Provisionierung über PXE und iVentoy, Erstkonfiguration, Rebuild, keine Handarbeit auf dem Zielhost.
- Stellte Web-Dienste hinter nginx bereit, mit TLS, Reverse Proxy und Zertifikaten aus einer eigenen Zertifizierungsstelle mit kurzlebigen Zertifikaten.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Überwachte die Plattform mit einem Ledger alle fünfzehn Minuten: Jobstatus, Generation Age, Disk-Druck und PSI, Meldung auf jeden Zustand ungleich ok.
- Analysierte Störungen mit journald, cgroups und tcpdump und dokumentierte Ursache und Behebung, damit der nächste Fall kürzer ist.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash, darunter Go-Dienste mit PostgreSQL und append-only Ereignisprotokoll.
- Optimierte Ressourcen unter Grenzen: systemd-Slices mit Speicherlimits, cgroups, PSI als Lastsignal, ARM-Boards und MicroVMs auf knappem Speicher.
- Nutzte Caching als Betriebsmittel: Build-Cache und Store-Substitution, damit ein Rebuild nicht jedes Paket neu übersetzt.
- Härtete Zugänge: SOPS/age-verschlüsselte Secrets pro Host, SSH-CA mit kurzlebigen Zertifikaten, nftables Default-Deny, Rechte nach dem Minimum.
- Dokumentierte Betriebswissen in Runbooks und einem Repository, das als Übergabe funktioniert.

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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Plattform]
    #linebreak()
    Ein Flake beschreibt dreizehn NixOS-Hosts, nginx-Vhosts mit TLS, eine SSH-CA, SOPS-Secrets und eine
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
    #text(weight: "bold")[Masterarbeit] #text(size: 8pt, fill: muted)[— Wetter und Prognose]
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis · Bereitschaft zu Präsenz in Espelkamp]
