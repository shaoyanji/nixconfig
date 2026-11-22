#set document(title: "Matt Ji — Lebenslauf", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.6cm, bottom: 1.6cm, left: 1.9cm, right: 1.9cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 11.5pt, fill: rgb("#111827"), lang: "de", hyphenate: false)
#set par(leading: 0.70em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Senior Linux Operations / Plattformbetrieb]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Fünf Jahre allein verantworteter Linux-Betrieb: dreizehn Hosts, systemd-Dienste, nftables, WireGuard zwischen den Standorten, sops-verschlüsselte Secrets und eine eigene SSH-Zertifizierungsstelle. Jeder Host ist deklariert — Kernelpaket, Initrd-Module, Firmware, Dienste, Firewall, Zugriffsrechte —, deshalb ist ein Rebuild der Commit plus ein Befehl, und die Rückkehr zur vorigen Generation ist Routine. Ein Sentinel protokolliert Jobstatus, Generation-Alter, Disk- und PSI-Druck alle fünfzehn Minuten und alarmiert erst, wenn die Zustellung bestätigt ist. Ansible gehört nicht zu dieser Erfahrung, eine konzernweite Plattform für 11.000 Nutzende ebenso wenig; beides steht im Anschreiben.]

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
  "Dreizehn Linux-Hosts über drei Hardware-Generationen: Installation über das Netz, Datenträger, Dienste, Netz, Zugriffsrechte, von der Beschaffung bis zur Übergabe an den Betrieb",
  "Kernel und Boot je Host gepinnt: Kernelpaket, Initrd-Module, Mikrocode und Firmware stehen im Host und nicht in einer Notiz; ein Wechsel ist ein Commit mit Rückrollweg",
  "systemd als Betriebsschicht: Dienste, Timer, Abhängigkeiten und Sandbox-Optionen deklariert statt von Hand nachgezogen",
  "Mehrere Standorte in einem Bestand, WireGuard zwischen ihnen, DNS und Zertifikate aus der eigenen Stelle, keine öffentlich erreichbare Verwaltung",
  "Wartung automatisiert: gepinnte Updates, Zustandsprüfung alle fünfzehn Minuten, Alarmierung mit Zustellbestätigung; Disk- und PSI-Druck als Messwert statt als Eindruck",
  "Sicherungen mit restic und geprüfte Rückspielungen; Werkzeuge für Rollout, Auswertung und Bericht in Python, Go und Bash",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Software und IT-Administration des Unternehmens und seiner Tochtergesellschaften verantwortet",
  "Betriebs- und Ertragsdaten ausgewertet und als Entscheidungsgrundlage aufbereitet",
))
#entry("Fraunhofer ISE — Wissenschaftliche Hilfskraft", "2012", (
  "Messaufbau im Labor betreut: Laborgeräte über C++-Anwendungen angesteuert, Messreihen in Python ausgewertet",
))

#section("Projekte")
#entry("nixconfig — dreizehn Hosts aus einem Repository", "seit 2023", (
  "Feature-Liste je Host, Modul je Dienst; ein Gate prüft Module und Assertions, bevor etwas auf eine Maschine geht",
  "Sentinel-Ledger über Jobstatus, Generation-Alter, Disk- und PSI-Druck, ausgewertet in Python und Go; Alarmierung erst nach bestätigter Zustellung",
  "Secrets mit sops verschlüsselt, Host-Schlüssel über die eigene Zertifizierungsstelle, Dienste hinter einem Tailnet ohne öffentliche Schnittstelle",
))
#entry("fleet-sentinel — Telemetrie, die eine Aussage trägt", "", (
  "Ein Dienst je Messreihe: Jobstatus, Generation-Alter, Disk- und PSI-Druck werden fortgeschrieben statt in Diagrammen vergessen",
  "Grenzwerte stehen im Bestand und ändern sich mit einem Commit; alarmiert wird nur, was sie überschreitet",
  "Zustellbestätigung als Bedingung: eine Warnung gilt erst als gemeldet, wenn die Nachricht angekommen ist",
))
#entry("Betriebshandbuch als Build-Artefakt", "seit 2023", (
  "Dokumentation, Aufgabenmenü und Prüfungen entstehen aus dem Bestand; ein Runbook je Verfahren, damit Betriebswissen nicht an einer Person hängt",
))

#section("Arbeitsweise")
#text(size: 10pt)[
  - Erst messen, dann ändern: keine Datei auf einem Host von Hand, jede Änderung durch den Bestand und dort geprüft. \
  - Prüfen statt hoffen: Gates vor dem Rollout, Rückspielen von Sicherungen geübt, Alarmzustellung bestätigt. \
  - Aufschreiben, was getan wurde: was nicht im Repository steht, existiert beim nächsten Vorfall nicht.
]

#section("Ausbildung")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Erneuerbare-Energien-Management", "2011 – 2014", ("Abschlussnote 1,8; Modellierung mit neuronalen Netzen, Energiewirtschaft, Technikfolgenabschätzung",))
#entry("Colorado School of Mines — B.Sc. Erdöltechnik", "2006 – 2010", ("GPA 3,2",))

#section("Kenntnisse")
#text(weight: "bold")[Systembetrieb] — Linux-Hosts, systemd-Dienste und Timer, Kernel- und Initrd-Module, Mikrocode und Firmware, Speicher- und Prozessdruck, Boot und Wiederherstellung \
#text(weight: "bold")[Netz] — nftables, WireGuard zwischen Standorten, DNS, Zertifikate, eigene Zertifizierungsstelle, Fernzugriff ohne öffentliche Dienste \
#text(weight: "bold")[Automatisierung] — deklarierter Bestand, Gates vor dem Rollout, Rückrollung über Generationen, gemeinsamer Binary-Cache \
#text(weight: "bold")[Telemetrie] — Sentinel-Ledger, PSI- und Disk-Druck, Jobstatus, Alarmierung mit Zustellbestätigung, Auswertung in Python und Go \
#text(weight: "bold")[Skripte] — Python, Bash, Go \
#text(weight: "bold")[Nicht vorhanden] — Ansible im Produktivbetrieb, Checkmk, ElasticSearch, konzernweites LDAP und IAM, Betrieb einer Plattform für 11.000 Nutzende \
#text(weight: "bold")[Sprachen und Status] — Deutsch C1, Englisch Muttersprache · Niederlassungserlaubnis · Karlsruhe gut erreichbar, bis zu zwei mobile Tage
