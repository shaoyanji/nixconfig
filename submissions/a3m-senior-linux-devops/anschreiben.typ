#set document(title: "Bewerbung — A3M Global Monitoring, Senior Linux DevOps Engineer", author: "Matt Ji")
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
  A3M Global Monitoring GmbH \
  Senior Linux DevOps Engineer (m/f/d) \
  Schopenstehl 20, Hamburg
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(4pt)
#text(weight: "bold")[Bewerbung als Senior Linux DevOps Engineer]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ein Frühwarnsystem ist nur so gut wie die Zustellung seiner Warnung. Diese Erfahrung habe ich fünf Jahre lang auf eigener Hardware gemacht: dreizehn Linux-Hosts, begrenzte Ressourcen, kein Managed Cloud, keine öffentliche Schnittstelle. Ein Sentinel-Job schreibt alle fünfzehn Minuten Zustand, Alter der laufenden Generation, Speicher- und Prozessdruck und Plattenplatz in ein Ledger, Prüfungen von außen messen Erreichbarkeit und Antwortzeit, und eine Brücke in Go führt eine Störung erst dann als gemeldet, wenn die Zustellung bestätigt ist. Ein Alarm, der ausgelöst und nie zugestellt wird, ist schlimmer als keiner, weil er einen falschen Glauben erzeugt.

#v(2pt)
Die Serverlandschaft selbst habe ich von der Installation bis zur Härtung allein getragen: Netze mit WireGuard zwischen den Standorten, nftables-Regeln, keine öffentlich erreichbaren Verwaltungsdienste, eine eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten und getrennte Schlüssel je Host. Auslieferung läuft über gepinnte Eingaben und eine Prüfung des ausgewerteten Systems, nicht über Handarbeit; Rückrollung dauert Minuten. Sicherungen laufen mit restic, und ich spiele sie zurück, statt sie nur einzurichten. Bei einem Vorfall bleibt keine Eskalationsstufe übrig, an die man weiterreichen könnte: Schweregrad bestimmen, Ursache eingrenzen, Dienst wiederherstellen, aufschreiben, was war.

#v(2pt)
Was ich nicht mitbringe, sage ich offen: Eine ISO-27001-konforme Betriebsführung habe ich nicht begleitet, also keine Audits, keine Nachweisführung, kein Management-Handbuch. Cloud-Plattformen, Kubernetes und Container-Orchestrierung kenne ich nicht aus dem Betrieb, und mit einem verteilten Team über mehrere Zeitzonen habe ich nicht gearbeitet — mein Betrieb war fern vom Aufstellungsort, aber allein. Die Härtung, die Netze und die Überwachung, die Ihre Anzeige beschreibt, sind dagegen genau die Arbeit, die ich fünf Jahre lang gemacht habe.

#v(2pt)
Ich arbeite aus Freiburg, Fernarbeit aus ganz Deutschland ist für mich normal, und für Übergaben oder Vor-Ort-Termine bin ich in Hamburg. Deutsch ist C1, Englisch Muttersprache, Niederlassungserlaubnis liegt vor. Das Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(16pt)
Matt Ji
