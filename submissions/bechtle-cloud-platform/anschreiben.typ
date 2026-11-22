// Bechtle AG / KubeOps — Cloud Platform Engineer (w/m/d), Remote. Deutsches Anschreiben, eine Seite.
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
Bechtle AG — KubeOps\\
Herrn Christopher Waldraff\\
72336 Balingen

#v(0.5cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Cloud Platform Engineer (w/m/d) (Remote) — Job 72406]
#v(0.45cm)

Sehr geehrter Herr Waldraff,

KubeOps baut containerbasierte Infrastruktur für Umgebungen, in denen Datenschutz und regulatorische Vorgaben
den Ausschlag geben. Genau dort liegt meine Erfahrung — allerdings eine Schicht tiefer: Ich habe fünf Jahre
lang Linux-Plattformen so betrieben, dass ihr Zustand aus einer Deklaration entsteht und nachprüfbar bleibt.
Dreizehn Hosts aus einem Repository, jede Änderung durch ein Gate, das in der CI und auf dem Host identisch
läuft, jeder Rückweg ein Zeiger auf die vorige Generation. Wer später prüft, ob ein System gehärtet ist,
findet die Antwort im Repository statt in einer Erinnerung.

Dazu kommt die Seite, die bei sensiblen Umgebungen zählt: Souveränität als Betriebsentscheidung. Secrets
liegen pro Host mit SOPS und age verschlüsselt vor, Zugang läuft über eine SSH-CA mit kurzlebigen Zertifikaten,
nftables setzt Default-Deny. Seit 2024 betreibe ich eine lokale Inferenz-Plattform auf eigener Hardware, damit
Anfragen das Haus nicht verlassen — nicht als Prinzipienreiterei, sondern weil ich wissen will, wo Daten
liegen, bevor ich dafür bezahle.

Was ich nicht mitbringe, sage ich vorab: Kubernetes und Docker habe ich nicht als Administrator betrieben —
keine Cluster-Verwaltung, keine Pod- oder Network-Policies im Produktivbetrieb. Terraform habe ich nicht
eingesetzt, GitLab- oder GitHub-Pipelines nicht entworfen; meine deklarative Arbeit steckt in Nix, meine
CI-Gates in einer eigenen Pipeline. Wer für ein Kundenprojekt einen Plattformingenieur ab Tag eins braucht,
der Cluster und Terraform aus dem Stand beherrscht, findet ihn bei anderen Bewerbern. Wer jemanden sucht, der
Linux, Automatisierung, Härtung und Remote-Disziplin mitbringt und die Container-Seite darauf aufbaut, ist bei
mir richtig.

Zum Rahmen: Ich habe fünf Jahre vollständig ortsunabhängig gearbeitet — Remote ist für mich die Arbeitsform,
in der Dokumentation und Übergabe ernst genommen werden, nicht ein Zugeständnis. Präsenztage in Balingen sind
möglich; Gutach liegt rund 200 Kilometer entfernt, also greift ohnehin das Remote-Modell. Ich bin bereit, die
Sicherheitsüberprüfung nach SÜ2 zu durchlaufen — mit dem Zusatz, dass ich US-Staatsbürger mit deutscher
Niederlassungserlaubnis bin und die Erteilung für nichtdeutsche Staatsangehörige von der zuständigen Stelle
entschieden wird. Das nenne ich früh, damit es nicht nach einer Zusage zum Problem wird. Deutsch ist C1,
Englisch Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
