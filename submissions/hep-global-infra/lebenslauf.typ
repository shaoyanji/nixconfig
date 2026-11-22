#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.6cm, bottom: 1.6cm, left: 1.9cm, right: 1.9cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 11.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.70em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systembetrieb, Messtechnik und Automatisierung]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre allein verantworteter IT-Betrieb: dreizehn Linux-Server über drei Hardware-Generationen, Netz, Dienste, Sicherheitsupdates, Überwachung, Sicherungen. Davor kaufmännische Betreuung von 10 MW Solar-PV bei einem Projektentwickler, einschließlich der Software und IT des Unternehmens. Und davor, 2012, ein Messaufbau am Fraunhofer ISE: Laborgeräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet, Heliostat-Ungenauigkeiten interferometrisch vermessen. Diese Reihenfolge ist der Grund für dieses Schreiben: Ich kenne die Messkette von der Anlage bis zur Auswertung und betreibe die Systeme, auf denen sie läuft. Windows-Server, Active Directory, Entra ID und VMware habe ich nicht betreut; das steht auch im Anschreiben.]

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
  "Dreizehn Linux-Server über drei Hardware-Generationen: Installation über das Netz, Datenträger, Dienste, Netz, Zugriffsrechte, von der Beschaffung bis zur Übergabe an den Betrieb",
  "Mehrere Standorte und Netze in einem Bestand, WireGuard zwischen den Standorten, keine öffentlich erreichbare Verwaltung",
  "Wartung automatisiert: gepinnte Updates, Zustandsprüfung alle fünfzehn Minuten, Alarmierung, die erst nach bestätigter Zustellung als gemeldet gilt",
  "Sicherungen mit restic und geprüfte Rückspielungen; die Rückkehr zur vorigen Systemgeneration ist Routine, nicht Ausnahme",
  "Zustand deklarativ beschrieben und im CI derselbe Zustand geprüft, der ausgerollt wird; keine von Hand geänderte Datei auf einer Maschine",
  "Nutzende betreut, ohne Administrator zu sein: Rechte, Zugänge, Anleitungen, kurze Wege statt Ticketschlangen",
  "Werkzeuge in Python, Go und Shell für Rollout, Auswertung und Berichte",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Kaufmännische Betreuung von 10 MW Solar-PV-Anlagen: Finanzmodelle, Erträge, Kosten über die Laufzeit",
  "Software und IT-Administration des Unternehmens und seiner Tochtergesellschaften verantwortet",
  "Betriebs- und Ertragsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet; gesehen, was eine Anlage kostet, die weniger liefert als gerechnet",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Messaufbau im Labor betreut: Laborgeräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
  "Heliostat-Ungenauigkeiten mit Interferometrie vermessen und Geometriematrizen in Mathematica geprüft",
  "In einem Institut mit geteilten Rechnern, zentraler Datenablage und dokumentierten Auswertungen gearbeitet",
))

#section("Projekte")
#entry("nixconfig — ein Bestand, einmal beschrieben", "seit 2023", (
  "Ein Modul je Dienst, eine Feature-Liste je Host; ein Gate prüft Module und Assertions, bevor etwas auf eine Maschine geht",
  "Sentinel-Ledger über Jobstatus, Generation-Alter, Disk- und PSI-Druck alle fünfzehn Minuten, ausgewertet in Python und Go",
  "Dienste hinter einem Tailnet ohne öffentliche Schnittstelle, Zertifikate über die eigene Zertifizierungsstelle",
))

#section("Arbeitsweise")
#text(size: 10pt)[
  - Erst beschreiben, dann ändern: keine Datei auf einem Server von Hand, jede Änderung geht durch den Bestand und wird dort geprüft. \
  - Prüfen statt hoffen: Gates vor dem Rollout, Rückspielen von Sicherungen geübt, Alarmzustellung bestätigt. \
  - Aufschreiben, was getan wurde: ein Runbook je Verfahren, damit Betriebswissen nicht an einer Person hängt.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Systembetrieb] — Linux-Server, systemd, cgroups, Namespaces, Speicher- und Prozessdruck, Boot und Wiederherstellung \
#text(weight: "bold")[Netz] — nftables, WireGuard zwischen Standorten, DNS, Zertifikate, Fernzugriff ohne öffentliche Dienste \
#text(weight: "bold")[Wartung] — automatisierte Updates, Zustandsprüfung, Alarmierung mit Zustellbestätigung, restic mit geprüfter Rückspielung \
#text(weight: "bold")[Nix] — Flakes, Modulaufbau, gepinnte Eingaben, reproduzierbare Systeme, Rückrollung \
#text(weight: "bold")[Messdaten] — Geräteanbindung, Auswertung von Messreihen, Interferometrie, 3D-Geometrie, Python \
#text(weight: "bold")[Skripte] — Python, Go, Shell, C++; Auswertung, Berichte, Dokumentation \
#text(weight: "bold")[Nicht vorhanden] — Windows-Server, Active Directory, Entra ID, VMware und Hyper-V, Netzwerkhardware von Cisco, Ticketsysteme im Regelbetrieb \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Umzug nach Baden-Württemberg möglich
