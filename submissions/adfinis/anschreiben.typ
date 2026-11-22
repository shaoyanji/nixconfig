// Adfinis AG — Senior System Engineer (Cloud Native). Deutsches Anschreiben, eine Seite.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.4cm)
Adfinis AG\\
Herrn Felix Kronlage-Dammers

#v(0.35cm)
#text(size: 8.8pt, fill: muted)[22. November 2026]

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Bewerbung als Senior System Engineer (Cloud Native, 80–100 %, remote in Deutschland)]
#v(0.45cm)

Sehr geehrter Herr Kronlage-Dammers,

Infrastruktur, die nur in der Hand ihres Erbauers funktioniert, ist keine Infrastruktur, sondern eine persönliche
Dienstleistung. Genau daran habe ich fünf Jahre gearbeitet: dreizehn Linux-Hosts als eine Deklaration, jeder Host eine
Feature-Liste, jeder Dienst ein Modul, jeder Eingang gepinnt. Änderungen laufen durch ein Gate, das in der CI und auf der
Maschine identisch ist; jede Generation hat einen Vorfahren, sodass ein Rollback ein Zeiger ist und keine Reparatur um
drei Uhr nachts. Secrets liegen pro Host mit sops verschlüsselt hinter einer eigenen SSH-Certificate-Authority, die
kurzlebige Zugänge ausstellt, und ein Sentinel schreibt alle fünfzehn Minuten Jobstatus, Generation-Alter, Disk- und
PSI-Druck — Alarm bei jedem Zustand außer „ok" und auch dann, wenn ein Dienst einfach aufhört zu melden.

Dass Adfinis Open Source als Geschäftsmodell betreibt und nicht als Marketing, ist der Grund für diese Bewerbung. Ich
habe zehn Jahre auf der kaufmännischen Seite von Energieanlagen gearbeitet — ein Solarportfolio über 100 Mio. USD, die
Ertrags-, Bewertungs- und Hedging-Modelle dahinter, Bankenprüfungen und Due-Diligence — und dabei gelernt, in Kosten pro
Einheit und in Service-Leveln zu denken statt in Uptime-Prozenten. Auf Deutsch und Englisch vor Kunden, Banken und
Deal-Brokern zu sprechen, war dabei Alltag.

Was ich mitbringe, ist überprüfbare Reproduzierbarkeit: dieselbe Prüfung, die die CI besteht, besteht auch der Host, und
die Dokumentation wird aus derselben Quelle erzeugt wie die Konfiguration, damit sie nicht driftet. Was ich nicht
mitbringe, ist Betriebserfahrung mit Kubernetes-Clustern, Terraform oder Vault im Kundengroßmaßstab. Ihre Ausschreibung
nennt NixOS ausdrücklich als akzeptierte Distribution, und genau dort liegt meine Tiefe — ich würde die übrigen Werkzeuge
im Kundeneinsatz lernen, nicht behaupten, sie schon zu beherrschen.

Was mich an dieser Stelle zusätzlich interessiert: Beratung heißt, die Lösung muss beim Kunden weiterleben, wenn das
Projekt vorbei ist. Deshalb schreibe ich lieber Mechanismen als Anleitungen — ein Check, der eine Fehlerklasse schließt,
ist mehr wert als eine Notiz, die niemand liest. Ich zeige Ihnen das Repository lieber, als es zu beschreiben:
https://github.com/shaoyanji/nixconfig

Ich bin US-amerikanischer Staatsbürger mit unbefristeter deutscher Niederlassungserlaubnis, also ohne Sponsoring
arbeitsberechtigt, wohne in Baden-Württemberg und arbeite gern remote mit Reisebereitschaft zu Kundenterminen. Über ein
Gespräch freue ich mich.

Mit freundlichen Grüßen
#v(0.5cm)
Matt Ji
