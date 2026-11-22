// Adfinis AG — Senior System Engineer (Cloud Native). Eigenständige deutsche Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#7a2f2f"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#7a2f2f")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
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
    #text(size: 9.8pt)[Linux-Systeme · Deklarative Infrastruktur · Open Source]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/in/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profil")
Fünf Jahre Betrieb einer Linux-Flotte, die als ein Repository beschrieben ist: jeder Host eine Feature-Liste, jeder
Dienst ein Modul, jeder Eingang gepinnt, jeder Wechsel durch ein Gate, das in der CI und auf der Maschine identisch
läuft. Secrets liegen mit sops verschlüsselt pro Host hinter einer eigenen SSH-Certificate-Authority, die kurzlebige
Zugänge ausstellt statt Schlüssel zu verteilen; jede Generation hat einen Vorfahren, damit ein Rollback ein Zeiger ist
und keine Reparatur unter Zeitdruck; ein Sentinel schreibt alle fünfzehn Minuten Jobstatus, Generation-Alter, Disk- und
PSI-Druck und alarmiert, wenn ein Dienst aufhört zu melden. Dazu eine Dekade kaufmännischer Verantwortung für
Energieanlagen, in der ich gelernt habe, in Kosten pro Einheit und Service-Leveln zu denken. Ich habe Kubernetes-Cluster
und Terraform nicht im Kundenbetrieb geführt; meine Tiefe liegt in deklarierten Linux-Systemen und in NixOS, das Ihre
Ausschreibung ausdrücklich als akzeptierte Distribution nennt.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — systemd, cgroups, PSI, nftables, `tcpdump`, `strace`],
  [*Deklarative Infrastruktur* — Flake, Module, gepinnte Eingänge],
  [*CI/CD* — ein Gate für CI und Host, inventarisierte Matrix],
  [*Betrieb* — Generationen, Rollback per Zeiger, Canary vor der Flotte],
  [*Monitoring* — Fünfzehn-Minuten-Ledger, Alarm auf Zustand statt Volumen],
  [*Security* — sops/age, SSH-CA, Default-Deny, kurzlebige Zugänge],
  [*Automatisierung* — Go, Python, Bash hinter einer validierten Oberfläche],
  [*Kosten* — Aufbewahrung als Entscheidung, Kapazität gemessen])

#section("Berufserfahrung")

#job("Gründer", "Bountystash", "06/2020 – 08/2025")
- Betrieb von dreizehn Linux-Hosts als eine Deklaration: Dienste, Speicher, Firewall, Secrets und Telemetrie als Module, mit dokumentiertem Rebuild-Pfad je Host und ohne manuelle Eingriffe auf einer laufenden Maschine.
- Zugänge ausgegeben statt gespeichert: SSH-Certificate-Authority mit kurzlebigen Zertifikaten, pro Host verschlüsselte Secrets, Default-Deny-Regeln.
- Jede Änderung durch ein Gate, das in der CI und auf dem Zielhost identisch läuft; ein fehlgeschlagener Check lässt die vorherige Generation weiterlaufen.
- Deployment als Generation mit Vorfahren, damit ein Rollback ein Zeiger auf ein bekanntes System ist.
- Aufbau der Betriebsüberwachung: Jobstatus, Generation-Alter, Disk- und PSI-Druck alle fünfzehn Minuten, Alarm bei jedem Zustand außer „ok" und bei ausbleibender Meldung.
- Fünf Jahre selbst im Bereitschaftsdienst, woraus die Runbooks entstanden: wiederkehrende Prüfungen wurden Werkzeug, alles was zweimal scheiterte wurde ein Check.
- Fehlerursachen auf Systemebene: `strace` für Syscall-Verhalten, cgroups und PSI zur Trennung von I/O- und Speicherdruck, `tcpdump` für MTU und Fragmentierung.
- Aufbewahrung und Kapazität als Entscheidung mit Zahl, damit Speicherdruck als bekannte Kurve ankommt.

#job("Asset Manager", "O3 Energy", "08/2016 – 06/2020")
- Leitung des Asset Managements eines Solarportfolios über 100 Mio. USD, inklusive Betrieb von 10 MW PV-Anlagen.
- Ertrags- und Bewertungsmodelle, die Bankenprüfungen standhielten, samt nachvollziehbarem Abgleich hinter jeder Zahl.
- Durchführung von Software-Rollouts bei Kunden und Dokumentation jedes einzelnen.

#job("Director of Sustainability", "Smart Energy 360", "08/2015 – 08/2016")
- Verantwortung für eine Projektpipeline über 100 Mio. USD im Segment gewerblicher Kunden.
- Beratung zu Nachhaltigkeitsstrategie und Risiko, mit Datenmodellen als Grundlage jeder Empfehlung.

#job("Wissenschaftlicher Mitarbeiter", "Fraunhofer ISE", "03/2012 – 09/2012")
- C++-Anwendung für ein Heliostat-Interferometer, Auswertung in Python inklusive 3D-Geometrie.
- Arbeit in Messkampagnen, in denen ein Ergebnis reproduzierbar sein musste und nicht nur plausibel.

#job("Associate Technical Professional", "Halliburton", "06/2010 – 09/2011")
- Behebung von Equipment- und Prozessproblemen im Feld, unter Zeitdruck und ohne zweiten Versuch.

#section("Ausgewählte Projekte")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Infrastruktur als Code]
    #linebreak()
    Dreizehn Hosts, gepinnte Eingänge, ein Gate pro Host unter Speicherwächter, Rollback als Zeiger auf die vorherige
    Generation. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Monitoring]
    #linebreak()
    Jobstatus, Generation-Alter, Disk und PSI alle fünfzehn Minuten, Alarm bei jedem Zustand außer ok und bei Stille,
    mit Historie für die Nachbetrachtung.
  ],
  [
    #text(weight: "bold")[Zero Standing Secrets] #text(size: 8pt, fill: muted)[— Security]
    #linebreak()
    Eine Flotten-CA stellt kurzlebige SSH-Zugänge aus, Secrets liegen pro Host verschlüsselt, nichts auf der Platte
    überlebt die Sitzung, die es gebraucht hat.
  ],
  [
    #text(weight: "bold")[Task-Control-Plane] #text(size: 8pt, fill: muted)[— Self-Service]
    #linebreak()
    Jede Flottenoperation hinter einer Oberfläche mit benannten Argumenten und Validierung, damit ein falsches
    Argument scheitert, bevor es einen Host berührt.
  ],
  [
    #text(weight: "bold")[Netboot-Provisionierung] #text(size: 8pt, fill: muted)[— Bare Metal]
    #linebreak()
    PXE und iVentoy liefern Installer und Erstkonfiguration, damit eine Maschine in die deklarierte Flotte kommt statt
    von Hand zusammengesetzt zu werden.
  ],
  [
    #text(weight: "bold")[Energie-Telemetrie] #text(size: 8pt, fill: muted)[— O3 Energy]
    #linebreak()
    Drei Datenquellen zu einer prüfbaren Reihe zusammengeführt; fehlende Messwerte als bekanntes Fehlerbudget statt
    als guter Monat.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch muttersprachlich · US-Staatsbürger mit unbefristeter Niederlassungserlaubnis, arbeitsberechtigt ohne Sponsoring · remote aus Deutschland, Reisebereitschaft in der DACH-Region]
