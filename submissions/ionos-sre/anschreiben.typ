#set document(title: "Bewerbung IONOS — Site Reliability Engineer", author: "Matt Ji")
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
  IONOS SE \
  Application Hosting Team \
  Hinterm Hauptbahnhof 3-5 \
  76137 Karlsruhe
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Site Reliability Engineer (f/m/d), Kennziffer 1585]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Eine Plattform, die Nextcloud, Workspace und IONOS GPT für Millionen Kunden trägt, hat ein anderes Problem als ein einzelner Server: Es ist nicht die Frage, ob etwas ausfällt, sondern ob man es merkt, bevor die Kundschaft es merkt, und ob man es zurücknehmen kann, ohne den Tag zu verlieren. Genau für diese Frage habe ich fünf Jahre lang die Infrastruktur gebaut, die sie beantwortet — dreizehn Server, drei Hardware-Generationen, jeder Dienst als Modul, jede Änderung als Commit.

#v(2pt)
Konkret: Das Gate, das in CI läuft, ist dasselbe, das den Ausrollvorgang schützt; jeder Stand bleibt als Generation erhalten und lässt sich zurückrollen statt vorwärts reparieren. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Nachricht ankommt. Dienste sind über systemd-Limits begrenzt, Speicherdruck ist eine Messgröße erster Ordnung, Sicherungen laufen mit restic und werden durch Wiederherstellungen geprüft. Und ein Teil der Arbeit ist inhaltlich nah an IONOS GPT: Ich betreibe eine KI-Plattform auf eigener Hardware mit Modellserver und Go-Router, erreichbar nur über ein Tailnet — kleiner Maßstab, dieselbe Sorte Dienst.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: keinen Kubernetes-Betrieb, kein Terraform, kein ArgoCD, keine GitLab-CI-Pipelines, keinen Prometheus-Grafana-ELK-Stack. Meine Automatisierung ist deklarative Konfiguration plus Git, mein Monitoring ein eigenes Ledger. Die Konzepte sind dieselben, die Werkzeuge nicht, und ein Hosting-Anbieter mit diesem Lastprofil sollte das vorher wissen statt in der Probezeit. Was ich mitbringe: Linux bis zur systemd-Unit, Automatisierung als Haltung, Telemetrie, die auch unter Ressourcenknappheit trägt, Störungsdiagnose aus Daten und die Gewohnheit, Betriebswissen aufzuschreiben.

#v(2pt)
Karlsruhe ist von Gutach im Breisgau rund anderthalb Stunden entfernt; mit hybridem Modell und Vertrauensarbeitszeit ist Präsenz bei Bedarf für mich kein Problem, ein Umzug in die Region wäre nach einer erprobten Zeit denkbar. Deutsch ist bei mir C1, Englisch Muttersprache. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
