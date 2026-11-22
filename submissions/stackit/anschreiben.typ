#set document(title: "Bewerbung STACKIT — Senior Platform Engineer Control Plane", author: "Matt Ji")
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
  Schwarz Digits — STACKIT \
  IT - Cloud Services \
  Referenz 1923 · Bad Friedrichshall
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als (Senior) Platform Engineer, STACKIT Control Plane Platform]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ich habe die Werkzeuge, die eine Plattform tragen, selbst gebaut statt eingekauft. Fünf Jahre lang habe ich dreizehn Linux-Hosts allein betrieben: deklarativ beschrieben, jede Änderung durch ein Gate geprüft, jeder Stand als Generation rückrollbar. Das Monitoring war keine Lizenz, sondern ein Ledger mit Messwerten alle fünfzehn Minuten, Gatus-Prüfungen und eine Alarm-Bridge in Go, die eine Zustellung erst bestätigt, wenn sie angekommen ist. Wenn ein Entwicklungsteam damals etwas auf der Plattform brauchte, gab es niemanden, an den ich es hätte weiterreichen können — es gab ein Runbook, ein Task und mich.

#v(2pt)
Genau darin liegt die Verbindung zu Ihrer Control Plane: Interne Werkzeuge bauen, die Bereitstellung automatisieren, Monitoring für Verfügbarkeit und Performance verantworten und Entwicklungsteams dabei unterstützen, ihre Services zu betreiben. Ich habe in Go und Python Werkzeuge geschrieben, die Handarbeit ersetzt haben, statt sie zu dokumentieren. Ich habe Sicherheit als Teil der Lieferkette behandelt: sops und age, eine eigene CA mit kurzlebigen Zertifikaten, nftables als Code, keine offenen Sockets. Und ich habe fünf Jahre lang in einem Umfeld gearbeitet, in dem es keinen zweiten Menschen gab, der ein Problem hätte übernehmen können.

#v(2pt)
Was fehlt, sage ich vorher, weil es der Kern der Stelle ist. Kubernetes habe ich nicht im Produktivbetrieb aufgebaut, weder Architektur noch Operator-Pattern, und mit Istio, Calico, Helm, Kustomize, Terraform, Pulumi, Concourse und Flux habe ich nicht gearbeitet. Meine deklarative Arbeit ist Nix, nicht HCL, und meine verteilten Systeme sind dreizehn Hosts, keine mandantenfähige Cloud. Wer eine Control Plane baut, braucht genau das am ersten Tag; ich würde es lernen müssen, und das ist ein echter Aufwand, kein Formfehler.

#v(2pt)
Zur Region: Ich wohne in Gutach im Breisgau, Bad Friedrichshall liegt rund zwei Stunden entfernt. Für Präsenzblöcke ist das machbar; über einen Umzug in den Raum Heilbronn würde ich offen sprechen. Ich bin US-Amerikaner mit Niederlassungserlaubnis, brauche also keinen Sponsor. Deutsch C1, Englisch Muttersprache. Mein Repository ist öffentlich: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
