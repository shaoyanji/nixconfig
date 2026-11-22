// DFS Deutsche Flugsicherung — Ingenieur Site Reliability. Deutsches Anschreiben, eine Seite.
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
DFS Deutsche Flugsicherung GmbH\\
Frau Jessica Kuprat\\
Am DFS Campus 1\\
63225 Langen

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Ingenieur Site Reliability (m/w/d) — J000000038]
#v(0.45cm)

Sehr geehrte Frau Kuprat,

in der Flugsicherung ist ein Ausfall kein Vorfall mit Kostenfolge, sondern eine Frage von Sicherheit. Das
ändert, was von einem Betrieb verlangt wird: nicht die schnelle Reparatur, sondern dass der Zustand vor dem
Eingriff belegt ist, dass die Ursache bekannt ist, bevor gehandelt wird, und dass es einen Weg zurück gibt,
der nicht improvisiert ist. Nach dieser Regel habe ich fünf Jahre lang Systeme betrieben.

Konkret heißt das bei mir: dreizehn Linux-Hosts aus einer Deklaration im Repository, jede Änderung durch ein
Gate, das in der CI und auf dem Host identisch läuft, jeder Rückweg ein Zeiger auf die vorige Generation —
kein halber Rollout, kein Zustand, den nur ein Laptop kennt. Eine Telemetrieschleife prüft alle fünfzehn
Minuten Jobstatus, Generation Age, Disk-Druck und PSI und meldet jeden Wert außerhalb des Erwarteten;
Blindheit gilt dabei als Fehlerfall, nicht als Normalzustand. Störungen verfolge ich mit journald, cgroups,
tcpdump und strace bis zur Ursache und schreibe sie auf, damit der nächste Fall schneller geht.

Was ich nicht mitbringe, sage ich vorab: keine Erfahrung in einer sicherheitskritischen
Echtzeitumgebung und keine Praxis im Schichtbetrieb eines Kontrollzentrums. Meine Systeme waren
geschäftskritisch, nicht verkehrskritisch; ein Ausfall kostete Geld und Vertrauen, nicht Zulassung. Wer
jemanden für den Betrieb von Flugsicherungssystemen ab Tag eins sucht, findet ihn bei Bewerbern aus der
Branche. Wer jemanden sucht, der Betriebsdisziplin, Telemetrie und Reproduzierbarkeit mitbringt und die
Domäne lernt, ist bei mir richtig.

Zu den formalen Voraussetzungen: Ich bin bereit, die Sicherheitsüberprüfung und die
Tauglichkeitsuntersuchung zu durchlaufen, und sage das nicht als Floskel — ich weiß, dass beides Zeit
kostet und dass eine Verweigerung das Verfahren beendet. Ich bin US-Staatsbürger mit deutscher
Niederlassungserlaubnis, also unbefristetem Aufenthaltsrecht und ohne Sponsoringbedarf. Ob eine
Überprüfung für einen nichtdeutschen Staatsangehörigen erteilt wird, entscheidet die zuständige Stelle; ich
nenne das früh, damit es nicht nach der Zusage zum Problem wird. Schichtdienst und Präsenz am Standort
Langen sind für mich selbstverständlich, ein Umzug dorthin eingeplant. Deutsch ist C1, Englisch
Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
