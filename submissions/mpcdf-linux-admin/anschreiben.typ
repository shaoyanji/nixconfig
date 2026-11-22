#set document(title: "Bewerbung — MPCDF, Linux System Administrator", author: "Matt Ji")
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
  Linux System Administrator\*in (m/w/d) — Kennziffer 04/2026
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(4pt)
#text(weight: "bold")[Bewerbung als Linux System Administrator (m/w/d)]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ihre Anzeige beschreibt eine Stelle, an der ein Ausfall nicht einen Dienst trifft, sondern jede Anmeldung an jedem System: LDAP- und Kerberos-Server zu betreiben, weiterzuentwickeln und zu verbessern. Genau diese Art Dienst habe ich fünf Jahre lang allein betrieben — Adressierung, DNS, Secrets pro Host, eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten und den Zugang über WireGuard und nftables. Jeder Knoten entsteht dabei aus einer Beschreibung: gepinnte Eingaben, Prüfung des ausgewerteten Systems vor dem Rollout, Rückkehr zur vorigen Generation in Minuten. Ein Dienst, der nur in Handarbeit existiert, lässt sich nicht wiederherstellen — also existiert er bei mir nicht in Handarbeit.

#v(2pt)
Zur Betriebsseite kommt die Messseite, und die ist in diesem Profil die ungewöhnliche: 2012 habe ich am Fraunhofer ISE einen Messaufbau betreut, Geräte über C++-Anwendungen angesteuert und Messreihen in Python ausgewertet, mit der Regel, dass ein Ergebnis nachvollziehbar abgelegt wird. Übertragen auf den Betrieb heißt das: Speicher- und Prozessdruck, Plattenplatz und Alter der laufenden Generation werden alle fünfzehn Minuten erfasst, weil sie einem Ausfall vorausgehen; Prüfungen von außen messen Erreichbarkeit und Antwortzeit; eine Brücke in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist. Werkzeuge dafür schreibe ich in Python, Go und Shell.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: LDAP habe ich nicht als Administrator betreut, weder OpenLDAP noch 389 DS, und Kerberos weder als KDC noch als Client-Einbindung; SSSD, PAM-Konfiguration und FreeIPA kenne ich nicht aus dem Betrieb, ebenso wenig einen Zwei-Faktor-Rollout. Mein Abschluss liegt in Erneuerbaren Energien, nicht in Informatik, und die dreizehn Knoten, die ich betreibe, sind kein Rechenzentrum. Was ich mitbringe, ist die Grundlage, auf der solche Dienste laufen: Linux und systemd im Griff, Zertifikate und Secrets selbst verwaltet, Änderungen geprüft und rückrollbar, Störungen eingegrenzt und aufgeschrieben.

#v(2pt)
Ich bin bereit, nach Garching zu umziehen; Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
