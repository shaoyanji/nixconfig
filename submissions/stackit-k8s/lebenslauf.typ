// STACKIT / Schwarz Digits — Senior Kubernetes Engineer (m/f/d), GT4121, Bad Friedrichshall.
// Deutsche Typst-Quelle anstelle des Nix-Pakets. Container, microVMs, Nix, Telemetrie.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1d3c34"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1d3c34")
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
    #text(size: 9.8pt)[Linux- und Plattformingenieur · Container, microVMs, NixOS, Telemetrie]
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
Ich baue Plattformen, die aus einem Commit reproduzierbar sind, und ich betreibe sie danach selbst. Sechs Jahre lang lief eine Flotte von dreizehn
NixOS-Hosts unter meiner alleinigen Verantwortung: jeder Host deklarativ beschrieben, jeder Dienst eine systemd-Unit mit definiertem Fehlerverhalten,
jede Änderung eine Generation, die sich in einem Befehl zurückrollen lässt. Der Unterschied zwischen einem Cluster, den man erklären kann, und einem,
der nur läuft, liegt in dieser Rückverfolgbarkeit, nicht im Orchestrator.

Container und microVMs habe ich von der Grenze her gebaut statt von der Oberfläche: microVM-Gäste deklarativ beschrieben, auf KVM mit cloud-hypervisor
gestartet, mit vsock für den Kanal zum Host, virtiofs für geteilte Verzeichnisse und einem TCG-Rückfall, wenn die Hardwarevirtualisierung fehlt. Die
Gäste hängen hinter einer isolierten Bridge mit NAT und udev-gebundenen Taps; Ressourcengrenzen setzen systemd-Slices und cgroups, nicht ein
Kommentar in der Konfiguration. Wer Gäste so startet, lernt, was ein Namespace trennt und was nicht.

Betrieb heißt bei mir Messen vor Vermuten. Ein Sentinel schreibt Job-Status, Generationsalter, Disk- und Inode-Auslastung sowie PSI-Werte für IO,
Speicher und CPU alle fünfzehn Minuten in ein Journal; alarmiert wird auf einen schlechten Zustand und auf Stille, weil ein ausgefallener Melder sonst
wie ein gesunder Host aussieht. Dazu gehören die unglamourösen Teile: PostgreSQL mit geordneten Migrationen und einem Wiederherstellungsdrill, der
einen Dump in einen temporären Cluster spielt und Tabellen- und Zeilenzahlen prüft.

Linux und Netz sind Handwerk: systemd, nftables-Freigaben je Dienst und Netz mit datierten Streichungen, WireGuard-Mesh, ein DNS-Failover mit
VRRP, und Fehlersuche mit tcpdump bis zur MTU an der Grenze, die das Paket verwirft, statt auf einen Anwendungstimeout zu warten. Speicherseitig
kenne ich ZFS, SMART/NVMe, NFS und SMB, Snapshots und Backups.

Wo ich hinter dem Profil zurückbleibe: Kubernetes habe ich nicht in Produktion betrieben, weder als Cluster noch als Multi-Cluster-Landschaft, und
weder Gardener noch ClusterAPI eingesetzt. Operatoren, Controller und CRDs in Go habe ich nicht geschrieben; meine Go-Arbeit sind Dienste und
Kommandozeilenwerkzeuge. Kyverno, Falco, GitOps mit Argo oder Flux und Betrieb von CNI und etcd fehlen ebenfalls. Diese Sätze stehen hier, damit sie
im Gespräch nicht überraschen.

#section("Schwerpunkte")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*microVMs* — cloud-hypervisor auf KVM, vsock, virtiofs, TCG-Rückfall, udev-Taps],
  [*Ressourcen* — systemd-Slices und cgroups, PSI, Disk- und Inode-Grenzen je Pfad],
  [*NixOS und Nix* — deklarative Hosts, Flake mit gepinnten Inputs, Auswertungslauf je Host],
  [*Linux* — systemd, Namespaces, Rechte, Härtung mit `ProtectSystem` und `NoNewPrivileges`],
  [*Netz* — nftables je Dienst, WireGuard-Mesh, NAT und Bridge, DNS-Failover mit VRRP],
  [*Telemetrie* — Sentinel-Journal alle fünfzehn Minuten, Alarm auf Zustand und auf Stille],
  [*Daten* — PostgreSQL mit Migrationen und Wiederherstellungsdrill, ZFS, NFS und SMB],
  [*Automatisierung* — Planungslauf, JSON-Ausgabe, ein Exit-Code je Ergebnis, Pre-Push-Gates])

#section("Berufserfahrung")

#block(breakable: false)[
#job("Gründer und Ingenieur", "Bountystash", "06/2020 – 08/2025", "Freiburg im Breisgau")
- Flotte mit dreizehn NixOS-Hosts aus einem Flake: gepinnte Inputs, ein Auswertungslauf pro Host als Freigabe, hermetische Builds, Rollback auf die vorherige Generation.
- microVM-Labor auf KVM: Gäste deklarativ beschrieben, mit cloud-hypervisor gestartet, vsock und virtiofs für Host-Kanal und geteilte Verzeichnisse, TCG als Rückfall ohne Hardwarevirtualisierung.
- Netzgrenzen von Hand gezogen: isolierte Bridge mit NAT, udev-gebundene Taps für die Gäste, Firewall-Freigaben je Dienst und Netz statt einer Pauschalfreigabe, mit datierten Streichungen.
- Betrieb mit Telemetrie: Job-Status, Generationsalter, Disk- und Inode-Auslastung sowie PSI alle fünfzehn Minuten in einem Journal, Alarm auf schlechten Zustand und auf ausbleibende Meldung.
- Datenhaltung mit Wiederherstellung: PostgreSQL je Dienst mit geordneten Migrationen, dazu ein Drill, der einen Dump in einen temporären Cluster spielt und Tabellen- und Zeilenzahlen prüft.
- Zugriff ohne stehende Schlüssel: eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, SOPS-verschlüsselte Secrets mit einem age-Schlüssel pro Host.
- Automatisierung als Vertrag: Aufgaben mit typisierten Argumenten, Planungslauf ohne Wirkung, JSON-Ausgabe und einem Exit-Code je Ergebnis, dazu Pre-Commit- und Pre-Push-Gates.
- Fehlersuche am Paket: eine pfadspezifische MTU-Störung mit tcpdump bis zu der Grenze verfolgt, die verworfen hat, und den Pfad dokumentiert, statt den Anwendungstimeout zu vergrößern.

#job("Eigene Projekte", "Selbstständig", "2023 – heute", "Remote")
- Go-Dienste und Kommandozeilenwerkzeuge für Telemetrie und Betrieb, daneben Python und Bash für Prüfungen und Auswertungen.
- tokenloom: Rust-Arbeitsbereich mit Piece-Table und einem Retokenisierer, der nur die geänderte Spanne anfasst; ein Abnahmetest hält die Invariante fest.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "08/2016 – 06/2020", "Dallas, Texas, USA")
- Datenqualität und Ertragsmodelle eines Solarportfolios über 100 Mio. USD; drei Messreihen zu einer prüfbaren Reihe zusammengeführt.
- Software und IT für das Unternehmen und seine Töchter verantwortet, ein internationales Team geführt.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "08/2015 – 08/2016", "Dallas, Texas, USA")
- Beratung gewerblicher Kunden zu Energiestrategie, Software und Risiko.
]

#block(breakable: false)[
#job("Wissenschaftlicher Mitarbeiter", "Fraunhofer ISE", "03/2012 – 09/2012", "Freiburg im Breisgau")
- C++-Anwendung für ein Heliostaten-Interferometer und die zugehörige Python-Auswertung; die Geometrie gegen eine unabhängige Rechnung geprüft.
]

#section("Ausgewählte Arbeiten")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[microVM-Labor] #text(size: 8pt, fill: muted)[— Virtualisierung]
    #linebreak()
    cloud-hypervisor auf KVM, vsock und virtiofs, isolierte Bridge mit NAT, TCG als Rückfall.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— Plattform]
    #linebreak()
    Dreizehn Hosts, gepinnte Inputs, ein Auswertungslauf je Host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— Telemetrie]
    #linebreak()
    PSI, Job-Status und Generationsalter alle fünfzehn Minuten; Alarm auf Zustand und Stille.
  ],
  [
    #text(weight: "bold")[firewall-scope] #text(size: 8pt, fill: muted)[— Netz]
    #linebreak()
    Freigaben je Dienst und Netz mit datierten Streichungen statt einer Pauschalfreigabe.
  ],
  [
    #text(weight: "bold")[mail-archive] #text(size: 8pt, fill: muted)[— Daten]
    #linebreak()
    PostgreSQL mit Migrationen, gespeichertem `tsvector` hinter GIN und Upsert auf `message_id`.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— Automatisierung]
    #linebreak()
    Typisierte Argumente, Planungslauf, JSON-Ausgabe, ein Exit-Code je Ergebnis.
  ])

#section("Ausbildung")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · Note 1,8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · GPA 3,2]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[US-amerikanischer Staatsbürger mit unbefristeter Niederlassungserlaubnis, kein Sponsoring nötig · Deutsch C1, Englisch Muttersprache · Umzug nach Bad Friedrichshall: ja · Eintritt ab 01.12.2026]
