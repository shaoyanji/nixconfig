// BAMF — DevOps-Engineers (m/w/d). Deutsches Anschreiben, eine Seite.
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
Bundesamt für Migration und Flüchtlinge\\
Referat 22B — Public Cloud / Plattformdienste\\
Nürnberg

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als DevOps-Engineer (m/w/d) — Kennziffer BAMF-2025-358]
#v(0.45cm)

Sehr geehrte Damen und Herren,

Plattformdienste in einer Bundesbehörde haben eine Bedingung, die in der freien Wirtschaft optional ist:
Der Betrieb muss prüfbar sein. Wer später fragt, welche Konfiguration galt, wer sie geändert hat und wie man
zurückkommt, braucht eine Antwort aus Aufzeichnungen — nicht aus der Erinnerung eines Kollegen. Genau so
betreibe ich Systeme: dreizehn Linux-Hosts aus einer Deklaration im Repository, jede Änderung durch ein Gate,
das in der CI und auf dem Host identisch ist, jeder Rückweg ein Zeiger auf die vorige Generation.

Automatisierung ist bei mir die Voraussetzung dafür, dass ein Betrieb ohne Zuruf funktioniert. Wiederkehrende
Schritte laufen als Go-, Python- oder Bash-Werkzeug hinter einer Task-Oberfläche, sodass auch jemand sie
ausführen kann, der das System nicht gebaut hat. Virtualisierung kenne ich aus dem Betrieb: MicroVMs als
deklarierte Gäste, systemd-Slices mit Speichergrenzen, Provisionierung über PXE bis zum Rebuild. Monitoring
ist ein Ledger alle fünfzehn Minuten mit Meldung auf jeden Zustand ungleich ok, und Störungen werden mit
journald, cgroups und tcpdump bis zur Ursache verfolgt und aufgeschrieben — Dokumentation ist bei mir Teil
der Lieferung, nicht Nachbereitung.

Was ich nicht mitbringe, sage ich vorab: Container-Orchestrierung und den Betrieb einer Public-Cloud-Plattform
habe ich nicht administriert. Container waren bei mir gepinnte Bauumgebungen, keine Plattform; Cloud-Erfahrung
sind Oracle-Hosts und ein kleines Lambda-Projekt. Wenn die Stelle beides ab Tag eins verlangt, bin ich nicht
der passende Kandidat. Wenn eine Behörde jemanden braucht, der die Betriebs- und Automatisierungsseite
mitbringt und die Cloud-Seite geordnet aufbaut, ist die Lücke eine Frage der Einarbeitung.

Zum Rahmen: Eine Eingruppierung in E 11 oder E 12 nach TVöD Bund entspricht meiner Erfahrung; eine
Sicherheitsüberprüfung nach SÜ1 ist für mich kein Hindernis, ich bin US-Staatsbürger mit deutscher
Niederlassungserlaubnis und brauche kein Sponsoring. Nürnberg ist rund 350 Kilometer entfernt — für
Einarbeitung und regelmäßige Präsenz komme ich gern, und ich kläre früh, wie viele Tage hybrid vorgesehen
sind. Deutsch ist C1, Englisch Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
