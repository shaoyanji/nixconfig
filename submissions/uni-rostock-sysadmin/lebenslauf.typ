#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux- und Laborinfrastruktur, Netze, Betriebssicherheit]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux-Systemadministrator mit zehn Jahren Erfahrung in Betrieb, Automatisierung und Anwenderbetreuung, davon eine Forschungsstation am Fraunhofer ISE. Betreibt dreizehn Server über drei Hardware-Generationen als deklarierte Infrastruktur: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung. Arbeitet mit NixOS und Debian-nahen Systemen, systemd, Rechteverwaltung und reproduzierbaren Installationen. Stellt Web-Dienste hinter einem Reverse Proxy bereit, mit TLS über eine eigene Zertifizierungsstelle, und hält sie über ein WireGuard-Tailnet erreichbar, ohne öffentliche Schnittstelle. Sichert mit restic und führt Wiederherstellungen durch; überwacht mit einem Sentinel-Ledger alle 15 Minuten. Betreute Laborgeräte und Messdaten bereits wissenschaftlich. Windows-Server-Administration, Linux-Virtualisierung mit Proxmox oder KVM und RHEL sind nicht Teil dieser Erfahrung. Deutsch C1, Englisch Muttersprache.]

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
  "Deklarierte Plattform und Dienste in einem Flake: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit",
  "Stellte Web-Dienste hinter einem Reverse Proxy bereit, mit TLS über eine eigene Zertifizierungsstelle und kurzlebigen Zertifikaten",
  "Hielt alles über ein WireGuard-Tailnet erreichbar und keinen Dienst mit öffentlicher Schnittstelle",
  "Schrieb einen Sentinel-Job, der Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt",
  "Prüfte Endpunkte mit Gatus und band Alarmierung an eine Go-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt",
  "Sicherte mit restic auf ein NAS, führte Wiederherstellungen durch und begrenzte jeden Dienst über systemd-Limits",
  "Automatisierte Betrieb und Auswertung mit Shell, Python und Go und dokumentierte jede Prozedur als Runbook",
  "Betreute Nutzende bei Hard- und Softwarefragen und leitete sie bei der Bedienung der Dienste an",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Betreute Software und IT-Administration für das Unternehmen und seine Tochtergesellschaften",
  "Erstellte Finanzmodelle und betreute 10 MW Solar-PV-Anlagen",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Band Laborgeräte über C++-Anwendungssoftware an und wertete Messdaten mit Python aus",
  "Forschte zu Heliostat-Ungenauigkeiten mit Interferometrie am Institut für Solare Energiesysteme",
))

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschluss 1,8; Modellierung mit neuronalen Netzen",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Projekte")
#entry("nixconfig", "seit 2023", (
  "Deklarierte die Flotte in einem Flake mit Modulen je Dienst und Gates je Host; CI prüft denselben Zustand, der ausgerollt wird",
  "Ergänzte ein Sentinel-Ledger aus Job-Status, Generation-Alter, Disk- und PSI-Druck sowie eine Go-Bridge mit Zustellbestätigung",
  "Betrieb eine autarke KI-Plattform auf eigener Hardware mit Modellserver, Go-Router und Zugang nur über das Tailnet",
))

#section("Kenntnisse")
#text(weight: "bold")[Systeme] — NixOS und Debian-nah, systemd, Rechteverwaltung, Ressourcenlimits, reproduzierbare Installation, Desktop- und Notebook-Support \
#text(weight: "bold")[Netz und Web] — nftables, DNS, WireGuard, Reverse Proxy, TLS über eigene Zertifizierungsstelle \
#text(weight: "bold")[Betrieb] — Monitoring-Ledger, Gatus, Zustellbestätigung, restic mit geprüften Wiederherstellungen, Rückrollung je Generation \
#text(weight: "bold")[Wissenschaft] — Laborgeräteanbindung, Messdatenanalyse, C++, Python \
#text(weight: "bold")[Nicht vorhanden] — Windows-Server-Administration, Proxmox/KVM, RHEL, Hochschul-Verwaltungsverfahren \
#text(weight: "bold")[Sprachen] — Deutsch C1, Englisch Muttersprache
