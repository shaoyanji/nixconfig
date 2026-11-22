// Bundesdruckerei Gruppe — Site Reliability Engineer. Deutsches Anschreiben, eine Seite.
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
Bundesdruckerei Gruppe GmbH\\
Berlin

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Site Reliability Engineer (m/w/d) — Referenz 15933-0067012870-S]
#v(0.45cm)

Sehr geehrte Damen und Herren,

souveräne Infrastruktur heißt für mich: Ein Betrieb, dessen Zustand sich rekonstruieren lässt, ohne jemanden
zu fragen. Wer ändert was, durch welches Gate ging es, was stand vorher, wie komme ich dorthin zurück —
diese vier Fragen beantworte ich auf meinen Systemen aus Aufzeichnungen, nicht aus Erinnerung. Dreizehn
Linux-Hosts laufen bei mir aus einer Deklaration, jede Änderung durch eine Prüfung, die in der CI und auf
dem Host identisch ist, und der Rückweg ist ein Zeiger auf die vorige Generation.

Die Zuverlässigkeitsseite ist bei mir Messung, nicht Zeremonie: ein Ledger alle fünfzehn Minuten mit
Jobstatus, Generation Age, Disk-Druck und PSI, Meldung auf jeden Zustand ungleich ok, und Störungen werden
mit journald, cgroups und tcpdump bis zur Ursache verfolgt und aufgeschrieben. Isolation setze ich über
MicroVMs als deklarierte Gäste und systemd-Slices mit Speichergrenzen; Zugänge laufen über eine SSH-CA mit
kurzlebigen Zertifikaten, Secrets sind pro Host mit SOPS und age verschlüsselt, nftables ist Default-Deny.
Bereitschaft und Schichtbetrieb sind für mich selbstverständlich, nicht Verhandlungsmasse.

Was ich nicht mitbringe, sage ich vorab: Ich habe keine Container-Orchestrierung und keine
Container-Registry administriert — Container waren bei mir gepinnte Bauumgebungen, keine Plattform. Eine
formale Fehlerbudget-Steuerung über mehrere Teams habe ich nicht geführt; ich messe und entscheide auf
meinen Systemen, aber ich habe sie nicht als Governance-Prozess eingeführt. Und eine eigene CI-Plattform
habe ich nicht gebaut: Die Gates laufen in einer bestehenden CI. Für eine Rolle, die den Betrieb souveräner
Systeme verantwortet, ist das der ehrliche Ausgangspunkt.

Zur Person: Berlin bedeutet für mich einen Umzug, nicht ein Pendeln — bei Schicht- und Rufbereitschaft wäre
alles andere unehrlich. Ich bin US-Staatsbürger mit deutscher Niederlassungserlaubnis und brauche kein
Sponsoring; eine Sicherheitsüberprüfung ist für mich kein Hindernis. Zur Eingruppierung: Die Anzeige nennt
keine Spanne, deshalb frage ich nach der vorgesehenen Entgeltgruppe, statt eine Zahl zu erfinden. Deutsch
ist C1, Englisch Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
