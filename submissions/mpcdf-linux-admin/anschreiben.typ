#set document(title: "Bewerbung — MPCDF, Linux Systems Administrator", author: "Matt Ji")
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
  Max Planck Computing and Data Facility (MPCDF) \
  Linux Systems Administrator (m/w/d)
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(4pt)
#text(weight: "bold")[Bewerbung als Linux Systems Administrator]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ein Rechnerverbund, der Forschung trägt, hat zwei Eigenschaften, die ihn von einem Webserver unterscheiden: Knoten werden in großer Zahl identisch gebraucht, und ein einzelner falsch konfigurierter Knoten kostet nicht einen Nutzer, sondern eine Messreihe. Fünf Jahre lang habe ich dreizehn Linux-Hosts unter dieser Logik betrieben — Installation über das Netz, gepinnte Eingaben, Prüfung des ausgewerteten Systems vor dem Rollout, Rückkehr zur vorigen Generation in Minuten. Weil jeder Knoten aus derselben Beschreibung entsteht, ist ein Neuaufbau kein Projekt, sondern ein Vorgang.

#v(2pt)
Dazu kommt die Messseite, und die ist in diesem Bewerbungsprofil die ungewöhnliche: 2012 habe ich am Fraunhofer ISE einen Messaufbau betreut, Geräte über C++-Anwendungen angesteuert und Messreihen in Python ausgewertet — mit der Regel, dass ein Ergebnis nachvollziehbar abgelegt wird. Diese Disziplin habe ich später auf den Betrieb übertragen: Speicher- und Prozessdruck, Plattenplatz und Alter der laufenden Generation werden alle fünfzehn Minuten erfasst, weil sie einem Ausfall vorausgehen; Prüfungen von außen messen Erreichbarkeit und Antwortzeit; eine Brücke in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: Slurm, Lustre und InfiniBand. Ein Cluster mit parallelem Dateisystem, Fabric und GPU-Betrieb ist mir nicht vertraut, und RHEL habe ich nicht im Regelbetrieb verwaltet. Was ich mitbringe, ist die Grundlage, auf der solche Systeme betrieben werden: Linux-Knoten reproduzierbar aufsetzen, Ressourcen messen statt schätzen, Störungen eingrenzen und aufschreiben, und einen Betrieb hinterlassen, den der nächste Kollege übernehmen kann.

#v(2pt)
Ich bin bereit, nach Garching zu umziehen; Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
