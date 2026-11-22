#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux-Systemadministration, Netze und Betriebssicherheit]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Anwenderbetreuung, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen vollständig aus der Ferne: Netze und Firewall als Code, Zugang nur über ein WireGuard-Tailnet, kein Dienst mit öffentlicher Schnittstelle. Überwacht mit einem Sentinel-Ledger alle 15 Minuten, prüft Endpunkte mit Gatus und bestätigt eine Alarmzustellung erst, wenn die Nachricht ankommt. Sichert mit restic und führt Wiederherstellungen durch; jede Änderung läuft über ein Gate und lässt sich auf die vorherige Generation zurückrollen. Leittechnik, SCADA, Video- und Audiosysteme, KVM-Matrizen, KRITIS, NIS-2 und ISO 27001 sind nicht Teil dieser Erfahrung. Deutsch C1, Englisch Muttersprache.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(5pt)
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
  #v(3pt)
]

#section("Berufserfahrung")
#entry("Bountystash — Gründer", "2020 – 2025", (
  "Betrieb dreizehn NixOS-Hosts über drei Hardware-Generationen und mehrere Standorte, inklusive Beschaffung, Installation und Inbetriebnahme",
  "Konfigurierte Netz und Firewall als Code mit nftables, dazu DNS und ein WireGuard-Tailnet; kein Dienst mit öffentlicher Schnittstelle",
  "Hielt die Flotte aus der Ferne verfügbar und leitete andere bei der Bedienung an, statt vor Ort zu reparieren",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Sicherte Daten mit restic auf ein NAS und führte Wiederherstellungen durch, statt sich auf den Sicherungsjob zu verlassen",
  "Führte jede Änderung über ein Gate mit Rückrollung auf die vorherige Generation, auch bei Diensten ohne Ausfallfenster",
  "Härtete Dienste über systemd-Optionen und Ressourcenlimits und hielt Speicherdruck im Blick, statt Ausfälle nachträglich zu erklären",
  "Verwaltete Geheimnisse mit sops und age und Host-Schlüssel über eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten",
  "Dokumentierte jede Prozedur als Runbook und als Task im Repository, damit Wissen nicht in Köpfen bleibt",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
  "Dokumentierte technische Anlagen und erstellte Finanzmodelle für 10 MW Solar-PV",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
  "Schrieb C++-Anwendungssoftware zur Anbindung der Laborgeräte und Python-Werkzeuge für Analyse und 3D-Geometrie",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig", "seit 2023", (
  "Deklarierte die Flotte in einem Flake, sodass jede Änderung prüfbar ist und jede Generation zurückgerollt werden kann",
  "Ließ in CI dasselbe Modul-Gate je Host laufen wie auf den Maschinen, dazu ein Sentinel-Ledger aus Job-Status, Generation-Alter, Disk- und PSI-Druck",
  "Betrieb eine autarke KI-Plattform auf eigener Hardware mit Modellserver, Go-Router und Zugang nur über das Tailnet",
))

#section("Kenntnisse")
#text(weight: "bold")[Systeme] — NixOS und Debian-nah, systemd, Boot-Konfiguration, reproduzierbare Installation, Ressourcenlimits \
#text(weight: "bold")[Netzwerk] — nftables, DNS, WireGuard, Adressierung und Segmentierung, Fehlersuche mit tcpdump und ss \
#text(weight: "bold")[Verfügbarkeit] — JSONL-Ledger, Gatus, Zustellbestätigung, restic, geprüfte Wiederherstellungen, Rückrollung \
#text(weight: "bold")[Sicherheit] — sops, age, eigene SSH-Zertifizierungsstelle, kurzlebige Zertifikate, keine offene Schnittstelle \
#text(weight: "bold")[Automatisierung] — Shell, Python, Go, Git als einzige Quelle, CI \
#text(weight: "bold")[Nicht vorhanden] — SCADA/Leittechnik, Video- und Audiotechnik, KVM-Matrix, KRITIS/NIS-2/ISO 27001, Verkehrstechnik \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache
