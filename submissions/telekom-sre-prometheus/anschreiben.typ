#set document(title: "Bewerbung T-Systems — Site Reliability Engineer", author: "Matt Ji")
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
  T-Systems International GmbH \
  Herrn Thomas Arbeit \
  Kennziffer 12444-563465374109756-DT-S
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Site Reliability Engineer (SRE) (m/w/d), Standort Karlsruhe]

#v(4pt)
Sehr geehrter Herr Arbeit,

#v(2pt)
Eine Fog-Node, die ohne verlässliche Verbindung arbeitet, ist der ehrlichste Prüfstein für Telemetrie: Wenn die Leitung wegfällt, entscheidet nicht das Dashboard, sondern ob die Daten lokal gehalten, verdichtet und nach der Rückkehr korrekt nachgeliefert werden. Genau unter dieser Bedingung habe ich fünf Jahre lang Betrieb gemacht, ohne es so zu nennen: dreizehn Server auf eigener Hardware, alles nur über ein WireGuard-Tailnet erreichbar, jede Maschine mit begrenztem Speicher und begrenzter CPU.

#v(2pt)
Konkret: Ein Sentinel-Job schreibt alle 15 Minuten Jobstatus, Generation-Alter sowie Disk- und PSI-Druck in ein JSONL-Ledger; die Retention entsteht durch Rotation, nicht durch Wachstum. Gatus prüft Endpunkte, und eine Go-Bridge bestätigt einen Alarm erst, wenn die Nachricht tatsächlich ankommt — ich halte den Unterschied zwischen ausgelöstem und zugestelltem Alarm für den Kern der Sache. Dienste sind über systemd-Optionen und Ressourcenlimits begrenzt, Speicherdruck ist eine Messgröße erster Ordnung, jede Änderung ist auf die vorherige Generation rückrollbar, Sicherungen laufen mit restic und werden durch Wiederherstellungen geprüft. Störungen diagnostiziere ich aus dem Ledger und den Systemlogs, bevor sie jemand meldet.

#v(2pt)
Was ich nicht mitbringe, sage ich vor der ersten Zeile Ihrer Must-Have-Liste: keinen Prometheus-Betrieb, kein PromQL, keine Federation, kein Remote Write, keine lokale Retention in Prometheus. Keine Grafana-Dashboards und kein Provisioning as Code, kein Loki und kein LogQL, kein AlertManager mit Routing und Inhibition, kein Kubernetes-Monitoring. Meine Konfiguration ist Nix, nicht YAML, und Terraform, Ansible und OpenTelemetry sind mir Werkzeugnamen, keine Praxis. Das ist die halbe Stelle, und ich sage es lieber jetzt als in der Einarbeitung.

#v(2pt)
Was ich mitbringe, ist die andere Hälfte und die, die man nicht in einem Kurs nachholt: die Gewohnheit, Telemetrie so zu bauen, dass sie unter Knappheit funktioniert und im Ernstfall trägt, plus die Fähigkeit, einen Stack wie Ihren schnell zu verstehen, weil ich seine Bausteine von Hand gebaut habe. Karlsruhe ist von Gutach im Breisgau rund anderthalb Stunden entfernt; hybrides Arbeiten mit Präsenz bei Bedarf ist für mich deshalb kein Zugeständnis, sondern die passende Form. Deutsch ist bei mir C1, Englisch Muttersprache. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
