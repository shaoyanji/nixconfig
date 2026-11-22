// Biz Factory GmbH — Systemadministrator / DevOps Engineer, Linux- und Kubernetes-basierte OSS-Infrastrukturen.
// Native deutsche Quelle statt des Nix-Builds. Nur belegbare Fakten.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2f3350")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when, where) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
  #v(-2pt)
  #text(size: 8pt, fill: muted)[#where]
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Systemadministrator und DevOps Engineer · Linux · deklarativer Betrieb]
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
Linux-Betrieb ist bei mir Code, nicht Checkliste. Ein Flake deklariert dreizehn Hosts, jeder Host ist eine Feature-Liste, jeder
Dienst ein Modul mit systemd-Unit und definiertem Fehlerverhalten, Secrets liegen mit sops hinter einer eigenen
SSH-Zertifizierungsstelle, und jede Generation lässt sich mit einem Befehl zurückrollen. Rebuilds kommen aus einem gemeinsamen
Binary-Cache und von Remote-Buildern; die CI führt dasselbe Gate je Host aus, das die Maschine vor dem Umschalten besteht.

Datenbanken und Dienste betreibe ich im Alltag: PostgreSQL für die Anwendungsdatenbank mit Migrationen und einem dokumentierten
Wiederherstellungsweg, ein Mail-Archiv, das seine Post selbst klassifiziert, und ein Ledger, das denselben POST zweimal annimmt, ohne
die Zeile zu duplizieren. Go trägt die Dienste, Python die Werkzeuge. Telemetrie baue ich selbst: ein Sentinel schreibt alle fünfzehn
Minuten Jobstatus, Generation Age, Disk- und PSI-Druck in ein Ledger, Gatus alarmiert bei jedem Zustand außer ok — und bei Stille,
weil ein Monitor, der aufhört zu melden, wie ein System ohne Befund aussieht.

Zur Rolle gehört für mich die Helpdesk-Haltung: ein Runbook, das jemand anderes lesen kann, eine Dokumentation, die den Befehl nennt
statt die Absicht, und ein Ticket, das nicht zweimal aufgemacht wird, weil die Ursache beim ersten Mal nur symptomweise behandelt
wurde.

Was ich nicht mitbringe, sage ich vorher: SLES- und RHEL-Betrieb, OpenShift und OpenStack, Kubernetes im Produktivcluster sowie
GitLab CI und LDAP/Active Directory habe ich nicht als eigene Verantwortung geführt. Tiefen Linux-Betrieb, Container als
Build-Umgebung, Datenbankbetrieb und Automatisierung als Code bringe ich mit — und die Bereitschaft, die fehlenden Werkzeuge in
eurer Umgebung zu lernen.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — systemd-Units, nftables, Kernel-Pinning, Server-Betrieb],
  [*Deklarativ* — ein Flake, Hosts als Feature-Listen, Dienste als Module],
  [*Datenbanken* — PostgreSQL mit Migrationen, Backup, Wiederherstellung],
  [*Container* — reproduzierbare Build-Umgebungen, MicroVM-Gäste als Canary],
  [*Monitoring* — Ledger und Gatus, Alarm bei schlechtem Zustand und bei Stille],
  [*Automatisierung* — Go und Python hinter einer validierten Task-Oberfläche],
  [*Sicherheit* — sops je Host, kurzlebige Zertifikate aus eigener CA],
  [*Dokumentation* — Runbooks und Schulungen aus derselben Quelle wie die Konfiguration])

#section("Berufserfahrung")

#block(breakable: false)[
#job("Gründer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Deklarierte eine ganze Flotte als ein Flake: dreizehn Hosts, jeder eine verkettete Feature-Liste, jeder Dienst ein Modul, damit die Optionsfläche ein Gate bleibt statt einer Kopie, die auseinanderläuft.
- Verschlüsselte jedes Secret mit sops und stellte Hostschlüssel über eine eigene SSH-Zertifizierungsstelle aus; Zugriff ist ein kurzlebiges Zertifikat, kein Schlüssel, den jemand weitergegeben hat.
- Bediente Rebuilds aus einem gemeinsamen Binary-Cache und von Remote-Buildern und machte Rollback zu einem Zeiger auf die vorige Generation.
- Ließ in der CI dasselbe Modul-Gate laufen, das eine Maschine vor dem Umschalten besteht, angetrieben von einer Inventardatei, sodass eine fehlerhafte Hostdefinition vor der Hardware scheitert.
- Betreibt PostgreSQL für die Anwendungsdatenbank: Migrationen über dieselbe Task-Oberfläche, ein geprüfter Wiederherstellungsweg, Statement-Timeouts und Alarm auf Disk-Druck.
- Schrieb die Dienste der Flotte in Go und Python: ein Append-only-Eventlog, ein Mail-Archiv, das seine Post klassifiziert, ein Ledger mit idempotentem POST, eine Task-Oberfläche mit typisierten Argumenten, Trockenläufen und JSON-Ausgabe.
- Führte Monitoring als geschlossenen Kreis: Ledger alle fünfzehn Minuten mit Jobstatus, Generation Age, Disk und PSI, Gatus alarmiert bei jedem Zustand außer ok und bei Stille.
- Entwickelte eine Covered-Call-Hedging-Strategie für Kundenportfolios und prüfte Bug-Bounty-Programme mit Triage gegen Listen bekannter ausgenutzter Schwachstellen.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD und führte drei Messreihen zu einer prüfbaren Zeitreihe zusammen.
- Administrierte Software und IT für das Unternehmen und seine Tochtergesellschaften, einschließlich Rollout, Zugriffen und der Dokumentation, die das wiederholbar machte.
- Analysierte Haftungsrisiken und baute den internen Risikomanagementrahmen, an dem die Töchter danach gemessen wurden.
- Leitete ein internationales Team und baute eine Anreizstruktur an einem live gerechneten Finanzmodell.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Betreute eine Projektpipeline über 100 Mio. USD und beriet Geschäftskunden zu Energiestrategie, Sicherheitssoftware und Risiko.
- Verantwortete Kundenservice und Betreuung und entwickelte Vertriebs- und Marketingstrategie für die Nachhaltigkeitspraxis.
]

#block(breakable: false)[
#job("Wissenschaftliche Hilfskraft", "Fraunhofer ISE", "Mär 2012 – Sep 2012", "Freiburg, DE")
- Schrieb die C++-Anwendung für ein Heliostat-Interferometer und die Python-Analyse daneben und prüfte die Geometrie unabhängig in Mathematica, statt der ersten Implementierung zu glauben.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Arbeitete zwölfstündige Schichten im Feld, führte die Sicherheitsschulung der Crew und diagnostizierte Geräte- und Prozessfehler unter Zeitdruck.
]

#section("Ausgewählte Arbeiten")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Linux-Flotte]
    #linebreak()
    Dreizehn Hosts aus einem Flake, gepinnte Eingaben, hermetische Builds, sops-Secrets, SSH-CA, ein Gate pro Host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[Mail-Archiv] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    Mail in PostgreSQL, klassifiziert und über eine API abfragbar, mit Migrationen und geprüftem Wiederherstellungsweg.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Monitoring]
    #linebreak()
    Jobstatus, Generation Age, Disk und PSI alle fünfzehn Minuten, Alarm bei schlechtem Zustand und bei Stille.
  ],
  [
    #text(weight: "bold")[Task-Control-Plane] #text(size: 8pt, fill: muted)[— Automatisierung]
    #linebreak()
    Eine validierte Oberfläche mit typisierten Argumenten, Trockenlauf und JSON, von Menschen und Agenten genutzt.
  ],
  [
    #text(weight: "bold")[Schwachstellenbetrieb] #text(size: 8pt, fill: muted)[— Sicherheit]
    #linebreak()
    Triage gegen den CISA-KEV-Katalog, geordnet nach tatsächlicher Betroffenheit der Flotte statt nach Meldungsvolumen.
  ],
  [
    #text(weight: "bold")[Swirl Engine] #text(size: 8pt, fill: muted)[— Go und Geometrie]
    #linebreak()
    Polygonflächen aus stochastischen Daten über den Satz von Green, mit einem Go-Fuzzer für die Formen, die es brechen.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Erneuerbare-Energien-Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Erdöltechnik] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3,2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[Deutsch C1 (verhandlungssicher) · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · 100 Prozent remote möglich · verfügbar ab 01.12.2026]
