#set document(title: "Bewerbung — Mittwald, DevOps Engineer Linux Hosting Platform", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig
]

#v(12pt)

#text(size: 9pt)[
  Mittwald CM Service GmbH & Co. KG \
  DevOps Engineer (m/w/d) — Linux Hosting Platform
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(4pt)
#text(weight: "bold")[Bewerbung als DevOps Engineer, Linux Hosting Platform]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Hosting heißt, den Server eines anderen zu betreiben, und das ändert die Prioritäten: Ein Neustart ist keine Option, die Uhr läuft immer, und die Frage ist nicht, ob etwas kaputtgeht, sondern ob man es merkt, bevor der Kunde schreibt. Fünf Jahre lang habe ich dreizehn Linux-Hosts unter genau dieser Bedingung betrieben, ohne Managed Cloud und ohne Reserve. Server entstehen bei mir aus einer Beschreibung — Installation über das Netz, gepinnte Eingaben, Prüfung vor dem Rollout, Rückkehr zur vorigen Generation in Minuten statt in einer Nacht. Das ist der Unterschied zwischen einem Wochenende auf Abruf und einem Wochenende.

#v(2pt)
Netz und Zugriff stehen in derselben Beschreibung: Adressierung, DNS, WireGuard zwischen den Standorten, nftables-Regeln, keine öffentlich erreichbare Verwaltung, eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten. Telemetrie ist selbst gebaut und endet nicht im Dashboard: Ein Ledger schreibt alle fünfzehn Minuten Zustand, Prüfungen von außen messen Erreichbarkeit und Antwortzeit, und eine Brücke in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist. Sicherungen laufen mit restic, und ich spiele sie zurück, statt sie nur einzurichten.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: Kubernetes, Prometheus und Grafana. Meine Automatisierung ist Nix, Python, Go und Shell; ein Hosting-Betrieb mit Containerplattform, großen Datenbanken und Kundenpanels ist mir nicht vertraut. Was ich mitbringe, ist der Teil, der bei Hosting am schwersten nachzuholen ist: den Reflex, jede Änderung reproduzierbar zu machen, und die Gewohnheit, einen Vorfall so aufzuschreiben, dass der nächste ihn nicht neu untersuchen muss.

#v(2pt)
Ich lebe in Freiburg und wäre für Espelkamp oder Münster zum Umzug bereit; Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
