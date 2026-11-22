#set document(title: "Bewerbung Universität Freiburg — IT-Administration Future Forests", author: "Matt Ji")
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
  Albert-Ludwigs-Universität Freiburg \
  Exzellenzcluster Future Forests \
  Frau Dr. May-Britt Becker \
  Stadtstraße 5 \
  79104 Freiburg
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Verantwortlicher für die IT-Administration (m/w/d/x), Kennziffer 00005265]

#v(4pt)
Sehr geehrte Frau Dr. Becker,

#v(2pt)
Ich wohne in Gutach im Breisgau, rund 20 Kilometer von Freiburg, und ich habe an dieser Universität studiert. Als jemand, der 2014 hier seinen Master gemacht hat und seitdem Systeme betreibt, ist das keine Bewerbung an eine fremde Institution, sondern an die eigene Alma Mater. Future Forests forscht daten- und softwareintensiv, und ich weiß aus eigener Zeit am Fraunhofer ISE, was das für die IT bedeutet: Messreihen und Modelle vertragen keine Unterbrechung, und wer sie betreut, muss die Forschenden verstehen, nicht nur die Server.

#v(2pt)
Meine Praxis ist Linux: dreizehn Server über drei Hardware-Generationen, jeder Dienst ein Modul, jede Änderung ein Commit mit Gate und Rückrollung. Gesichert wird mit restic auf ein NAS, und ich führe Wiederherstellungen wirklich durch, statt zu prüfen, ob der Job grün ist; genau das verlangt Ihre Anzeige. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in ein JSONL-Ledger schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Zustellung passiert ist. Netz und Firewall liegen als nftables-Regeln neben den Diensten, DNS ist selbst konfiguriert, Zugriffsrechte sind Rollen je Host, Geheimnisse liegen in sops und age, und kein Dienst hängt ungeschützt im Netz. Jede Prozedur steht als Runbook im Repository, damit der Betrieb nicht an einer Person hängt.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: Windows administriere ich auf Workstation-Ebene, nicht als Server mit Active Directory und Gruppenrichtlinien, und macOS habe ich nie administriert. VMware, Hyper-V und KVM sind nicht meine Praxis, Docker und Kubernetes ebenfalls nicht, Identity Management mit LDAP oder Keycloak fehlt, und BSI IT-Grundschutz habe ich nicht umgesetzt, sondern nur die Hygieneseite davon gelebt. Die Anzeige verlangt fundierte Kenntnisse in Windows, Linux und macOS; die Lücke liegt bei Windows im Serverbetrieb und bei macOS insgesamt.

#v(2pt)
Deutsch ist bei mir C1, Englisch Muttersprache, und der Weg nach Freiburg ist ein Arbeitsweg, kein Umzug. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
