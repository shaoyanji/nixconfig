#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.58em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Netzwerke und Systembetrieb — Firewalls, Fernzugriff, reproduzierbare Testbeds]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre Linux-Netze, allein aufgebaut und betrieben: dreizehn Hosts über mehrere Standorte, WireGuard zwischen den Netzen, nftables-Regeln im Code, keine öffentlich erreichbaren Verwaltungsdienste, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten. Jede Änderung ist beschrieben und geprüft, jede Umgebung ist aus derselben Beschreibung reproduzierbar — ein Testbed, das man nachbauen kann, statt einer Maschine, die nur einmal existiert. Überwachung und Alarmierung sind selbst gebaut, mit Zustellbestätigung statt Vermutung. Forschungsumfeld aus eigener Erfahrung: 2012 am Fraunhofer ISE Messaufbau, Geräteanbindung, Auswertung. Kommerzielle Firewall-Appliances, WAN-Routing und Glasfasertechnik habe ich nicht betrieben; das steht im Anschreiben.]

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
  "Netze über mehrere Standorte geplant und betrieben: Adressierung, DNS, WireGuard-Tunnel zwischen den Standorten, Fernzugriff ohne öffentlich erreichbare Verwaltungsdienste",
  "Firewall-Regeln als Code: nftables in der Systembeschreibung, nicht als Handarbeit auf der Maschine; Änderungen laufen durch eine Prüfung",
  "Dreizehn Linux-Hosts über drei Hardware-Generationen installiert, gehärtet und gewartet, inklusive PXE-Installation und Boot über das Netz",
  "Reproduzierbare Umgebungen: gepinnte Eingaben, gleiche Beschreibung ergibt gleiches System, Rückkehr zur vorigen Generation in Minuten — die Grundlage dafür, ein Testbed erneut aufzubauen",
  "Überwachung als geschlossene Schleife: Ledger alle fünfzehn Minuten, Prüfungen von außen, Go-Brücke, die einen Alarm erst nach bestätigter Zustellung als gemeldet führt",
  "Störungsbearbeitung ohne Eskalationsstufe dahinter: Schweregrad bestimmen, Ursache eingrenzen, Dienst wiederherstellen, Ursache dokumentieren",
  "Sicherheit im Betrieb: eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, sops und age je Host, minimale Rechte, getrennte Schlüssel",
  "Dokumentation aus dem Bestand erzeugt, damit Netze und Adressierung nicht in einem Kopf liegen",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solarleistung und Verantwortung für Software und IT des Unternehmens",
  "Betriebsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet",
))
#entry("Fraunhofer ISE — Wissenschaftlicher Mitarbeiter", "2012", (
  "Messaufbau im Labor betreut: Geräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "In einem Forschungsumfeld mit geteilten Rechnern, Datenablage und dokumentierten Auswertungen gearbeitet — Rechner, die Forschende nutzen, ohne Administratoren zu sein",
  "Messdaten und Auswertungen nachvollziehbar abgelegt, damit Ergebnisse über die Projektlaufzeit hinaus prüfbar bleiben",
))

#section("Projekte")
#entry("nixconfig — ein Bestand, einmal beschrieben", "seit 2023", (
  "Ein Host registriert sich einmal als Feature-Liste; Prüfungen, Aufgabenmenü und Dokumentation entstehen aus derselben Beschreibung",
  "Netz und Zugriff sind Teil der Beschreibung: Adressen, Tunnel, Regeln, Zertifikate",
  "Veröffentlichen, Ausrollen und Rückrollen sind Aufgaben, keine Eingriffe auf dem Host",
))

#section("Arbeitsweise")
#text(size: 9.5pt)[
  - Erst beschreiben, dann ändern: ein Netz, das nur in Handarbeit existiert, lässt sich nicht wiederherstellen. \
  - Erst messen, dann urteilen: ohne Vorher-Nachher-Wert ist eine Änderung eine Vermutung. \
  - Aufschreiben, was war: Adressierung, Regeln und Vorfälle gehören in die Dokumentation, nicht ins Gedächtnis.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Netz] — IPv4, DNS, WireGuard, nftables, VLAN-freie Standortkopplung, TLS mit eigener Zertifizierungsstelle, Fernzugriff ohne öffentliche Dienste \
#text(weight: "bold")[Linux] — Debian-nah über NixOS, systemd, cgroups, Namespaces, PSI, Boot und Wiederherstellung, PXE-Installation \
#text(weight: "bold")[Betrieb] — Monitoring mit Zustellbestätigung, Störungsbearbeitung, restic mit geprüften Rückspielungen, Rückrollung über Generationen \
#text(weight: "bold")[Automatisierung] — Nix-Flakes als reproduzierbare Beschreibung, CI/CD über Gates, Python, Go, Shell \
#text(weight: "bold")[Nicht vorhanden] — kommerzielle Firewall-Appliances, WAN-Routing (BGP, OSPF, MPLS), Glasfaser- und QKD-Technik, Steuerung externer Dienstleister, 2nd-/3rd-Level-Support in einer Organisation \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Umzug nach Erfurt möglich
