// Biz Factory GmbH — Systemadministrator / DevOps Engineer. Deutsches Anschreiben, eine Seite.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.32cm)
#text(size: 8.6pt, fill: muted)[22. November 2026]
#v(0.32cm)
Biz Factory GmbH #linebreak() z. Hd. Robin

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Bewerbung als Systemadministrator / DevOps Engineer – Linux- und Kubernetes-basierte OSS-Infrastrukturen]
#v(0.32cm)

Hallo Robin,

ich betreibe eine NixOS-Flotte als einen Flake: jeder Host eine Feature-Liste, jeder Dienst ein Modul mit systemd-Unit und
definiertem Fehlerverhalten, Secrets mit sops hinter einer eigenen Zertifizierungsstelle, jede Generation mit einem Befehl
zurückrollbar. Rebuilds laufen über einen gemeinsamen Binary-Cache und Remote-Builder, die CI führt dasselbe Gate je Host aus wie die
Maschine selbst, und ein Sentinel schreibt alle fünfzehn Minuten Jobstatus, Generation Age, Disk- und PSI-Druck in ein Ledger und
alarmiert, wenn ein Dienst aufhört zu melden. Das ist die Sorte Betrieb, die ihr für Kunden aufsetzt — kleiner, aber mit denselben
Fehlerbildern: Cache-Misses, Builder-Kapazität, und ein Rollback, der am schlechten Tag funktionieren muss.

Datenbanken und Dienste betreibe ich im Alltag: PostgreSQL mit Migrationen und einem Wiederherstellungsweg, den ich gegangen bin, ein
Mail-Archiv, das seine Post selbst klassifiziert, und ein Ledger, das denselben POST zweimal annimmt, ohne die Zeile zu duplizieren.
Go trägt die Dienste, Python die Werkzeuge. Monitoring mache ich nicht mit Icinga oder Nagios, sondern mit einem eigenen Ledger und
Gatus; die Frage ist dieselbe: Meldet der Dienst noch, und was heißt grün? Dass Open Source hier Geschäftsmodell ist und nicht
Marketing, ist der Grund, warum ich mich bei euch bewerbe.

Was ich nicht mitbringe, sage ich vorher: SLES- und RHEL-Betrieb, OpenShift und OpenStack, Kubernetes im Produktivcluster sowie
GitLab CI und LDAP/Active Directory habe ich nicht als eigene Verantwortung geführt. Ich sage das lieber jetzt als in der dritten
Woche. Was ich mitbringe, ist tiefer Linux-Betrieb, Automatisierung als Code statt als Checkliste, Datenbankbetrieb und die
Helpdesk-Haltung aus eurer Ausschreibung: Runbook, Dokumentation, Schulung und ein Ticket, das nicht zweimal aufgemacht werden muss.

100 Prozent remote passt; ich bin in Deutschland mit Niederlassungserlaubnis, also keine Visumsfrage. Meine Gehaltsvorstellung liegt
bei 84.000 Euro brutto, Eintritt ab 01.12.2026. Das Repository ist die ehrliche Version des Betriebs:
https://github.com/shaoyanji/nixconfig

Viele Grüße,
#v(0.4cm)
Matt Ji
