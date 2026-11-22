// EWERK GROUP — Senior Platform / DevOps Engineer. Deutsches Anschreiben, eine Seite.
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
EWERK GROUP\\
Leipzig

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Senior Platform / DevOps Engineer (m/w/d)]
#v(0.45cm)

Sehr geehrte Damen und Herren,

in der Energiebranche habe ich angefangen, und die Frage, die mich dort geprägt hat, ist dieselbe, die eine
Plattform im KRITIS-Umfeld trägt: Läuft es, und wenn es nicht läuft, weiß jemand warum und wie man
zurückkommt? Vier Jahre lang habe ich Ertragsmodelle und Telemetrie für ein Solarportfolio über 100 Mio. USD
verantwortet und dabei gelernt, dass fehlende Messwerte keine Fußnote sind, sondern ein Betriebsrisiko. Die
fünf Jahre danach habe ich Systeme so gebaut, dass diese Frage eine Antwort aus Aufzeichnungen bekommt statt
aus Erinnerung: dreizehn Linux-Hosts aus einer Deklaration, jede Änderung durch ein Gate, das in der CI und
auf dem Host identisch ist, jeder Rückweg ein Zeiger auf die vorige Generation.

Zuverlässigkeit ist für mich kein Zustand, den man behauptet, sondern einer, den man sieht. Ein Ledger prüft
alle fünfzehn Minuten Jobstatus, Generation Age, Disk-Druck und PSI und meldet jeden Wert außerhalb des
Erwarteten — bevor ein Anwender anruft. PSI und cgroups nutze ich als Lastsignal, um zu unterscheiden, ob ein
Host an Speicher oder Ein-/Ausgabe leidet. Härtung ist bei mir Voreinstellung: nftables als Default-Deny,
Secrets pro Host mit SOPS und age verschlüsselt, Zugang über eine SSH-CA mit kurzlebigen Zertifikaten,
Rechte nach dem Minimum. Und weil ein Eingriff ohne Rückweg kein Betrieb ist, ist der Rollback Teil des
Entwurfs, nicht der Notfallplan.

Was ich nicht mitbringe, sage ich vorab: Eine KRITIS-Umgebung nach BSI-Vorgaben habe ich nicht verantwortet
— keine Auditierung, keine Meldepflichten gegenüber einer Aufsicht, keine dokumentierte
Krisenorganisation. Meine KRITIS-Nähe ist fachlich, nicht formal: Ich kenne die Lastprofile und die
Sprache der Branche aus dem Asset Management und den Betrieb aus dem eigenen Fuhrpark. Wer die
Compliance-Seite ab Tag eins braucht, findet sie bei anderen Bewerbern; wer jemanden braucht, der den
Betrieb und die Nachvollziehbarkeit mitbringt und die formale Seite dazulernt, ist bei mir richtig.

Zum Rahmen: Ich habe fünf Jahre vollständig ortsunabhängig gearbeitet — Remote ist für mich kein Zugeständnis,
sondern die Arbeitsform, in der ich Dokumentation und Übergabe ernst nehme. Ich bin US-Staatsbürger mit
deutscher Niederlassungserlaubnis, unbefristetes Aufenthaltsrecht, kein Sponsoring nötig. Deutsch ist C1,
Englisch Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
