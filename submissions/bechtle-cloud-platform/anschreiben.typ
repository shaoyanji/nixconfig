#set document(title: "Bewerbung Bechtle KubeOps — Cloud Platform Engineer", author: "Matt Ji")
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
  Bechtle AG — KubeOps \
  Herrn Christopher Waldraff, Recruiting \
  Bisingen
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Cloud Platform Engineer (w/m/d) (Remote), Job 72406]

#v(4pt)
Sehr geehrter Herr Waldraff,

#v(2pt)
Souveräne IT-Betriebsmodelle Made in Bisingen: Das ist für mich kein Schlagwort, sondern die einzige Art, wie ich Infrastruktur je betrieben habe. Dreizehn Server auf eigener Hardware, kein Managed Cloud, keine öffentliche Schnittstelle, alles über ein WireGuard-Tailnet — weil Verfügbarkeit und Datenhoheit dann nicht von einem Anbieter abhängen, sondern von dem, was man selbst gebaut und dokumentiert hat. Was KubeOps für den Public Sector mit Kubernetes tut, habe ich im Kleinen ohne Kubernetes getan.

#v(2pt)
Konkret: Die Plattform steht deklarativ in einem Repository, jeder Dienst ist ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit. Dasselbe Gate läuft in CI und vor dem Ausrollen; jeder Stand bleibt als Generation erhalten und lässt sich zurückrollen, statt einen Fehler vorwärts zu reparieren. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Nachricht ankommt. Automatisiert wird in Shell, Python und Go, Geheimnisse liegen in sops und age, Host-Schlüssel kommen aus einer eigenen Zertifizierungsstelle mit kurzlebigen Zertifikaten.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher, weil die Anzeige es als Bedingung nennt: keinen Kubernetes-Betrieb, kein Docker im Produktivbetrieb, kein Terraform, keine GitLab- oder GitHub-Pipeline, keine DevSecOps-Werkzeugkette und keine Private-Cloud-Projekte im Kundenumfeld. Meine Infrastruktur als Code ist Nix, meine Pipeline ist ein Gate in Git. Die Konzepte sind dieselben — Bereitstellung als Code, Prüfung vor dem Ausrollen, Rückrollbarkeit, Rechte und Geheimnisse als Teil der Plattform —, die Werkzeuge nicht. Diese Einarbeitung wäre echt.

#v(2pt)
Zur Sicherheitsüberprüfung SÜ2 bin ich bereit; ich bin US-Amerikaner mit deutscher Niederlassungserlaubnis, was den Ablauf betreffen kann, aber kein Hindernis für die Bereitschaft ist. Zum Modell: Bisingen liegt rund 140 km von Gutach im Breisgau, die 60-km-Schwelle ist damit deutlich überschritten und das Remote-Modell greift. Wie viele Präsenztage für Voll-Remote tatsächlich erwartet werden, würde ich gern im Gespräch klären, statt es anzunehmen. Deutsch ist bei mir C1, Englisch Muttersprache. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
