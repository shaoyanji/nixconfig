#set document(title: "Bewerbung — Universität Rostock, IT-Systemadministrator", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig
]

#v(14pt)

#text(size: 9pt)[
  Universität Rostock \
  IT-Systemadministrator
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als IT-Systemadministrator]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Serverbetrieb ist für mich die Arbeit, die man nicht sieht, solange sie funktioniert. Ich habe fünf Jahre lang dreizehn Linux-Server allein betreut: Installation über das Netz, Aufteilung der Datenträger, Dienste, Netz und Zugriff, Sicherheitsupdates, Sicherungen. Der Zustand jeder Maschine steht in einer Flake und nicht in meiner Erinnerung; ein Rollout läuft über eine Prüfung, eine Rückkehr zur vorigen Generation dauert Minuten statt einer Nacht. Diese Eigenschaft ist in einem Institut mit begrenzter Personaldecke mehr wert als jede einzelne Technik: Wer die Maschine beschreibt, kann sie wiederherstellen, auch wenn derjenige, der sie aufgesetzt hat, gerade nicht da ist.

#v(2pt)
Wartung habe ich deshalb automatisiert, weil sie sonst liegen bleibt. Alle fünfzehn Minuten schreibt ein Ledger den Zustand, Prüfungen messen Erreichbarkeit und Antwortzeit, ein Alarmkanal in Go meldet eine Störung erst, wenn die Zustellung bestätigt ist. Speicher- und Prozessdruck, Alter der laufenden Generation und Platz auf den Datenträgern werden mitgeprüft, weil sie einem Ausfall vorausgehen. Sicherungen laufen mit restic, und ich spiele sie zurück, statt sie nur einzurichten. Netz und Fernzugriff sind im Code beschrieben: nftables, WireGuard ohne öffentlichen Listener, eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten. Dokumentation entsteht aus demselben Bestand wie das Aufgabenmenü, damit Wissen nicht mit einer Stelle geht.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: Ich habe Debian nicht im Regelbetrieb verwaltet — mein Bestand läuft auf NixOS, die Paket- und Rechnerverwaltung einer Hochschule ist mir also nicht vertraut. Windows-Domäne, Active Directory, VMware und Ansible kenne ich nicht aus dem Betrieb. Aus der Forschung kenne ich den Alltag aus dem Jahr 2012 am Fraunhofer ISE: Messaufbau, geteilte Rechner, Datenablage, dokumentierte Auswertung. Das ist keine Hochschul-IT, aber es ist ein Forschungsumfeld, in dem Rechner von Menschen genutzt werden, die keine Systemadministratoren sind.

#v(2pt)
Ich wohne in Freiburg und wäre für die Stelle nach Rostock umzuziehen; Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
