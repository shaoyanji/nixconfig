#set document(title: "Bewerbung FAU — IT-Systemadministrator Linux und Windows", author: "Matt Ji")
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
  Friedrich-Alexander-Universität Erlangen-Nürnberg \
  Lehrstuhl für Fertigungstechnologie (LFT) \
  Herrn Gunar Tochtermann \
  Egerlandstraße 11-13 \
  91058 Erlangen
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als IT-Systemadministrator Linux und Windows (m/w/d), Interamt-ID 1513404, Kennung 2015]

#v(4pt)
Sehr geehrter Herr Tochtermann,

#v(2pt)
Eine IT am Lehrstuhl für Fertigungstechnologie ist keine Büro-IT: CAD- und FEM-Workstations, Messplätze an Pressen, Cluster für Simulationen, NAS für Messdaten, verteilt auf drei Standorte. Ich kenne beide Hälften davon. Am Fraunhofer ISE habe ich Laborgeräte über selbst geschriebene C++-Anwendungen angebunden und Messreihen in Python ausgewertet; danach habe ich fünf Jahre lang dreizehn Server allein betrieben, von der Beschaffung über Transport und Installation bis zum laufenden Betrieb.

#v(2pt)
Konkret: Ubuntu-nahes Linux und NixOS, Benutzer- und Rechteverwaltung über zentrale Konfiguration statt lokaler Handarbeit, Netze und Firewall als Code mit nftables, DNS, ein WireGuard-Tailnet ohne öffentliche Schnittstelle, PXE-Installationen aus eigenem ISO-Archiv. Sicherungen laufen mit restic auf NAS-Ziele und werden durch Wiederherstellungen geprüft. Ein Sentinel-Ledger schreibt alle 15 Minuten Jobstatus, Generation-Alter, Disk- und PSI-Druck; Gatus prüft Endpunkte, eine Go-Bridge bestätigt Alarme erst bei Zustellung.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: keine Windows-Server-Administration, kein Active Directory, keine Group Policies, kein Hyper-V, kein PowerShell, keine Lizenzserver für CAD- und FEM-Software. Windows kenne ich aus der Anwenderbetreuung. Das ist die halbe Stellenbeschreibung, und ich sage es lieber jetzt als in der Einarbeitung.

#v(2pt)
Was ich mitbringe, ist die andere Hälfte: zehn Jahre Linux, Beschaffung und Hardware-Lebenszyklus an mehreren Standorten, Speicher und Sicherung mit geprüften Wiederherstellungen, Dokumentation als Runbook und die Gewohnheit, ein Institut nicht von einer Person abhängig zu machen. Die Stelle ist mit TV-L E 10 bewertet; die Perspektive auf die Nachfolge der IT-Leitung bis E 11 ist genau die Aufgabe, für die ich mich bewerbe, weil sie Betrieb und Verantwortung zusammenbringt. Ich bin US-Amerikaner mit unbefristetem Niederlassungsrecht in Deutschland, brauche also keinen Visa-Sponsor. Erlangen ist von Freiburg rund dreieinhalb Stunden entfernt; hybrides Arbeiten und ein Umzug nach der Einarbeitung sind für mich beides gangbare Wege. Deutsch C1, Englisch Muttersprache.

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
