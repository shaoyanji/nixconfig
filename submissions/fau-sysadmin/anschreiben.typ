#set document(title: "Bewerbung FAU LFT — IT-Systemadministrator", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  Friedrich-Alexander-Universität Erlangen-Nürnberg \
  Lehrstuhl für Fertigungstechnologie (LFT) \
  Herrn Gunar Tochtermann \
  Egerlandstraße 11-13 \
  91058 Erlangen
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als IT-Systemadministrator Linux und Windows (m/w/d), Kennung 2015]

#v(4pt)
Sehr geehrter Herr Tochtermann,

#v(2pt)
Ein Lehrstuhl mit drei Standorten, Werkstattmaschinen in der einen Halle und Workstations in der anderen: Wer dort die IT betreut, muss Wege kennen, nicht nur Hostnamen. Ich habe fünf Jahre lang genau das getan, mit dreizehn Rechnern statt einer Institutsflotte. Davor war ich 2012 wissenschaftliche Hilfskraft am Fraunhofer ISE in Freiburg und weiß deshalb, wie Forschung mit Rechentechnik umgeht: Messreihen laufen über Nacht, ein Ausfall wird nicht als Ticket erlebt, sondern als verlorene Woche.

#v(2pt)
Meine Praxis ist Linux: dreizehn NixOS-Hosts über drei Hardware-Generationen, jeder Dienst ein Modul, jeder Host eine Feature-Liste. Zugriffsrechte sind als Rollen deklariert statt von Hand gepflegt, Netz und Firewall liegen als Code mit nftables daneben, DNS und ein WireGuard-Tailnet verbinden die Standorte. Gesichert wird mit restic auf ein NAS, und Wiederherstellungen prüfe ich, statt sie anzunehmen. Ein Sentinel-Ledger schreibt alle 15 Minuten Jobstatus, Generation-Alter sowie Disk- und PSI-Druck, Gatus prüft Endpunkte, eine Go-Bridge bestätigt einen Alarm erst bei echter Zustellung. Software installiere ich reproduzierbar aus einer gepinnten Beschreibung, und Nutzende betreue ich direkt: Konten, Schlüssel, Zugänge, Hard- und Softwarefragen, dazu Runbooks, die auch ohne mich funktionieren.

#v(2pt)
Windows ist bei mir Workstation-Ebene, nicht Serverseite. Windows Server 2019, 2022 und 2025, Active Directory, Group Policies, Hyper-V und Lizenzserver habe ich nicht administriert; CAD- und FE-Betreuung im Institutsmaßstab fehlt mir ebenfalls. Ich schreibe das offen, weil die Stelle beides verlangt und ein Gespräch schneller klärt, was einarbeitbar ist. Was ich mitbringe: Linux bis zur systemd-Unit, Speicherung und Sicherung mit geprüften Rücksicherungen, Netzdienste, Beschaffung nach Richtlinien und die Gewohnheit, Wissen aufzuschreiben statt im Kopf zu halten.

#v(2pt)
Deutsch ist bei mir C1, Englisch Muttersprache; das Studium in Freiburg war deutschsprachig, die Arbeit bei Fraunhofer ISE ebenfalls. Die Stelle ist als Nachfolge der IT-Leitung angelegt, und Verantwortung für Menschen und Budget ist für mich eine Perspektive, keine Last. Hybrid nach der Einarbeitung passt, der Start zum 15.02.2027 ist machbar. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
