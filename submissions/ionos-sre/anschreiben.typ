// IONOS SE — Site Reliability Engineer (f/m/d), Application Hosting. Deutsches Anschreiben, eine Seite.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.32cm)
#text(size: 8.6pt, fill: muted)[22. November 2026]
#v(0.32cm)
IONOS SE #linebreak() Application Hosting

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Bewerbung als Site Reliability Engineer (f/m/d) – Application Hosting, Karlsruhe]
#v(0.32cm)

Sehr geehrte Damen und Herren,

die Ausschreibung beschreibt eine Plattform, auf der Managed Nextcloud, Nextcloud Workspace und IONOS GPT für sehr viele
Kundinnen und Kunden laufen, und verlangt Betrieb, der auch bei höchster Last trägt. Genau an dieser Frage arbeite ich seit vier
Jahren, nur mit dreizehn Hosts statt mit einer Produktplattform: Wie belegt man, dass ein Dienst wirklich läuft, und wie
automatisiert man den Betrieb so, dass ihn nachts niemand von Hand retten muss.

Linux ist dabei die Grundlage, und sie ist deklarativ: NixOS erzeugt ein System aus einer Beschreibung, Generationen sind
reproduzierbar, ein Rollback ist ein Zeiger auf die vorige Generation. Ein Flake beschreibt dreizehn Hosts als Feature-Listen, die
Optionsfläche wird abgeleitet statt kopiert, und jede Änderung geht durch dasselbe Modul-Gate, das in der CI und auf den Maschinen
läuft. Dazu gehört Telemetrie, der ich traue: ein Sentinel schreibt alle fünfzehn Minuten Jobstatus, Generation Age, Disk-Druck und
Pressure Stall in ein Ledger, gatus alarmiert bei jedem Zustand außer ok und zusätzlich bei Stille, und ein grüner Socket gilt
ausdrücklich nicht als erledigter Job — nur das Ledger entscheidet. Wenn etwas bricht, endet die Analyse in einer strukturellen
Änderung: Der Check, der den Fehler gefunden hat, wird Teil des Gates.

Kubernetes habe ich nicht produktiv betrieben, weder als Cluster-Administrator noch als Plattform-SRE mit Mandanten, und das sage
ich vor dem ersten Gespräch. Terraform, GitLab CI, Argo CD und Prometheus/Grafana stehen nicht in meiner Werkzeuggeschichte;
Nextcloud habe ich nicht administriert. Was daneben und darunter da ist: deklarative Gäste als MicroVMs aus derselben Codebasis wie
ihre Hosts, containerisierte Builds mit gepinnten Eingaben, Automatisierung in Go und Python, PostgreSQL im Betrieb, Secrets pro
Host mit sops und age, SSH-Zugriff über eine Zertifizierungsstelle. Diese Werkzeuge sind austauschbar, die Denkweise dahinter nicht.

Auch die Skalierung will ich nicht größer reden, als sie ist. Dreizehn Hosts und ein Postgres-Archiv sind kein Application Hosting
für Millionen Kunden. Was überträgt, ist die Methode: die Ursache vor dem Eingriff messen, Änderungen nur durch ein Gate lassen,
Dokumentation schreiben, die um drei Uhr nachts lesbar ist, und einen Alarm abschalten, dem niemand mehr glaubt.

Zum Rahmen: Karlsruhe liegt rund 130 Kilometer von Gutach im Breisgau entfernt, einzelne Bürotage sind gut machbar, täglich
dauerhaft nicht — über die Aufteilung und die Rufbereitschaft spreche ich gern. Deutsch ist C1, Englisch Muttersprache; ich bin
US-Staatsbürger mit deutscher Niederlassungserlaubnis und brauche keine Unterstützung bei der Arbeitserlaubnis. Meine
Gehaltsvorstellung liegt bei 85.000 Euro brutto im Jahr, Eintritt ab 01.12.2026.

Mit freundlichen Grüßen,
#v(0.4cm)
Matt Ji
