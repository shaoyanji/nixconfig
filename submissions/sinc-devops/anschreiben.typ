#set document(title: "Bewerbung SINC — DevOps Engineer", author: "Matt Ji")
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
  SINC GmbH \
  Frau Jenni Holdmann, Recruiting \
  Wiesbaden
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als DevOps Engineer (m/w/d), SINC-ID 63891414]

#v(4pt)
Sehr geehrte Frau Holdmann,

#v(2pt)
Eine interne Plattform ist der Ort, an dem sich zeigt, ob eine Organisation ihre eigenen Werkzeuge ernst nimmt: Wenn Entwicklungs- und Testteams auf Umgebungen warten, ist nicht die Software langsam, sondern der Betrieb. Genau diesen Teil habe ich fünf Jahre lang verantwortet — dreizehn Server, drei Hardware-Generationen, Umgebungen, auf die sich andere verlassen mussten, und eine CI, deren Gate vor dem Ausrollen dasselbe war wie im Repository.

#v(2pt)
Konkret: Die Infrastruktur steht deklarativ in einem Repository, jeder Dienst ist ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit. Jeder Stand bleibt als Generation erhalten und lässt sich zurückrollen, statt einen Fehler vorwärts zu reparieren. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Nachricht ankommt. Automatisiert wird in Bash, Python und Go; Geheimnisse liegen in sops und age, Host-Schlüssel kommen aus einer eigenen Zertifizierungsstelle mit kurzlebigen Zertifikaten, und Supportanfragen endeten als Runbook statt als Zuruf.

#v(2pt)
Dass diese Plattform öffentlichen Institutionen dient, ändert die technische Anforderung nicht, aber die Folge: Wenn eine Umgebung steht, stehen Menschen ohne Ausweichweg davor. Deshalb sind Rückrollung, nachvollziehbare Änderungen und Runbooks für mich keine Kür, sondern der Teil des Betriebs, der über Vertrauen entscheidet — und der Grund, warum ich Zustellbestätigung nicht als Detail behandele.

#v(2pt)
Was ich nicht mitbringe, sage ich vor der ersten Zeile Ihres Stack-Abschnitts: keinen Windows-Server-Betrieb, kein Hyper-V, kein OpenStack, kein Oracle oder Microsoft SQL, kein PowerShell, kein C\#, kein Azure DevOps, kein Docker, kein Kubernetes, kein Helm. Meine Welt ist Linux und deklarative Konfiguration; Ihr Betrieb ist überwiegend Windows und Virtualisierung. Diese Einarbeitung wäre echt und breit, und ein internes Plattformteam merkt das in der ersten Woche.

#v(2pt)
Zur Person: Ich bin US-Amerikaner mit unbefristetem Niederlassungsrecht in Deutschland, benötige kein Visum und arbeite seit Jahren hier. Meine Gehaltsvorstellung liegt bei 80.000 bis 88.000 EUR brutto im Jahr. Wiesbaden ist von Gutach im Breisgau rund 250 km entfernt; mit bis zu 60 % Homeoffice sind zwei Präsenztage pro Woche mit Übernachtung für mich realistisch, ein Umzug wäre nach einer erprobten Zeit denkbar, aber nicht die Voraussetzung. Deutsch ist bei mir C1, Englisch Muttersprache.

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
