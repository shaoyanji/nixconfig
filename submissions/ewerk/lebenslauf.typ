// EWERK GROUP — Senior Platform / DevOps Engineer. Eigenständige Typst-Quelle.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.5em)
#set list(marker: text(fill: rgb("#14432a"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#14432a")
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
    #text(size: 10pt)[Plattformbetrieb · Energiedaten · deklarierte Systeme]
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
Ich bin in der Energiebranche groß geworden und im Betrieb geblieben: vier Jahre Asset Management für ein
Solarportfolio über 100 Mio. USD, danach fünf Jahre Plattformbetrieb. Was mich dort gehalten hat, ist
dieselbe Frage, die eine KRITIS-Umgebung stellt: Läuft es, und wenn es nicht läuft, weiß jemand warum und
wie man zurückkommt? Meine Antwort ist eine Plattform, deren Zustand aus einer Deklaration entsteht,
dreizehn Linux-Hosts aus einem Repository, jede Änderung durch ein Gate, Rollback als Zeiger auf die vorige
Generation, Telemetrie alle fünfzehn Minuten. Deutsch C1, Englisch Muttersprache, US-Staatsbürger mit
deutscher Niederlassungserlaubnis.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Energie* — Ertragsmodelle, Messdaten, Telemetrie-Abgleich, Abweichungsanalyse],
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump, strace],
  [*Deklarativer Betrieb* — gepinnte Inputs, Rebuild statt Reparatur, Generation-Rollback],
  [*Telemetrie* — Ledger alle 15 Minuten, Alerting, PSI als Lastsignal, Kapazitätsblick],
  [*Sicherheit* — nftables Default-Deny, SOPS/age, SSH-CA, Minimalrechte],
  [*Automatisierung* — Go, Python, Bash, Nix hinter einer Task-Oberfläche],
  [*Netzwerk* — WireGuard, eigene DNS-Zone, TLS/PKI, MTU-Analyse],
  [*Dokumentation* — Runbooks, Incident-Notizen, prüfbares Betriebswissen])

#section("Berufserfahrung")

#job("Asset Manager", "O3 Energy", "Aug. 2016 – Juni 2020")
- Verantwortete Datenqualität und Ertragsmodelle für ein Solarportfolio über 100 Mio. USD: Messdaten, Telemetrie-Abgleich, Abweichungsanalysen.
- Führte mobile Felderfassung ein und glich fehlende Sensordaten systematisch aus, statt Lücken zu schätzen.
- Berichtete Anlagenzustand und Abweichungen an Eigentümer und Banken, in einer Form, die Prüfungen bestand.
- Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften: Arbeitsplätze, Netz, Wi-Fi, Anwendungen.
- Unterstützte Feldtechniker direkt, mit Einweisung statt Ticket-Weiterleitung.

#job("Gründer", "Bountystash", "Juni 2020 – Aug. 2025")
- Betreute dreizehn Linux-Hosts deklarativ: gewünschter Zustand im Repository, keine Handarbeit auf dem Zielhost, Rebuild als beschriebener Pfad.
- Führte jede Änderung durch ein Gate, das in CI und auf dem Host identisch läuft; ein fehlgeschlagener Check lässt die vorige Generation stehen.
- Überwachte Systeme und Dienste mit einem Ledger alle fünfzehn Minuten — Jobstatus, Generation Age, Disk-Druck, PSI — und meldete jeden Zustand ungleich ok.
- Nutzte cgroups und PSI als Lastsignal, um zu sehen, ob ein Host an Speicher oder Ein-/Ausgabe leidet, bevor Anwender es merken.
- Härtete den Betrieb mit nftables als Default-Deny, SOPS/age-verschlüsselten Secrets pro Host und einer SSH-CA mit kurzlebigen Zertifikaten.
- Analysierte Störungen mit journald, cgroups und tcpdump bis zur Ursache und dokumentierte Behebung und Rückweg.
- Isolierte Arbeitslasten über MicroVMs als deklarierte Gäste und systemd-Slices mit Speichergrenzen.
- Automatisierte wiederkehrende Betriebsschritte in Go, Python und Bash hinter einer einheitlichen Oberfläche.

#job("Director of Sustainability", "Smart Energy 360", "Aug. 2015 – Aug. 2016")
- Beriet Mandanten zu Energiestrategie und Risikomanagement, mit Datenmodellen als Grundlage der Empfehlung.
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
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Betriebsblindheit beenden]
    #linebreak()
    Ein Ledger prüft alle fünfzehn Minuten Jobstatus, Generation Age, Disk-Druck und PSI und meldet
    jeden Zustand ungleich ok — der Unterschied zwischen Ausfall und Vermutung.
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
#text(size: 7.8pt, fill: muted)[Deutsch C1 · Englisch Muttersprache · US-Staatsbürger mit deutscher Niederlassungserlaubnis, kein Sponsoring nötig · remote erprobt, fünf Jahre ortsunabhängig]
