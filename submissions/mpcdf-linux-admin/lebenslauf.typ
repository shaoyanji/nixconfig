#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.58em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systembetrieb — Basisdienste, reproduzierbare Auslieferung, Messgrößen]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre Linux-Knoten, die aus einer Beschreibung entstehen: dreizehn Hosts über drei Hardware-Generationen, Installation über das Netz, gepinnte Eingaben, Prüfung des Rollouts, Rückkehr zur vorigen Generation in Minuten. Darunter die Dienste, von denen alles andere abhängt: Adressierung, DNS, Secrets pro Host, eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten. Messen ist keine Beigabe — Speicher- und Prozessdruck, Plattenplatz und Alter der laufenden Generation werden alle fünfzehn Minuten erfasst, weil sie einem Ausfall vorausgehen. Dazu die Messdisziplin aus der Forschung: 2012 am Fraunhofer ISE Messaufbau und Auswertung, davor ein Ingenieurstudium an der Colorado School of Mines. Was an Identitätsdiensten fehlt, steht im Anschreiben.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(6pt)
  #text(size: 10.5pt, weight: "bold", fill: rgb("#1f2937"))[#kind]
  #v(1pt)
  #line(length: 100%, stroke: 0.4pt + rgb("#e5e7eb"))
  #v(2pt)
]

#let entry(title, when, bullets) = block(breakable: false, width: 100%)[
  #par[
    #text(weight: "bold")[#title]
    #if when != "" [#text(size: 8.5pt, fill: rgb("#4b5563"))[ — #when]]
  ]
  #if bullets != () [
    #v(1pt)
    #block(inset: (left: 10pt, top: 0pt, bottom: 0pt))[
      #for bullet in bullets [- #bullet]
    ]
  ]
  #v(4pt)
]

#section("Berufserfahrung")
#entry("Bountystash — Gründer und alleiniger Systembetreiber", "2020 – 2025", (
  "Dreizehn Linux-Hosts über drei Hardware-Generationen installiert, gehärtet und gewartet, inklusive PXE-Installation und Boot über das Netz",
  "Basisdienste selbst betrieben: Adressierung, DNS, Secrets pro Host, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, Zugang über WireGuard und nftables",
  "Knoten als Beschreibung: gepinnte Eingaben, gleiche Beschreibung ergibt gleiches System, keine von Hand geänderten Dateien",
  "Auslieferung mit Prüfung vor dem Rollout und Rückkehr zur vorigen Generation in Minuten statt in einer Nacht",
  "Ressourcen im Blick: cgroups, Namespaces, PSI und Speicherdruck als Messgrößen, nicht als Vermutung",
  "Telemetrie als Schleife: Ledger alle fünfzehn Minuten, Prüfungen von außen auf Erreichbarkeit und Antwortzeit, Go-Brücke mit Zustellbestätigung",
  "Sicherungen mit restic und durchgeführten Rückspielungen; Wiederherstellung geübt, nicht angenommen",
  "Werkzeuge in Python, Go und Shell für Rollout, Auswertung, Messreihen und Berichte",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau im Labor betreut: Geräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "Messdaten nachvollziehbar abgelegt, damit Ergebnisse über die Projektlaufzeit hinaus prüfbar bleiben",
  "In einem Forschungsumfeld mit geteilten Rechnern und dokumentierten Auswertungen gearbeitet",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung und Verantwortung für Software und IT des Unternehmens",
  "Betriebsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet",
))

#section("Projekte")
#entry("nixconfig — ein Verbund, einmal beschrieben", "seit 2023", (
  "Ein Host registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen aus derselben Beschreibung",
  "Zugänge und Rollen dokumentiert: wer welchen Dienst nutzt und welcher Knoten ihn trägt",
  "Veröffentlichen, Ausrollen und Rückrollen sind Aufgaben, keine Eingriffe auf dem Knoten",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst messen, dann urteilen: ohne Vorher-Nachher-Wert ist eine Änderung eine Vermutung. \
  - Erst beschreiben, dann ändern: ein Dienst, der nur in Handarbeit existiert, lässt sich nicht wiederherstellen. \
  - Aufschreiben, was war: Messreihen, Regeln und Vorfälle gehören in die Dokumentation, nicht ins Gedächtnis.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2; Ingenieurausbildung mit Mess- und Versuchstechnik",))

#section("Kenntnisse")
#text(weight: "bold")[Systeme] — Linux-Knoten, systemd, cgroups, Namespaces, PSI und Speicherdruck, Boot und Wiederherstellung, PXE \
#text(weight: "bold")[Basisdienste] — DNS, Adressierung, Secrets pro Host, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, WireGuard, nftables \
#text(weight: "bold")[Messung] — Ledger mit Zeitstempel, Prüfungen von außen, Alarmbrücke mit Zustellbestätigung, Messreihen in Python \
#text(weight: "bold")[Auslieferung] — Nix als reproduzierbare Beschreibung, Gates, Rückrollung über Generationen \
#text(weight: "bold")[Code] — Python, Go, Shell; Automatisierung, Auswertung, Berichte \
#text(weight: "bold")[Nicht vorhanden] — LDAP (OpenLDAP, 389 DS), Kerberos (MIT, Heimdal), SSSD und PAM-Einbindung, FreeIPA, Zwei-Faktor-Rollout; Slurm, Lustre, InfiniBand, GPU- und CUDA-Betrieb, RHEL im Clusterbetrieb, Puppet oder Ansible \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Umzug nach Garching möglich
