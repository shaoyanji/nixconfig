// SVA — DevOps Consultant Infrastructure Automation. Eigenständige Typst-Quelle.
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
    #text(size: 10pt)[Infrastrukturautomatisierung · Linux · Kundenprojekte]
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
Automatisierung ist für mich die Frage, wie viel Handarbeit ein Betrieb noch duldet. Meine Antwort sind
dreizehn Linux-Hosts aus einer Deklaration, jede Änderung durch ein Gate, das in CI und auf dem Host identisch
ist, jeder Rückweg ein Zeiger auf die vorige Generation — und wiederkehrende Schritte als Go-, Python- oder
Bash-Werkzeug hinter einer Task-Oberfläche, damit auch jemand sie ausführen kann, der das System nicht gebaut
hat. Das habe ich fünf Jahre im eigenen Betrieb umgesetzt und zwei Jahre davor in Mandantenprojekten
kommuniziert. Deutsch C1, Englisch Muttersprache, US-Staatsbürger mit deutscher Niederlassungserlaubnis.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer einheitlichen Task-Oberfläche],
  [*Deklarative Systeme* — gepinnte Inputs, Rebuild statt Reparatur, Rollback],
  [*Linux* — NixOS, systemd, journald, cgroups/PSI, nftables, tcpdump],
  [*Gates* — Prüfung identisch in CI und Host, kein Rollout ohne Check],
  [*Telemetrie* — Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok],
  [*Sicherheit* — SOPS/age, SSH-CA mit kurzlebigen Zertifikaten, Default-Deny],
  [*Kundenarbeit* — Anforderungen aufnehmen, Varianten erklären, Übergabe schreiben],
  [*Werkzeuge* — Git, Taskfiles, Container als gepinnte Bauumgebungen])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Beschrieb dreizehn Linux-Hosts deklarativ, sodass ein Rebuild eine Funktion des Repositories ist und keine Handarbeit am Zielsystem.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash und legte sie hinter eine Task-Oberfläche mit benannten Argumenten und Hilfetext.
- Hielt die Automatisierung selbst wartbar: kleine Werkzeuge mit klarer Schnittstelle statt eines Skripts, das alles tut.
- Isolierte Arbeitslasten über MicroVMs und systemd-Slices mit Speichergrenzen; nutzte Container als gepinnte Bauumgebungen.
- Überwachte den Betrieb mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Härtete Systeme mit nftables als Default-Deny, SOPS/age-verschlüsselten Secrets pro Host und einer SSH-CA mit kurzlebigen Zertifikaten.
- Automatisierte Provisionierung über PXE und iVentoy vom Installer-Start bis zur Erstkonfiguration.
- Übergab Projekte schriftlich: Runbooks, Entscheidungen mit Begründung, Betriebsgrenzen.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften: Arbeitsplätze, Netz, Wi-Fi, Anwendungen.
- Führte Software-Rollouts und Updates durch und dokumentierte sie nachvollziehbar, sodass ein späterer Eingriff nachvollziehbar blieb.
- Führte mobile Felderfassung ein und ersetzte Papierlisten durch strukturierte Daten.
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD: Messdaten, Telemetrie-Abgleich, Abweichungsanalysen.
- Berichtete Anlagenzustand und Abweichungen an Eigentümer und Banken in prüfbarer Form.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie und Risikomanagement — Projektgeschäft mit Terminen beim Kunden.
- Übersetzte technische und kaufmännische Anforderungen in umsetzbare Empfehlungen für Entscheider ohne IT-Hintergrund.
- Betreute eine Projektpipeline über 100 Mio. USD.

#job("Wissenschaftliche Hilfskraft", "Fraunhofer ISE", "März 2012 – Sept. 2012")
- Vermaß Heliostat-Ungenauigkeiten mit Interferometrie und schrieb die C++-Anwendung zur Geräteanbindung.
- Schrieb Python-Werkzeuge für Messdatenanalyse und 3D-Geometrie und wertete die Messreihen statistisch aus.
- Arbeitete in festen Messkampagnen, in denen ein Ergebnis reproduzierbar sein musste, nicht nur plausibel.

#job("Associate Technical Professional", "Halliburton", "Juni 2010 – Sept. 2011")
- Behob Geräte- und Prozessprobleme vor Ort, unter Zeitdruck und ohne zweiten Versuch.
- Leitete die Sicherheitsschulung der Crew.

#section("Ausgewählte Projekte")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Automatisierung als Code]
    #linebreak()
    Ein Flake beschreibt dreizehn Hosts, Dienste, Secrets, Telemetrie und eine Task-Oberfläche; CI und Host
    führen dasselbe Gate aus.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— ein Einstiegspunkt]
    #linebreak()
    Jeder Betriebsschritt hinter einer Kommando-Oberfläche mit Argumenten und Hilfetext, damit Kollegen sie ohne
    Quellcode-Kenntnis ausführen.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Telemetrie]
    #linebreak()
    Ein Ledger prüft Jobstatus, Generation Age, Disk-Druck und PSI und meldet jeden Zustand ungleich ok.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— Datenpipeline]
    #linebreak()
    CISAs Katalog ausgenutzter Schwachstellen als bereinigte Zeitreihe, Exposition nach Behebungsaufwand.
  ],
  [
    #text(weight: "bold")[netboot] #text(size: 8pt, fill: muted)[— Bare Metal]
    #linebreak()
    PXE und iVentoy liefern Installer und Erstkonfiguration; eine Maschine tritt der deklarierten Flotte bei,
    statt zusammengebaut zu werden.
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
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · 25 km bis Freiburg, Präsenz vor Ort möglich]
