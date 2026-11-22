#set document(title: "Bewerbung PTV Group — Systemtechniker Leitstellensysteme", author: "Matt Ji")
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
  PTV Transport Consult GmbH \
  Herrn Steffen Göckel, Senior HR Business Partner \
  Hamburg
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Systemtechniker bzw. Systemingenieur Leitstellensysteme (m/w/d), Anzeige j2654]

#v(4pt)
Sehr geehrter Herr Göckel,

#v(2pt)
Eine Leitstelle ist der Ort, an dem ein Ausfall nicht als Ticket erscheint, sondern als dunkler Bildschirm vor Menschen, die gerade eine Entscheidung brauchen. Deshalb lese ich die Anzeige so: gesucht wird jemand, der Infrastruktur nicht nur plant, sondern ihren Betrieb verantwortet. Genau das ist meine Arbeit, seit fünf Jahren, mit dreizehn Servern, drei Hardware-Generationen und dem Anspruch, dass ein Ausfall nicht erst im Gespräch mit den Nutzenden auffällt.

#v(2pt)
Konkret: Netz und Firewall sind als Code konfiguriert, mit nftables, DNS und einem WireGuard-Tailnet, und kein Dienst hängt mit öffentlicher Schnittstelle im Netz. Überwacht wird mit einem Sentinel-Ledger, das Jobstatus, Generation-Alter sowie Disk- und PSI-Druck alle 15 Minuten in JSONL schreibt, dazu Gatus-Prüfungen und eine Go-Bridge, die einen Alarm erst bestätigt, wenn die Zustellung passiert ist. Jede Änderung läuft über ein Gate und lässt sich auf die vorherige Generation zurückrollen; bei Diensten ohne Ausfallfenster ist das der einzige Weg, nachts zu arbeiten. Gesichert wird mit restic, und ich stelle wieder her, statt den Job zu prüfen. Geheimnisse liegen in sops und age, Host-Schlüssel in einer eigenen Zertifizierungsstelle mit kurzlebigen Zertifikaten. Die Flotte wird vollständig aus der Ferne betrieben; das passt zu einer Stelle, die überwiegend remote läuft.

#v(2pt)
Was ich nicht mitbringe: keine Praxis mit SCADA- und Leitsystemen, keiner Tunnelleitzentrale, keiner Video-, Audio- oder KVM-Matrix, kein KRITIS-, NIS-2- oder ISO-27001-Projekt, keine Verkehrstechnik. Ich habe Sicherheitshygiene betrieben, nicht Grundschutz zertifiziert. Diese Einarbeitung wäre echt und ich sage sie vorher. Was ich mitbringe, ist die andere Hälfte: Linux bis zur systemd-Unit, Netzwerke bis zur Fehlersuche auf Paketebene, Verfügbarkeit als Messgröße und die Gewohnheit, Wissen aufzuschreiben, damit ein Team nicht von einer Person abhängt.

#v(2pt)
Zwei Dinge zur Lage: Die Anzeige nennt Hamburg, Karlsruhe ist Sitz der Gruppe; von Gutach im Breisgau sind es dorthin rund eineinhalb Stunden, in den Norden deutlich mehr, und projektbedingte Einsätze sind für mich eine Frage der Planung, nicht des Prinzips. Und ich komme mit einem M.Sc. statt mit Techniker- oder Meisterbrief; formal höher, im Team ungewöhnlich, deshalb steht es hier und nicht in der Fußnote. Deutsch ist bei mir C1, Englisch Muttersprache, Arbeitserlaubnis unbefristet.

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
