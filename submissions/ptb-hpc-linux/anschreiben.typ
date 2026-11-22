#set document(title: "Bewerbung PTB — Linux-Systemadministration HPC", author: "Matt Ji")
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
  Physikalisch-Technische Bundesanstalt \
  Referat 9.55 Hochleistungsrechnen \
  Herrn Dr. Daniel Lübbert \
  Abbestraße 2-12 \
  10587 Berlin
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Linux-Systemadministrator (m/w/d) - High-Performance Computing und Compute-Server, Kennziffer 26-163-9C]

#v(4pt)
Sehr geehrter Herr Dr. Lübbert,

#v(2pt)
Ein Cluster, der für Forschende rechnet, und ein Team, das dafür sorgt, dass niemand wegen der Infrastruktur eine Messreihe neu startet: Das ist Betrieb mit Nutzerkontakt, und so habe ich die letzten fünf Jahre gearbeitet. Dreizehn Server, drei Hardware-Generationen, jeder Dienst ein Modul, jede Änderung ein Commit mit Gate und Rückrollung. Dass Referat 9.55 Compute-Server und ein HPC-Cluster als Dienstleistung für die Fachabteilungen betreibt, ist genau die Rolle, in der ich mich bewege, und die Forschungsumgebung kenne ich von innen: 2012 war ich am Fraunhofer ISE.

#v(2pt)
Konkret: Zugriffsrechte sind als Rollen je Host deklariert statt von Hand gesetzt, und der Betrieb läuft automatisiert in Shell, Python und Go. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Zustellung passiert ist. Gesichert wird mit restic auf ein NAS, und ich führe Wiederherstellungen wirklich durch, statt den Job zu prüfen. Dienste sind über systemd-Optionen und Ressourcenlimits begrenzt, Geheimnisse liegen in sops und age, Host-Schlüssel kommen aus einer eigenen Zertifizierungsstelle mit kurzlebigen Zertifikaten, und kein Dienst hängt ungeschützt im Netz. Dokumentation ist Runbook, nicht Erinnerung.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: Slurm habe ich nicht betrieben, keine parallelen Programmiermodelle wie MPI oder OpenMP, keine verteilten Dateisysteme wie Lustre oder GPFS, kein Proxmox und kein Ansible; meine Automatisierung ist Nix und Git. Eine formale BSI-Umsetzung habe ich nicht, nur die Hygieneseite davon gelebt. Ich schreibe das vorher, weil ein HPC-Referat keine Zeit hat, eine Lücke erst im Betrieb zu entdecken. Was ich mitbringe: Linux bis zur systemd-Unit, reproduzierbare Installationen, Rechte als Code, Telemetrie mit echter Alarmzustellung und die Gewohnheit, Wissen aufzuschreiben.

#v(2pt)
Deutsch ist bei mir C1, Englisch Muttersprache; das Studium in Freiburg war deutschsprachig, die Arbeit bei Fraunhofer ISE ebenfalls. Ich bin US-Amerikaner mit deutscher Niederlassungserlaubnis, benötige kein Visum und bin bereit, die Sicherheitsüberprüfung nach § 9 SÜG zu durchlaufen. Dienstreisen sind kein Hindernis. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
