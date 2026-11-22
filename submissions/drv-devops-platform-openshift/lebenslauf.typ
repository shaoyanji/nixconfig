// Deutsche Rentenversicherung Bund — DevOps Platform Engineer OpenShift. Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#1d3f6e"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1d3f6e")
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
    #text(size: 10pt)[Plattformbetrieb · Automatisierung · souveräne KI-Infrastruktur]
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
Ich betreibe Plattformen, deren Zustand aus einer Deklaration entsteht und deren Änderungen durch ein Gate
gehen: dreizehn Linux-Hosts aus einem Repository, identische Prüfung in CI und auf dem Host, Rollback als
Zeiger auf die vorige Generation. Dazu betreibe ich eine lokale Inferenz-Plattform — Modelle, Routing,
Auslastungsschutz — auf eigener Hardware, weil ich wissen will, wo Daten liegen, bevor ich eine API
dafür bezahle. OpenShift und Kubernetes habe ich nicht produktiv administriert; was ich mitbringe, ist die
Schicht darunter und die Arbeitsweise darüber: Linux, Netzwerk, Zertifikate, Gates, Selbstbedienung für
Entwicklungsteams. TechnoCampus Spandau ist von Gutach rund 700 Kilometer entfernt — für Präsenzblöcke
bin ich bereit, für tägliches Pendeln nicht.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, nftables, tcpdump],
  [*Plattform as Code* — deklarierter Zustand, gepinnte Inputs, reproduzierbarer Rebuild],
  [*Selbstbedienung* — Task-Oberfläche für Betriebsschritte, Runbooks, klare Verträge],
  [*Souveräne KI* — lokale Modelle auf eigener GPU, Routing, On-Demand-Betrieb, Gaming-Guard],
  [*Container* — gepinnte Bauumgebungen, MicroVMs als deklarierte Gäste; kein K8s-Betrieb],
  [*Gates* — identische Prüfung in CI und Host, kein Rollout ohne Check, Rollback per Generation],
  [*Sicherheit* — SOPS/age, SSH-CA mit kurzlebigen Zertifikaten, Default-Deny, Minimalrechte],
  [*Betrieb* — Ledger alle 15 Minuten, Alerting, Incident-Analyse, Wartungsfenster mit Rückweg])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Betreute dreizehn Linux-Hosts deklarativ: gewünschter Zustand im Repository, keine Handarbeit auf dem Zielhost, Rebuild als beschriebener Pfad.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Baute eine einheitliche Task-Oberfläche, über die Dritte Betriebsschritte ausführen konnten, ohne den Aufbau zu kennen.
- Betrieb eine lokale Inferenz-Plattform auf eigener Hardware: mehrere Modelle hinter einem Router, On-Demand-Start, Auslastungsschutz, damit schwere Jobs und interaktive Anfragen sich nicht verdrängen.
- Isolierte Arbeitslasten über MicroVMs als deklarierte Gäste und systemd-Slices mit Speichergrenzen.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash.
- Überwachte den Betrieb mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Härtete Zugänge mit SOPS/age, einer SSH-CA mit kurzlebigen Zertifikaten und nftables als Default-Deny.
- Dokumentierte Betriebswissen in Runbooks und einem Repository, das als Übergabe ohne Rückfrage funktioniert.

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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Plattform as Code]
    #linebreak()
    Ein Flake beschreibt dreizehn NixOS-Hosts, nginx mit TLS, eine SSH-CA, SOPS-Secrets und eine
    Task-Oberfläche; CI und Host führen dasselbe Modul-Gate aus.
  ],
  [
    #text(weight: "bold")[eisen] #text(size: 8pt, fill: muted)[— souveräne Inferenz]
    #linebreak()
    Lokale Modelle auf eigener GPU: OpenAI-kompatible Endpunkte, Sprach- und Bildpfade, Router und
    Auslastungsschutz, damit kein Prompt das Haus verlässt.
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
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Erneuerbare-Energien-Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis · Bereitschaft zu Präsenzblöcken in Berlin-Spandau]
