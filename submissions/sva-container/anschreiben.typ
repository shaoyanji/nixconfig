// SVA — DevOps Engineer Container und Cloud (j456). Deutsches Anschreiben, eine Seite.
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
SVA System Vertrieb Alexander GmbH\\
Schnewlinstraße 12\\
79098 Freiburg im Breisgau

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als DevOps Engineer — Container und Cloud (j456)]
#v(0.45cm)

Sehr geehrte Damen und Herren,

Plattformarbeit bei einem Integrator ist Arbeit für Kunden, die den Betrieb später selbst tragen müssen.
Deshalb zählt am Ende nicht, dass es lief, sondern dass es erklärbar ist: welcher Zustand galt, wer ihn
geändert hat, wie man zurückkommt. So habe ich fünf Jahre lang Systeme betrieben — dreizehn Linux-Hosts aus
einer Deklaration im Repository, jede Änderung durch ein Gate, das in der CI und auf dem Host identisch
läuft, Rollback als Zeiger auf die vorige Generation.

Automatisierung verstehe ich als Voraussetzung, nicht als Zusatz. Wiederkehrende Schritte laufen als Go-,
Python- oder Bash-Werkzeug hinter einer Task-Oberfläche, sodass auch jemand sie ausführen kann, der das
System nicht gebaut hat. Dazu kommen Netzwerk und Härtung aus der Praxis: nftables als Default-Deny,
WireGuard, eigene CA mit kurzlebigen Zertifikaten, Secrets pro Host mit SOPS und age, Monitoring über ein
Ledger alle fünfzehn Minuten und Fehlersuche mit journald, cgroups und tcpdump. Container nutze ich als
gepinnte Bauumgebungen, nicht als Plattform.

Damit zum Punkt, der über die Bewerbung entscheidet: Kubernetes und OpenShift habe ich nicht produktiv
administriert. Ich weiß, wie ein Cluster aufgebaut ist und warum ein Rollout eine Rollback-Geschichte
braucht, aber ich habe keinen Betrieb mit mehreren Mandanten und keine Upgrade-Pfade über Versionen
verantwortet. Wenn die Stelle diesen Betrieb ab Tag eins verlangt, bin ich der falsche Kandidat. Wenn SVA
jemanden sucht, der Linux, Automatisierung und Kundenverantwortung mitbringt und die Container-Plattform
darauf aufbaut, bringe ich den Teil mit, der Jahre braucht.

Vor Ort bin ich ohnehin: Gutach liegt rund 25 Kilometer von der Schnewlinstraße entfernt, ich kann an
Kundenterminen und im Büro präsent sein, ohne über Entfernung zu verhandeln. Meine Gehaltsvorstellung liegt
bei *85.000 € brutto jährlich*. Deutsch ist C1, Englisch Muttersprache, ich bin US-Staatsbürger mit
deutscher Niederlassungserlaubnis und brauche kein Sponsoring.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
