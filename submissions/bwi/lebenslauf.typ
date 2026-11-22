// BWI GmbH — Senior Infrastructure/Platform Engineer (m/w/d), Stellen-ID 64059.
// Deutsche Typst-Quelle anstelle der Nix-PDFs. Linux, NixOS, Härtung, Automatisierung.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1f3a52"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1f3a52")
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
    #text(size: 9.8pt)[Linux- und Plattformingenieur · NixOS, Härtung, DevSecOps-Automatisierung]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profil")
Ich baue Infrastruktur, die aus einem Commit reproduzierbar ist. Sechs Jahre lang habe ich eine Flotte von dreizehn NixOS-Hosts allein betrieben:
jeder Host deklarativ beschrieben, jeder Dienst eine systemd-Unit mit definiertem Fehlerverhalten, jede Änderung eine Generation, die sich in einem
Befehl zurückrollen lässt. Was ich dabei gelernt habe, ist weniger ein Werkzeug als eine Arbeitsweise: eine Änderung wird erst als erledigt betrachtet,
wenn ein Prüfschritt sie bestätigt.

Die Flotte liegt in einem Flake mit gepinnten Inputs. Ein Host ist eine Liste von Modulen; die Auswertung läuft pro Host und bricht ab, bevor ein
fehlerhafter Stand gebaut wird. Härtung ist Teil dieser Beschreibung und nicht ein Nacharbeiten: systemd-Dienste laufen mit `ProtectSystem=strict`,
`ProtectHome`, `PrivateTmp` und `NoNewPrivileges`, jeder Dienst hat einen eigenen Benutzer, und Firewall-Freigaben werden pro Dienst und Netz
eingetragen statt als Pauschalregel. Zugriff läuft über eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten; Secrets liegen
SOPS-verschlüsselt im Repository, mit einem age-Schlüssel pro Host, sodass ein kompromittierter Host nicht die Schlüssel der anderen liest.

Automatisierung heißt bei mir: eine Aufgabe mit typisierten Argumenten, einem Planungslauf ohne Wirkung, JSON-Ausgabe und einem Exit-Code je Ergebnis.
Dazu Pre-Commit- und Pre-Push-Prüfungen, die Formatierung, Syntax und Textregeln erzwingen, und ein Sentinel, der Job-Status, Generationsalter, Disk- und
PSI-Werte alle fünfzehn Minuten in ein Journal schreibt. Alarmiert wird auf einen schlechten Zustand und auf Stille, weil ein ausgefallener Melder sonst
wie ein gesunder Host aussieht. PostgreSQL betreibe ich mit geordneten Migrationen und einem Wiederherstellungsdrill, der einen Dump in einen temporären
Cluster spielt und Tabellen- sowie Zeilenzahlen prüft.

Wo ich unter dem Anforderungsprofil bleibe: Kubernetes habe ich nicht in Produktion betrieben, weder als Cluster noch in einer air-gapped Umgebung, und
ich habe weder CKA noch CKS. Ceph kenne ich nicht aus dem Betrieb; meine Storage-Erfahrung sind ZFS, SMART/NVMe, NFS/SMB und Backups. Virtualisierung
kenne ich aus KVM- und microVM-Laboren, nicht aus VMware- oder OpenStack-Umgebungen im Großbetrieb. Diese Sätze stehen hier, damit sie im Gespräch nicht
überraschen.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*NixOS und Nix* — deklarative Hosts, Flake mit gepinnten Inputs, Module je Rolle],
  [*Linux-Härtung* — systemd-Sandboxing, eigene Benutzer, minimale Rechte je Dienst],
  [*Netz* — nftables-Freigaben je Dienst und Netz, WireGuard-Mesh, NAT und Bridge],
  [*Zugriff* — SSH-CA mit kurzlebigen Zertifikaten, SOPS/age je Host, keine stehenden Schlüssel],
  [*Automatisierung* — Task-Control-Plane mit Planungslauf, CI-Gates, Pre-Commit und Pre-Push],
  [*Virtualisierung* — KVM, microVM mit cloud-hypervisor, vsock, virtiofs-Freigaben],
  [*Datenhaltung* — PostgreSQL mit Migrationen und Wiederherstellungsdrill, NFS und SMB],
  [*Betrieb* — Telemetrie, Alarm auf Zustand und Stille, Rollback per Zeiger, Dokumentation])

#section("Berufserfahrung")

#block(breakable: false)[
#job("Gründer und Ingenieur", "Bountystash", "06/2020 – 08/2025", "Freiburg im Breisgau")
- Betrieb einer NixOS-Flotte mit dreizehn Hosts aus einem Flake: gepinnte Inputs, ein Auswertungslauf pro Host als Freigabe, hermetische Builds und Rollback auf die vorherige Generation.
- Härtung als Teil der Deklaration: systemd-Dienste mit `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp` und `NoNewPrivileges`, ein Benutzer je Dienst.
- Firewall-Freigaben pro Dienst und Netz statt einer Pauschalfreigabe, mit datierten Streichungen, damit gewachsene Öffnungen nicht stehen bleiben.
- Zugriff ohne stehende Schlüssel: eigene SSH-Zertifizierungsstelle, kurzlebige Zertifikate, SOPS-verschlüsselte Secrets mit einem age-Schlüssel pro Host.
- Automatisierung als Vertrag: Aufgaben mit typisierten Argumenten, Planungslauf, JSON-Ausgabe und einem Exit-Code je Ergebnis; Pre-Commit- und Pre-Push-Gates für Format, Syntax und Textregeln.
- Betrieb mit Telemetrie: Job-Status, Generationsalter, Disk- und Inode-Auslastung sowie PSI alle fünfzehn Minuten in einem Journal, Alarm auf schlechten Zustand und auf ausbleibende Meldung.
- Datenhaltung mit Wiederherstellung: PostgreSQL je Dienst mit geordneten Migrationen, dazu ein Drill, der einen Dump in einen temporären Cluster spielt und Tabellen- und Zeilenzahlen prüft.
- Virtualisierung im Labor: microVMs auf KVM mit cloud-hypervisor, vsock und virtiofs, hinter einer isolierten Bridge mit NAT und udev-gebundenen Taps.

#job("Eigene Projekte", "Selbstständig", "2023 – heute", "Remote")
- mail-archive: PostgreSQL mit geordneten Migrationen, gespeichertem `tsvector` hinter einem GIN-Index und Upsert auf `message_id`, damit eine erneut zugestellte Nachricht keine zweite Zeile erzeugt.
- tokenloom: Rust-Arbeitsbereich mit Piece-Table und einem Retokenisierer, der nur die geänderte Spanne anfasst; ein Abnahmetest hält die Invariante fest.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "08/2016 – 06/2020", "Dallas, Texas, USA")
- Verantwortung für Datenqualität und Ertragsmodelle eines Solarportfolios über 100 Mio. USD; drei Messreihen zu einer prüfbaren Reihe zusammengeführt, die in die Finanzberichterstattung einging.
- Software und IT für das Unternehmen und seine Töchter verantwortet; ein internationales Team geführt und die Anreizstruktur an ein laufendes Finanzmodell gebunden.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "08/2015 – 08/2016", "Dallas, Texas, USA")
- Beratung gewerblicher Kunden zu Energiestrategie, Software und Risiko, mit Übersetzung zwischen technischen und kaufmännischen Lesern.
]

#block(breakable: false)[
#job("Wissenschaftlicher Mitarbeiter", "Fraunhofer ISE", "03/2012 – 09/2012", "Freiburg im Breisgau")
- C++-Anwendung für ein Heliostaten-Interferometer und die zugehörige Python-Auswertung geschrieben; die Geometrie gegen eine unabhängige Rechnung geprüft.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "06/2010 – 09/2011", "Williston, North Dakota, USA")
- Störungen an Anlagen und Prozessen vor Ort im Zwölfstundentakt behoben, mit einer Mannschaft und einem Zeitplan, die von der Antwort abhingen.
]

#section("Ausgewählte Arbeiten")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Infrastruktur als Code]
    #linebreak()
    Dreizehn Hosts, gepinnte Inputs, ein Auswertungslauf je Host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[firewall-scope] #text(size: 8pt, fill: muted)[— Netz]
    #linebreak()
    Freigaben je Dienst und Netz mit datierten Streichungen statt einer Pauschalfreigabe.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Betrieb]
    #linebreak()
    PSI, Job-Status und Generationsalter alle fünfzehn Minuten; Alarm auf Zustand und Stille.
  ],
  [
    #text(weight: "bold")[SSH-CA und SOPS] #text(size: 8pt, fill: muted)[— Zugriff]
    #linebreak()
    Kurzlebige Zertifikate und ein age-Schlüssel je Host statt stehender Schlüssel.
  ],
  [
    #text(weight: "bold")[Wiederherstellungsdrill] #text(size: 8pt, fill: muted)[— Daten]
    #linebreak()
    Dump in einen temporären PostgreSQL-Cluster gespielt, Tabellen- und Zeilenzahlen geprüft.
  ],
  [
    #text(weight: "bold")[microVM-Labor] #text(size: 8pt, fill: muted)[— Virtualisierung]
    #linebreak()
    KVM und cloud-hypervisor mit vsock und virtiofs, hinter isolierter Bridge mit NAT.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · GPA 3,2]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[US-amerikanischer Staatsbürger mit unbefristeter Niederlassungserlaubnis, kein Sponsoring nötig · Deutsch C1, Englisch Muttersprache · Umzug an einen BWI-Standort und Reisebereitschaft: ja · Eintritt ab 01.12.2026]
