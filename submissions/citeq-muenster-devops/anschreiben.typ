// citeq — DevOps Engineer (m/w/d). Deutsches Anschreiben, eine Seite.
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
citeq — IT-Dienstleister der Stadt Münster\\
Herrn Tobias Burgmann · Herrn Oliver Musiolik\\
Scheibenstraße 109\\
48153 Münster

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als DevOps Engineer (m/w/d) — 22-029/26, Interamt 1510832]
#v(0.45cm)

Sehr geehrte Herren Burgmann und Musiolik,

kommunale IT hat eine Bedingung, die in der freien Wirtschaft optional ist: Der Betrieb muss erklärbar
bleiben. Wer später fragt, welche Konfiguration galt, wer sie geändert hat und wie man zurückkommt, braucht
eine Antwort aus Aufzeichnungen — nicht aus der Erinnerung eines Kollegen, der vielleicht nicht mehr da ist.
Genau so habe ich fünf Jahre lang Systeme betrieben: dreizehn Linux-Hosts aus einer Deklaration im
Repository, Webdienste mit nginx und TLS über eine eigene Zertifizierungsstelle, jede Änderung durch ein
Gate, das in der CI und auf dem Host identisch läuft, jeder Rückweg ein Zeiger auf die vorige Generation.

Dazu kommt die Seite, die bei einer Stadt besonders zählt: Souveränität als Betriebsfrage. Secrets liegen
pro Host mit SOPS und age verschlüsselt vor, Zugang läuft über eine SSH-CA mit kurzlebigen Zertifikaten
statt über geteilte Schlüssel, nftables setzt Default-Deny mit expliziten Freigaben, und seit 2024 betreibe
ich eine lokale Inferenz-Plattform auf eigener Hardware, damit Anfragen das Haus nicht verlassen. Das ist
keine Haltung, sondern eine Entscheidung darüber, wo Daten liegen — und sie lässt sich prüfen.

Was ich nicht mitbringe: Erfahrung in einem Rechenzentrum mit kommunalen Verfahren und keine
Verwaltungsroutine — keine Haushaltsvorgänge, keine Abstimmung mit Fachämtern, keine Arbeit in einem
IT-Verbund. Meine Umgebung war kleiner und schneller. Ich bringe dafür den Betrieb und die Gewohnheit mit,
Änderungen zu begründen, und ich lerne Verwaltungswege schneller, als ich Betriebsdenken nachträglich
lernen könnte.

Zum Rahmen: Die Eingruppierung nach TVöD beziehungsweise TV IKT in E 11 entspricht meiner Erfahrung; eine
Euro-Zahl nenne ich nicht, weil die Stelle sie vorgibt. Ich bin US-Staatsbürger mit deutscher
Niederlassungserlaubnis — unbefristetes Aufenthaltsrecht, kein Sponsoring nötig — und bereit, nach Münster
zu ziehen. Deutsch ist C1, Englisch Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
