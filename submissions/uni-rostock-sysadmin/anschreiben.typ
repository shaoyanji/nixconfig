#set document(title: "Bewerbung Universität Rostock — Systemadministrator/in", author: "Matt Ji")
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
  Universität Rostock \
  Fakultät für Informatik und Elektrotechnik \
  Herrn Prof. Dr.-Ing. Danielis \
  Albert-Einstein-Straße 22 \
  18059 Rostock
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Systemadministrator (m/w/d), Kennung 17891, Interamt-ID 1512442]

#v(4pt)
Sehr geehrter Herr Professor Danielis,

#v(2pt)
Ein Lehrstuhl-Fachlabor ist der Ort, an dem Forschung und Lehre dieselbe Hardware teilen: Rechner, auf denen ein Semesterprojekt läuft, während daneben eine Messreihe weiterläuft. Diese Infrastruktur soll unsichtbar sein, und unsichtbar wird sie nur, wenn jemand sie beschafft, dokumentiert, überwacht und im Störungsfall zuerst dort ist. Genau diese Rolle habe ich fünf Jahre lang ausgefüllt, mit dreizehn Servern, drei Hardware-Generationen und Nutzenden, die sich auf die Dienste verlassen mussten.

#v(2pt)
Konkret: Die Server-Infrastruktur steht deklarativ in einem Repository, jeder Dienst ist ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Prüfung und Rückrollung. Die Systeme laufen auf NixOS und Debian-nah, mit systemd, klarer Rechteverwaltung und reproduzierbaren Installationen. Web-Dienste stelle ich hinter einem Reverse Proxy bereit, mit TLS über eine eigene Zertifizierungsstelle und kurzlebigen Zertifikaten, erreichbar nur über ein WireGuard-Tailnet. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten schreibt; Sicherungen laufen mit restic und werden durch Wiederherstellungen geprüft. Beschaffung, Installation und Inbetriebnahme habe ich selbst gemacht, Support und Dokumentation ebenso — am Fraunhofer ISE zusätzlich im wissenschaftlichen Umfeld mit Laborgeräten und Messdaten.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: keine Windows-Server-Administration und keinen Windows-Desktop-Support im betreuten Maßstab, keine Linux-Virtualisierung mit Proxmox oder KVM, kein RHEL und keine Erfahrung mit den Verwaltungsverfahren einer Hochschule. Das ist ein Teil der Stelle, und ich sage es lieber jetzt als in der Einarbeitung. Was ich mitbringe, ist die Fähigkeit, sich in eine gewachsene Laborumgebung einzuarbeiten, sie zu dokumentieren und den Betrieb so zu ordnen, dass er nicht an einer Person hängt.

#v(2pt)
Zur Lage: Ich wohne in Gutach im Breisgau, rund 800 km von Rostock, und die Stelle ist bis zum 30.11.2027 befristet. Ein Umzug für zwölf Monate wäre für beide Seiten schwer zu rechtfertigen; was ich anbieten kann, sind Präsenzblöcke vor Ort — etwa zwei Wochen im Monat, in Abstimmung mit den Labor- und Lehrbetriebszeiten —, ergänzt durch Fernbetreuung an den übrigen Tagen. Wenn das für die Betreuung eines Fachlabors zu wenig ist, ist das ein ehrliches Ausschlusskriterium und keine Frage des Verhandelns. Meine Niederlassungserlaubnis ist unbefristet, ich benötige kein Visum; Deutsch ist bei mir C1, Englisch Muttersprache.

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
