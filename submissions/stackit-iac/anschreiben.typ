// STACKIT / Schwarz Digits — Infrastructure as Code / Terraform Platform Engineer. Deutsches Anschreiben.
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
STACKIT / Schwarz Digits\\
Bad Friedrichshall, Baden-Württemberg

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Infrastructure as Code / Terraform Platform Engineer (m/w/d)]
#v(0.45cm)

Sehr geehrte Damen und Herren,

Infrastructure as Code wird dann wertvoll, wenn die Beschreibung stimmt und nicht nur existiert. Deshalb habe
ich fünf Jahre lang genau das geprüft: dreizehn Linux-Hosts aus einer Deklaration, gepinnte Inputs, jede
Änderung durch ein Gate, das in der CI und auf dem Host identisch läuft, jeder Rückweg ein Zeiger auf die
vorige Generation. Abweichung war bei mir kein Betriebszustand, sondern ein Fehler, der über die Deklaration
behoben wird — nicht über eine Shell, die niemand später findet.

Zu den Werkzeugen: Meine deklarative Arbeit steckt in Nix, mit Modulen, gepinnten Inputs, Host-Definitionen aus
Feature-Listen und einem Rebuild, der eine Funktion des Repositories ist. Die Fragen sind bei Terraform
dieselben: Was ist der wahre Zustand, was driftet, was passiert beim zweiten Lauf, wer darf den Plan sehen und
wer den Apply. Dazu kommt Automatisierung über die Sprachgrenzen — Go, Python, Bash, alles hinter einer
Task-Oberfläche, damit ein Kollege es ohne Rückfrage ausführen kann — und Betrieb mit Telemetrie, Rollback und
dokumentiertem Rückweg.

Was ich nicht mitbringe, sage ich vorab: Terraform habe ich nicht produktiv verantwortet, ebenso wenig
AWS- oder Azure-Infrastruktur als Eigentümer. Ich kann die Konzepte und die Disziplin, die eine solche Plattform
braucht, und ich kenne die Fehler, die aus ungepinnten Modulen und ungeprüften States entstehen; die konkrete
Provider- und Workspace-Erfahrung fehlt. Wer jemanden für einen laufenden Terraform-Bestand ab Tag eins
braucht, findet ihn bei anderen Bewerbern. Wer jemanden braucht, der die Plattform aus einer sauberen
Deklaration heraus aufbaut und den Review-Prozess ernst nimmt, ist bei mir richtig.

Zum Rahmen: Ich wohne in Baden-Württemberg, rund zwei Stunden von Bad Friedrichshall, und Präsenztage in der
Region sind für mich normal. Ich bin US-Staatsbürger mit deutscher Niederlassungserlaubnis — unbefristetes
Aufenthaltsrecht, kein Sponsoring nötig. Deutsch ist C1, Englisch Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
