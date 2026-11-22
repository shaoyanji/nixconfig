#set document(title: "Bewerbung STACKIT — Platform Engineer Control Plane", author: "Matt Ji")
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
  Schwarz Digits KG \
  STACKIT, Abteilung IT - Cloud Services \
  Stiftsbergstraße 1 \
  74172 Neckarsulm
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als (Senior) Platform Engineer - STACKIT Control Plane Platform]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Die Anzeige beschreibt drei Dinge, die zusammen selten sind: interne Werkzeuge bauen, die Infrastrukturbereitstellung automatisieren, und Monitoring als eigene Verantwortung für Verfügbarkeit begreifen. Zwei davon habe ich fünf Jahre lang allein gemacht. Das dritte, die Kubernetes-Control-Plane, habe ich nicht gemacht, und das sage ich nicht am Ende.

#v(2pt)
Konkret: Dreizehn Server über drei Hardware-Generationen, beschrieben als ein deklarativer Zustand — jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit, den ein Gate prüfen muss, jeder frühere Stand als Generation rückrollbar. Kein Host wurde von Hand angefasst; eine Abweichung ist damit kein Betriebszustand, sondern ein Fehler im Repository. Dazu die Interna: cgroup-Limits je Dienst, PSI-Speicherdruck als Messgröße, systemd-Härtung, Namespaces, nftables als Code, DNS, PXE-Installationen aus eigenem Archiv.

#v(2pt)
Werkzeuge habe ich geschrieben, weil sie fehlten: eine in Go geschriebene Bridge, die eine Alarmzustellung erst bestätigt, wenn die Nachricht ankommt, den Router einer autarken KI-Plattform und die Auswertung des Sentinel-Ledgers, der alle 15 Minuten Jobstatus, Generation-Alter sowie Disk- und PSI-Druck schreibt. Das ist derselbe Impuls, aus dem ein Platform-Team interne Tools baut: Arbeit, die sich wiederholt, gehört in Code, nicht in eine Checkliste.

#v(2pt)
Was fehlt, vollständig und ohne Umschreibung: keine Kubernetes-Architektur, kein Operator-Pattern, keine CRDs, kein Istio oder Calico, kein Helm, kein Kustomize, kein Terraform, kein Pulumi, kein Concourse, kein Flux. Wer eine Control Plane baut, braucht das am ersten Tag, und ich bringe es nicht mit. Meine Automatisierung ist Nix und Git, nicht YAML und Helm.

#v(2pt)
Zur Person: Ich bin US-Amerikaner mit Niederlassungserlaubnis, brauche also keinen Visa-Sponsor. Bad Friedrichshall ist von Gutach im Breisgau rund zwei Stunden entfernt; Präsenzblöcke sind für mich die passende Form, ein Umzug nach der Einarbeitung denkbar. Deutsch C1, Englisch Muttersprache — die Anzeige nennt Englisch als Basis, beides ist vorhanden. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
