#set document(title: "Bewerbung DFS — Ingenieur Site Reliability", author: "Matt Ji")
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
  DFS Deutsche Flugsicherung GmbH \
  Frau Jessica Kuprat \
  Am DFS Campus 1 \
  63225 Langen
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Ingenieur Site Reliability (m/w/d), Referenz J000000038]

#v(4pt)
Sehr geehrte Frau Kuprat,

#v(2pt)
Wer den Luftraum kontrolliert, kann sich keinen Dienst leisten, der nur meistens erreichbar ist. Deshalb lese ich die Anzeige als Zusage an eine andere Art von Betrieb: Servicearchitekturen über den gesamten Lifecycle, Plattformen, die man selbst weiterentwickelt, und Nutzende, die man berät, statt Tickets zu schließen. Genau so habe ich fünf Jahre lang gearbeitet, mit dreizehn Servern, drei Hardware-Generationen und einer Flotte, die als Code existiert und nicht als Gewohnheit.

#v(2pt)
Konkret verantworte ich die Dienste, die eine Plattform erst benutzbar machen: eigener DNS, WireGuard-VPN, nftables als Firewall-Code, Segmentierung ohne öffentliche Schnittstelle, Reverse Proxy vor den Anwendungen. Jeder Dienst ist ein Modul, jede Änderung ein Commit, und das Gate, das in CI läuft, ist dasselbe, das den Ausrollvorgang schützt; jeder Stand bleibt als Generation erhalten und lässt sich zurückrollen. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Nachricht ankommt. Gesichert wird mit restic, und ich stelle wieder her, statt den Job zu prüfen. Automatisierung und Werkzeuge schreibe ich in Python und Go.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: kein Ansible, kein Kubernetes und keine Container-Orchestrierung im Betrieb, keine Cloud-Services und keine Rechenzentrumsplattform in dieser Größe, kein Windows Server und keine Microsoft Services. Meine Automatisierung ist deklarative Konfiguration plus Git; die Konzepte sind dieselben, die Werkzeuge nicht. Diese Einarbeitung wäre echt, und ein Bereich mit dieser Verantwortung sollte sie nicht für eine Fußnote halten.

#v(2pt)
Zur Verantwortung in einer kritischen Infrastruktur bin ich bereit, und zur Sicherheitsüberprüfung willige ich ein. Rufbereitschaft ist für mich selbstverständlich, nicht Zumutung. Langen ist von Gutach im Breisgau rund dreieinhalb Stunden entfernt; ein Umzug in die Rhein-Main-Region wäre für diese Stelle Teil der Entscheidung, nicht ein Detail am Rand. Zwei Punkte kann ich hier nicht zusagen, weil sie Nachweise brauchen und nicht Absichten: die medizinische Tauglichkeit und der Führerschein der Klasse B. Beides kläre ich gern vor einem Gespräch, statt es im Formular zu behaupten. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
