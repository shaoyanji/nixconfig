#set document(title: "Bewerbung — Fraunhofer IOF Erfurt, Senior Netzwerkspezialist Linux", author: "Matt Ji")
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
  Fraunhofer-Institut für Angewandte Optik und Feinmechanik IOF \
  Fraunhofer-Zentrum Erfurt, Photonische Quanten Systeme \
  Senior Netzwerkspezialist — Schwerpunkt Linux (all genders)
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(4pt)
#text(weight: "bold")[Bewerbung als Senior Netzwerkspezialist, Schwerpunkt Linux]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ein Testbed ist ein Netz, das man nachbauen kann. Diese Eigenschaft habe ich fünf Jahre lang hergestellt: dreizehn Linux-Hosts über mehrere Standorte, WireGuard zwischen den Netzen, nftables-Regeln als Teil der Beschreibung, keine öffentlich erreichbaren Verwaltungsdienste, eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten. Weil jede Maschine aus derselben Beschreibung entsteht, lässt sich eine Umgebung wieder aufbauen, wenn ein Versuch sie zerlegt hat — und genau das ist in einem Forschungslabor mit wechselnden Aufbauten der Unterschied zwischen einem Ergebnis und einem verlorenen Nachmittag.

#v(2pt)
Für ein Quanten-Testbed zählt außerdem, dass man dem Netz ansieht, ob es tut, was es soll. Bei mir schreibt ein Ledger alle fünfzehn Minuten Zustand, Erreichbarkeit, Druck und Plattenplatz mit, Prüfungen von außen messen die Antwortzeit, und eine Brücke in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist. Störungsbearbeitung habe ich ohne Eskalationsstufe dahinter gemacht: eingrenzen, wiederherstellen, aufschreiben. Aus der Forschung kenne ich den Alltag von 2012 am Fraunhofer ISE — Messaufbau, geteilte Rechner, dokumentierte Auswertung — und weiß deshalb, dass Forschende ein Netz brauchen, das still funktioniert, nicht eines, das erklärt werden muss.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: Kommerzielle Firewall-Appliances habe ich nicht administriert, meine Firewalls sind nftables-Regeln. WAN-Routing mit BGP, OSPF oder MPLS, Glasfasertechnik und QKD kenne ich nicht aus dem Betrieb, ebenso wenig die Steuerung externer Dienstleister oder 2nd- und 3rd-Level-Support in einer großen Organisation. Was ich mitbringe, ist der Teil, der schwer nachzuholen ist: Linux-Netze von Grund auf bauen, Regeln und Adressierung als Code behandeln, und einen Betrieb hinterlassen, den der nächste Kollege übernehmen kann.

#v(2pt)
Ich bin bereit, nach Erfurt umzuziehen; Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
