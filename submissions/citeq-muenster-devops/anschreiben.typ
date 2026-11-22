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
Wenn eine Stadt ihre Anträge, Formulare und Fachverfahren über eine IT betreibt, dann ist Betrieb dort keine Nebensache, sondern die Bedingung dafür, dass Verwaltung überhaupt funktioniert. Genau diesen Teil der Arbeit habe ich fünf Jahre lang gemacht: dreizehn Server, drei Hardware-Generationen, jeder Dienst als Modul beschrieben, jede Änderung als Commit, jedes Gate vor dem Ausrollen dieselbe Prüfung wie in CI.

#v(2pt)
Konkret: Die Infrastruktur steht deklarativ in einem Repository, nicht in gewachsenen Handgriffen. Jede Änderung ist nachvollziehbar, prüfbar und lässt sich auf die vorherige Generation zurückrollen, was bei Diensten ohne Wartungsfenster der einzige Weg ist, abends ruhig zu schlafen. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Zustellung passiert ist. Gesichert wird mit restic, und ich stelle wieder her, statt den Job zu prüfen. Geheimnisse liegen in sops und age, Host-Schlüssel in einer eigenen Zertifizierungsstelle mit kurzlebigen Zertifikaten, und kein Dienst hängt mit öffentlicher Schnittstelle im Netz. Wo Shell nicht reicht, schreibe ich Go oder Python; ein Router für Modellanfragen und mehrere Betriebswerkzeuge stammen aus dieser Arbeit.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: keinen Kubernetes- oder OpenShift-Betrieb, kein Docker im Produktivbetrieb, kein Ansible und kein Terraform. Meine Automatisierung ist deklarative Konfiguration plus Git, nicht die übliche Werkzeugkette; die Konzepte sind dieselben, die Befehle nicht. Auch mit kommunaler Beschaffung, Vergaberecht und den Formalien des öffentlichen Dienstes habe ich keine Erfahrung, und vom Web-Betrieb im Sinne mehrerer Fachverfahren kenne ich nur die eigene, kleinere Flotte. Diese Einarbeitung wäre echt.

#v(2pt)
Zur Lage: Von Gutach im Breisgau nach Münster sind es rund sechs Stunden, ein Umzug käme für mich frühestens nach einer erprobten Zeit in Frage. Die Anzeige nennt hybrid und remote; wie viel Präsenz das Team tatsächlich erwartet, ist deshalb die eine Frage, die ich vor einer Zusage klären müsste, und ich frage sie lieber jetzt als nach dem Vertrag. Reisen zu Abstimmungen sind kein Hindernis. Vergütung ist bei E 9a bis E 11 tariflich; meine Erwartung liegt am oberen Ende dieser Spanne und wird nicht als Zahl verlangt. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
