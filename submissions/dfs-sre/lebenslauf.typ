// DFS Deutsche Flugsicherung — Ingenieur Site Reliability. Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#12365c"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#12365c")
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
    #text(size: 10pt)[Site Reliability · Telemetrie · deklarierte Systeme]
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
Ich betreibe Systeme so, dass ihr Zustand messbar ist und ein Ausfall nicht interpretiert werden muss: dreizehn
Linux-Hosts aus einer Deklaration, eine Prüfung alle fünfzehn Minuten, jede Änderung durch ein Gate, jeder
Rückweg ein Zeiger auf die vorige Generation. In einer Umgebung, in der ein Ausfall nicht nur Geld kostet,
zählt nicht die schnelle Reparatur, sondern dass die Ursache belegt ist, bevor jemand eine Geschichte dazu
erzählt. Genau dafür habe ich Telemetrie, Fehlersuche und Wiederherstellung gebaut. Ich bin bereit,
Sicherheitsüberprüfung und Tauglichkeitsuntersuchung zu durchlaufen; US-Staatsbürger mit deutscher
Niederlassungserlaubnis.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, journald, cgroups/PSI, tcpdump, strace],
  [*Telemetrie* — Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok, Zeitreihen],
  [*Verfügbarkeit* — Gates vor Rollout, Generation-Rollback, Wiederanlauf geübt],
  [*Fehlersuche* — Ursache vor Maßnahme, Beweise aus Logs und Metriken, Incident-Notizen],
  [*Reproduzierbarkeit* — gepinnte Inputs, Rebuild statt Reparatur, gleiche Prüfung in CI und Host],
  [*Härtung* — nftables Default-Deny, SOPS/age, SSH-CA, Minimalrechte],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Dokumentation* — Runbooks, Änderungen mit Rückweg, prüfbares Betriebswissen])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Betreute dreizehn Linux-Hosts deklarativ und hielt sie über fünf Jahre ohne Handarbeit auf dem Zielsystem in einem beschreibbaren Zustand.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen und keinen halben Rollout.
- Baute eine Telemetrieschleife, die alle fünfzehn Minuten Jobstatus, Generation Age, Disk-Druck und PSI erfasst und jeden Zustand ungleich ok meldet — Blindheit als Fehlerfall, nicht als Normalzustand.
- Nutzte cgroups und PSI, um zu unterscheiden, ob ein Host an Speicher, Ein-/Ausgabe oder CPU-Auslastung leidet, bevor Anwender es melden.
- Analysierte Störungen mit journald, cgroups, tcpdump und strace bis zur Ursache und dokumentierte Behebung und Rückweg.
- Härtete den Betrieb mit nftables als Default-Deny, SOPS/age-verschlüsselten Secrets pro Host und einer SSH-CA mit kurzlebigen Zertifikaten.
- Isolierte Arbeitslasten über MicroVMs als deklarierte Gäste und systemd-Slices mit Speichergrenzen, um einen Fehler nicht zum Flächenbrand werden zu lassen.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash hinter einer einheitlichen Oberfläche.
- Dokumentierte Betriebswissen so, dass Dritte es ohne Rückfrage nutzen konnten.

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD: Messdaten, Telemetrie-Abgleich, Abweichungsanalysen.
- Glich fehlende Sensordaten systematisch aus, statt Lücken zu schätzen, und berichtete Abweichungen in prüfbarer Form.
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie und Risikomanagement.
- Betreute eine Projektpipeline über 100 Mio. USD.

#job("Wissenschaftliche Hilfskraft", "Fraunhofer ISE", "März 2012 – Sept. 2012")
- Vermaß Heliostat-Ungenauigkeiten mit Interferometrie und schrieb die C++-Anwendung zur Geräteanbindung.
- Schrieb Python-Werkzeuge für Messdatenanalyse und 3D-Geometrie.

#job("Associate Technical Professional", "Halliburton", "Juni 2010 – Sept. 2011")
- Behob Geräte- und Prozessprobleme vor Ort, unter Zeitdruck und ohne zweiten Versuch.
- Leitete die Sicherheitsschulung der Crew und arbeitete nach Verfahren, die Abweichungen nicht dulden.

#section("Ausgewählte Projekte")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Telemetrieschleife]
    #linebreak()
    Ein Ledger prüft Jobstatus, Generation Age, Disk-Druck und PSI, meldet jeden Zustand ungleich ok und
    hält fest, was wann gemessen wurde.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Reproduzierbarkeit]
    #linebreak()
    Ein Flake beschreibt dreizehn Hosts, Dienste, Secrets und eine Task-Oberfläche; CI und Host führen
    dasselbe Gate aus.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— Schwachstellenlage]
    #linebreak()
    CISAs Katalog bekannter ausgenutzter Schwachstellen als Zeitreihe, Exposition nach
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis · bereit zu Sicherheitsüberprüfung, Tauglichkeitsuntersuchung und Schichtdienst]
