// STACKIT / Schwarz Digits — DevOps / Cloud Engineer, Kubernetes & IaC (GT4627). Deutsches Anschreiben.
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
Frau Lara Schlimgen\\
Am Campus 1\\
74177 Bad Friedrichshall

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als DevOps / Cloud Engineer — Kubernetes & Infrastructure as Code (GT4627)]
#v(0.45cm)

Sehr geehrte Frau Schlimgen,

eine Plattform, die ServiceNow-Dienste für Kunden einer souveränen Cloud trägt, wird an zwei Stellen geprüft:
ob sie unter Last stabil bleibt und ob ihr Zustand belegbar ist, wenn ein Prüfer nach BSI C5 oder DORA fragt.
An der zweiten Stelle arbeite ich seit fünf Jahren: dreizehn Linux-Hosts aus einer Deklaration, jede Änderung
durch ein Gate, das in der CI und auf dem Host identisch läuft, jeder Rückweg ein Zeiger auf die vorige
Generation, dazu Telemetrie alle fünfzehn Minuten und Härtung als Voreinstellung statt als Projekt.

Konkret: nftables als Default-Deny mit expliziten Freigaben, Secrets pro Host mit SOPS und age verschlüsselt,
Zugang über eine SSH-CA mit kurzlebigen Zertifikaten, Abhängigkeiten auf bekannte Schwachstellen geprüft. Für
Observability gibt es ein Ledger, das Jobstatus, Generation Age, Disk-Druck und PSI erfasst und jeden Wert
außerhalb des Erwarteten meldet; Fehlersuche läuft mit journald, cgroups, tcpdump und strace bis zur Ursache
und wird aufgeschrieben, damit der nächste Fall billiger ist. Autoscaling und SLA-Denken sind mir aus der
Energiebranche vertraut, wo Verfügbarkeit eine Kennzahl mit Vertragsfolge war, nicht eine Absicht.

Zur Technik, die Ihre Anzeige nennt, und zu dem, was ich davon nicht habe: Kubernetes habe ich nicht als
Administrator betreut — keine Cluster-Upgrades, keine Pod-Security-Policies, keine Network-Policies im Betrieb.
Terraform, Ansible und helm habe ich nicht produktiv eingesetzt, eine GitLab-Pipeline habe ich nicht entworfen,
und ServiceNow kenne ich als Anwender von Tickets, nicht als Plattform. Meine deklarative Arbeit steckt in Nix,
mit Modulen, gepinnten Inputs und Rebuild als reproduzierbarem Pfad; CI-Gates habe ich gebaut, nur nicht in
GitLab. Wenn die Stelle diese Werkzeuge ab Tag eins und in dieser Breite verlangt, bin ich nicht der passende
Kandidat — das sage ich lieber jetzt als nach drei Gesprächen.

Was ich mitbringe, ist die Arbeitsweise, um die herum diese Rolle gebaut ist: Infrastruktur als Code mit
Review, Drift als Fehler statt als Zustand, Härtung mit Nachweis, Betrieb mit Telemetrie und definiertem
Rückweg. Ich wohne in Baden-Württemberg, rund zwei Stunden vom Campus, Präsenztage sind für mich normal. Ich
bin US-Staatsbürger mit deutscher Niederlassungserlaubnis, unbefristetes Aufenthaltsrecht, kein Sponsoring
nötig. Deutsch C1, Englisch Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
