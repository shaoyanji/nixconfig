#set document(title: "Bewerbung Universität Tübingen — HPC Systems Engineer", author: "Matt Ji")
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
  Eberhard Karls Universität Tübingen \
  Exzellenzcluster Machine Learning, ML Cloud \
  Herrn Simon Kreuzer \
  Tübingen
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als HPC Systems Engineer - Machine Learning Infrastructure & Operations (m/f/d)]

#v(4pt)
Sehr geehrter Herr Kreuzer,

#v(2pt)
Tausende Jobs am Tag auf vier Rechenzentren verteilt, und jeder davon darf nicht daran scheitern, dass die Infrastruktur schlecht dokumentiert ist. Ich habe fünf Jahre lang eine kleinere Version davon betrieben: dreizehn Server, drei Hardware-Generationen, von der Beschaffung bis zur Inbetriebnahme, alles als Code in Git. Dass Ihre Stelle die ganze Kette von Bare Metal über den Scheduler bis zur Automatisierung umfasst, ist genau die Arbeit, die ich kann, und die wissenschaftliche Umgebung kenne ich von innen: 2012 war ich am Fraunhofer ISE.

#v(2pt)
Konkret: Jeder Host ist eine Feature-Liste, jeder Dienst ein Modul, jede Änderung ein Commit mit Gate und Rückrollung. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt; Gatus prüft Endpunkte, eine Go-Bridge bestätigt einen Alarm erst, wenn die Zustellung passiert ist. Speicher und Sicherung laufen über restic auf ein NAS, und ich stelle Wiederherstellungen wieder her, statt sie anzunehmen. Ressourcenlimits je Dienst und ein Blick auf Speicherdruck gehören zum Alltag, nicht zur Ausnahme. Werkzeuge schreibe ich in Bash, Python und Go, und ich dokumentiere, damit andere den Betrieb übernehmen können.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: Slurm habe ich nicht betrieben, kein Lustre, Weka oder Ceph, keine GPU-Kette mit Treibern, CUDA, DCGM und MIG, kein InfiniBand und kein 400G-Ethernet. RHEL und Rocky kenne ich nicht aus dem Produktivbetrieb, meine Flotte ist NixOS und Debian-nah. Mein Abschluss ist ein M.Sc. in Erneuerbare-Energien-Management, nicht in Informatik; was ich an Systemwissen habe, kommt aus zehn Jahren Betrieb und nicht aus dem Zeugnis. Die Anzeige verlangt HPC-Praxis, und die fehlt mir an genau diesen Stellen.

#v(2pt)
Deutsch ist bei mir C1, Englisch Muttersprache. Tübingen liegt rund 130 Kilometer von Gutach entfernt, ein Umzug ist für mich die realistische Annahme, kein Hindernis. Die Stelle ist unbefristet und teilbar, beides passt. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
