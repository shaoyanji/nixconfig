#set document(title: "Bewerbung — Fraunhofer LBF Darmstadt, IT-System-Engineer / Network-Engineer", author: "Matt Ji")
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
  Fraunhofer-Institut für Betriebsfestigkeit und Systemzuverlässigkeit LBF \
  IT-System-Engineer / Network-Engineer (all genders) \
  Kennziffer 86030, Darmstadt
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(4pt)
#text(weight: "bold")[Bewerbung als IT-System-Engineer / Network-Engineer]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ein Maschinenpark, der vernetzt wird, ist ein Netz, das niemand mehr neu starten kann, wenn es falsch konfiguriert ist. Diese Eigenschaft habe ich fünf Jahre lang auf eigener Hardware hergestellt: dreizehn Linux-Hosts über mehrere Standorte, Adressierung und DNS beschrieben statt gewachsen, WireGuard zwischen den Netzen, nftables-Regeln als Teil der Beschreibung, keine öffentlich erreichbaren Verwaltungsdienste. Weil jede Änderung durch eine Prüfung läuft und eine Rückkehr zur vorigen Generation Minuten dauert, lässt sich ein Umbau wagen, ohne den Betrieb zu verlieren — und genau das verlangt die Anbindung von Maschinen im Umfeld von Industrie 4.0.

#v(2pt)
Für ein Institut zählt außerdem, dass man dem Netz ansieht, ob es tut, was es soll. Bei mir schreibt ein Ledger alle fünfzehn Minuten Zustand, Erreichbarkeit, Druck und Plattenplatz mit, Prüfungen von außen messen die Antwortzeit, und eine Brücke in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist. Störungsbearbeitung habe ich ohne Eskalationsstufe dahinter gemacht: eingrenzen, wiederherstellen, aufschreiben. Aus der Forschung kenne ich den Alltag von 2012 am Fraunhofer ISE — Messaufbau, geteilte Rechner, dokumentierte Auswertung — und weiß, dass Forschende ein Netz brauchen, das still funktioniert.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: Enterprise-Switching und WLAN von Cisco und HPE/Aruba habe ich nicht administriert, Palo-Alto-Firewalls, NAC mit Aruba ClearPass und 802.1X nicht betrieben, ein IPAM-System nicht eingeführt, Ansible nicht verwendet und keine CCNA- oder CCNP-Zertifizierung. Eine Auditierung nach ISO 27001 oder TISAX habe ich nicht begleitet. Meine Firewalls sind nftables-Regeln, meine Netze sind Linux-Tunnel, und die Automatisierung ist Nix, Python und Go statt Ansible. Ich wäre bereit, die Zertifizierung nachzuholen, wenn das zum Auftrag gehört.

#v(2pt)
Ich bin bereit, nach Darmstadt umzuziehen; Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
