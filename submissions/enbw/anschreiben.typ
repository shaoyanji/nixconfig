#set document(title: "Bewerbung EnBW — Platform / DevOps Engineer Linux & Kubernetes", author: "Matt Ji")
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
  EnBW Energie Baden-Württemberg AG \
  Karriere-Team \
  Karlsruhe
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Platform / DevOps Engineer Linux & Kubernetes (w/m/d), Referenz C-TIPCP]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ein Energieversorger, der Plattformen baut, ist für mich kein Zufallstreffer, sondern der Schnittpunkt zweier Vorgeschichten: Ich habe Erneuerbare-Energien-Management in Freiburg studiert, am Fraunhofer ISE zu Solar geforscht und vier Jahre lang 10 MW Photovoltaik gesteuert — und in denselben Jahren die Linux-Plattform betrieben, auf der solche Zahlen entstehen. Ertragsdaten und Betriebsdaten sind für mich dieselbe Frage in zwei Sprachen: ob das, was laufen soll, auch läuft.

#v(2pt)
Konkret: Dreizehn Server über drei Hardware-Generationen, deklarativ beschrieben, jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung. Automatisierungen und Schnittstellen schreibe ich in Go und Python, darunter eine Alarm-Bridge, die eine Zustellung erst bestätigt, wenn die Nachricht ankommt, und einen Router für Modellanfragen. Telemetrie ist eigenbau und trotzdem belastbar: ein Sentinel-Ledger mit Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten, Gatus-Prüfungen, Retention durch Rotation. Netz und Firewall sind Code, mit nftables, DNS und einem WireGuard-Tailnet ohne öffentliche Schnittstelle.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher, weil es im Titel der Stelle steht: keinen Kubernetes-Betrieb, kein Helm, kein GitOps, keine Container-Orchestrierung im Produktivbetrieb. Meine Plattform ist deklarativ, aber ohne Scheduler; die Konzepte — Rollout, Rollback, Selbstbedienung über Schnittstellen, Telemetrie als Betriebsgrundlage — sind dieselben. Diese Einarbeitung wäre echt, und ich sage es lieber jetzt als in der Probezeit.

#v(2pt)
Zur Person: Ich wohne in Gutach im Breisgau, also in Baden-Württemberg; Karlsruhe ist rund anderthalb Stunden entfernt, hybrides Arbeiten mit Präsenz bei Bedarf passt zu meinem Alltag. Ich bin US-Amerikaner mit unbefristetem Niederlassungsrecht in Deutschland, benötige kein Visum und keine Sponsoring-Zusage. Deutsch ist bei mir C1, Englisch Muttersprache. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
