#set document(title: "Bewerbung DKRZ — IT-Security-Systemadministrator", author: "Matt Ji")
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
  Deutsches Klimarechenzentrum GmbH \
  Abteilung Systeme \
  Bundesstraße 45a \
  20146 Hamburg
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als IT-Security-Systemadministrator (m/w/d)]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Eine wissenschaftliche Infrastruktur, die Klimamodelle für die nächsten Jahrzehnte rechnet, muss zwei Dinge gleichzeitig können: offen für Forschung sein und dicht gegenüber allem, was nicht dorthin gehört. Genau an dieser Grenze habe ich fünf Jahre gearbeitet. Ich betreibe dreizehn Linux-Server über drei Hardware-Generationen, vollständig als Code in Git, und ich habe die Absicherung dabei selbst gebaut, weil niemand sonst da war, der es getan hätte.

#v(2pt)
Konkret: Jeder Host ist eine Feature-Liste, jeder Dienst ein Modul, jede Änderung ein Commit mit Gate und Rückrollung. Vertrauen zwischen Maschinen läuft über eine eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, Geheimnisse liegen in sops und age, und kein Dienst hängt mit öffentlicher Schnittstelle im Netz. Dienste sind über systemd-Optionen und Ressourcenlimits gehärtet. Überwacht wird mit einem Sentinel-Ledger alle 15 Minuten, Gatus prüft Endpunkte, eine Go-Bridge bestätigt einen Alarm erst, wenn die Zustellung wirklich passiert ist. Gesichert wird mit restic auf ein NAS, und ich stelle Wiederherstellungen wieder her, statt sie anzunehmen. Werkzeuge schreibe ich in Bash, Python und Go, und ich dokumentiere, damit das auch andere können.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: IDS/IPS und SIEM habe ich nicht betrieben, also kein Wazuh, Elastic Stack oder Graylog. SELinux- und AppArmor-Profile habe ich nicht geschrieben, Schwachstellenmanagement, CVE-Bewertung, Schwachstellenscans und Incident Response sind keine Praxis aus einer Organisation, IT-Notfallkonzepte ebenso wenig. Ansible und Puppet sind nicht mein Werkzeug, Identity Management mit LDAP, FreeIPA oder Keycloak und föderierte Authentifizierung fehlen, Hochleistungsrechnen im Betrieb, OpenStack und Kubernetes ebenfalls. BSI IT-Grundschutz habe ich nicht umgesetzt, sondern nur die Hygieneseite davon gelebt. Die Anzeige verlangt einen Sicherheitsschwerpunkt; meine Stärke ist die Betriebs- und Automatisierungsseite davon.

#v(2pt)
Deutsch ist bei mir C1, Englisch Muttersprache, und ein Wechsel nach Hamburg ist machbar; hybrid passt zu meiner Arbeitsweise. Die Stelle ist vom 27. April und ohne Frist veröffentlicht; ich bewerbe mich, weil sie inhaltlich genau die Lücke zwischen Infrastruktur und Sicherheit beschreibt, in der ich arbeite. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
