// shopware AG — Cloud Infrastructure Engineer – AWS. Deutsches Anschreiben, eine Seite.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.9pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.6pt)[Matt Ji]
  #linebreak()
  #text(size: 9.2pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9.2pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.8pt, fill: muted)[22. November 2026]
#v(0.4cm)
shopware AG\\
IT Operations, IT Infrastructure\\
Schöppingen

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Cloud Infrastructure Engineer – AWS (m/w/d)]
#v(0.45cm)

Sehr geehrte Damen und Herren,

Sie suchen jemanden, der die interne IT-Infrastruktur stabil hält, die AWS-Umgebungen automatisiert
weiterentwickelt und das Netzwerk als Grundlage mitdenkt. Den Betriebsteil bringe ich seit fünf Jahren
mit — die Cloud-Seite ist der Teil, den ich lernen will, und Ihre Ausschreibung ist eine der wenigen, die
das ausdrücklich zulässt.

Ich betreibe dreizehn Linux-Hosts aus einer Deklaration im Repository. Jede Maschine zieht ihren Zustand
von dort, keine Änderung erreicht einen Host ohne ein Gate, das in der CI und auf dem Host selbst läuft,
und der Rückweg ist ein Zeiger auf die vorige Generation. Netzwerk ist dabei kein Nebenthema: WireGuard
zwischen den Hosts, nftables als Default-Deny, eine eigene DNS-Zone, MTU- und Path-Fehler mit tcpdump
gefunden statt geraten. Monitoring betreibe ich als Aufzeichnung, nicht als Dashboard — Jobstatus,
Generation Age, Disk-Druck und PSI alle fünfzehn Minuten, Meldung auf jeden Zustand ungleich ok — und
genau aus diesen Daten entstehen die Reports, die Sie für Entscheidungen brauchen: welche Instanz zu groß
ist, welcher Dienst zu viel Speicher hält, wo eine Grenze zu eng sitzt.

Was ich nicht mitbringe, sage ich vorab: Terraform habe ich nicht eingesetzt — meine Infrastruktur als Code
sind NixOS-Module und Flake-Verdrahtung, deklarativ, gepinnt und geprüft. AWS habe ich als Oracle-Hosts und
in einem kleinen Lambda-Projekt berührt, nicht als Architektur; CloudWatch und Prometheus/Grafana kenne ich
nicht aus dem Betrieb. Sie schreiben "Terraform oder ein vergleichbares IaC-Tool", und dort liegt mein
Anknüpfungspunkt: Die Konzepte sind vorhanden, das Werkzeug ist lernbar, und ich bringe die Betriebsdisziplin
mit, die eine Umgebung erst wartbar macht.

Zur Arbeitsweise: Ich arbeite seit fünf Jahren vollständig ortsunabhängig und dokumentiere so, dass
Übergabe ohne Rückfrage funktioniert. Ihre Ausschreibung erlaubt vollständig remote innerhalb Deutschlands,
mit vereinbartem Vertragsort — das passt zu mir; für Abstimmung und Projekte komme ich gern nach
Schöppingen. Meine Gehaltsvorstellung bespreche ich anhand der Bandbreite, die Sie für die Rolle vorgesehen
haben. Ich bin US-Staatsbürger mit deutscher Niederlassungserlaubnis, brauche kein Sponsoring und kann
kurzfristig beginnen.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
