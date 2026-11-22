#set document(title: "Bewerbung citeq — DevOps Engineer", author: "Matt Ji")
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
  citeq — IT-Dienstleister der Stadt Münster \
  Team Web-Entwicklung und -Betrieb \
  Scheibenstraße 109 \
  48153 Münster
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als DevOps Engineer (m/w/d), Ausschreibungsnummer 22-029/26]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Sie schreiben, das Configuration-Management mit Ansible solle nicht nur am Laufen gehalten, sondern weiterentwickelt werden. Das ist die Arbeit, die ich fünf Jahre lang gemacht habe, nur mit anderen Werkzeugen: dreizehn Server, drei Hardware-Generationen, jeder Dienst als Modul beschrieben, jeder Host als Feature-Liste, jede Änderung als Commit. Automatisierung ist dort kein Zusatz, sondern die einzige Art, wie die Flotte existiert.

#v(2pt)
Konkret: Jede Änderung läuft durch dasselbe Gate, das auch in CI läuft, und wird erst danach ausgerollt; jeder Stand bleibt als Generation erhalten und lässt sich zurückrollen, was bei Diensten ohne Wartungsfenster der einzige Weg ist, abends ruhig zu schlafen. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Zustellung passiert ist. Gesichert wird mit restic, und ich stelle wieder her, statt den Job zu prüfen. Geheimnisse liegen in sops und age, Host-Schlüssel in einer eigenen Zertifizierungsstelle mit kurzlebigen Zertifikaten, und kein Dienst hängt mit öffentlicher Schnittstelle im Netz. Wo Shell nicht reicht, schreibe ich Go oder Python.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher, weil das Team keine Zeit hat, es später zu merken: keinen Ansible-Betrieb, keine GitLab-CI-Pipelines, keine Docker-Images, keinen Prometheus-, Grafana- oder Graylog-Stack. Meine Werkzeuge heißen deklarative Konfiguration, Git, CI-Gates und ein eigenes Ledger; die Konzepte sind dieselben, die Befehle nicht. Auch Verwaltungsinformatik, kommunale Verfahren und Vergaberecht sind neu für mich. Was ich mitbringe: Linux bis zur systemd-Unit, den Blick für Verfügbarkeit und Sicherheit, die Gewohnheit, Betriebswissen aufzuschreiben, und die Bereitschaft, die genannten Werkzeuge zügig zu lernen, statt sie zu umschreiben.

#v(2pt)
Zur Lage: Von Gutach im Breisgau nach Münster sind es rund sechs Stunden. Die Anzeige nennt Homeoffice und Gleitzeit; Ihr Angebot, den Arbeitsplatz während der Bewerbungsfrist kennenzulernen, nehme ich gern wahr, und genau dabei würde ich klären wollen, wie viel Präsenz das Team tatsächlich erwartet. Ein Umzug käme für mich erst nach einer erprobten Zeit in Frage, nicht vorher. Die Eingruppierung reicht von E 9a bis E 11; ich bewerbe mich auf E 11, weil die Aufgaben Automation, Monitoring und Sicherheitsinfrastruktur umfassen. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
