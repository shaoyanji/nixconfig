#set document(title: "Bewerbung BWI — Cloud Engineer (m/w/d), Stellen-ID 67851", author: "Matt Ji")
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
  BWI GmbH \
  Frau Kristin Reichmann \
  POD 2 Cloud & Platform \
  Stellen-ID 67851
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Cloud Engineer (m/w/d), Stellen-ID 67851]

#v(4pt)
Sehr geehrte Frau Reichmann,

#v(2pt)
Ihre Abteilung POD 2 Cloud & Platform baut eine private Cloud-Plattform, und gesucht wird jemand, der Infrastruktur als Code versteht. Genau so betreibe ich meine Flotte: dreizehn NixOS-Hosts in einem Repository, jeder Host eine Feature-Liste, jeder Dienst ein Modul, Netz und Firewall deklarativ. Eine Server-Generation entsteht unveränderlich aus dem Repository, und ein Rollback ist ein Befehl, kein Eingriff auf der Maschine.

#v(2pt)
Provisioning und Rebuilds laufen ohne manuellen Schritt auf dem Host: gemeinsamer Binary-Cache, Remote-Builder, jede Abhängigkeit im Lock per Hash gepinnt, Builds in der Sandbox ohne Netzwerkzugriff. Vor dem Ausrollen prüfen Gates denselben Zustand, der ausgerollt wird — Modulprüfung je Host, sops-Drift, Oberflächen- und Linkchecks. Secrets stehen nicht dauerhaft im Betrieb: sops mit age, Zugang über die eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten. Ein Sentinel protokolliert Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten und alarmiert, wenn etwas ausfällt.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: keinen Produktivbetrieb von Kubernetes on premise, kein Terraform oder Ansible, keine Hochverfügbarkeits- und Failover-Architektur im Kundenmaßstab und keine Zertifizierung nach BSI Grundschutz. Meine Tiefe liegt bei Linux, systemd, deklarativer Infrastruktur, CI-Gates und Beobachtung. Die Prinzipien hinter Ihrer Plattform — reproduzierbar, unveränderlich, rückrollbar — sind die, nach denen ich seit fünf Jahren baue; die Werkzeuge darüber würde ich lernen müssen, und das ist echter Aufwand.

#v(2pt)
Zur Person: Deutsch C1, Englisch Muttersprache, US-Staatsangehörigkeit mit deutscher Niederlassungserlaubnis, keine Visumsunterstützung nötig. Bundesweit bin ich mobil, ein Standortwechsel ist verhandelbar, einer Sicherheitsüberprüfung stimme ich zu. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
