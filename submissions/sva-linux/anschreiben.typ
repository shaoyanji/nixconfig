// SVA — DevOps Engineer / Consultant Linux (j734). Deutsches Anschreiben, eine Seite.
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
SVA System Vertrieb Alexander GmbH\\
Geschäftsstelle Freiburg\\
Schnewlinstraße 12\\
79098 Freiburg im Breisgau

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als DevOps Engineer / Consultant Linux (m/w/d) — j734]
#v(0.45cm)

Sehr geehrte Damen und Herren,

bei einem Systemhaus ist Linux-Arbeit immer Arbeit für jemanden anderen: Der Kunde übernimmt den Betrieb
später selbst, oder er muss erklären können, warum es so aussieht, wie es aussieht. Deshalb beschreibe ich
Systeme lieber, als sie zu reparieren — dreizehn Linux-Hosts aus einer Deklaration im Repository, jede
Änderung durch ein Gate, das in der CI und auf dem Host identisch läuft, jeder Rückweg ein Zeiger auf die
vorige Generation. Ein Kunde kann das lesen, prüfen und selbst weiterführen; eine Sammlung von Handgriffen
kann er nur erben.

Dazu kommt, was im Betrieb täglich gebraucht wird: nftables als Default-Deny, WireGuard und eine eigene
Zertifizierungsstelle für TLS, Secrets pro Host mit SOPS und age verschlüsselt statt in einer Notiz, eine
Telemetrie, die alle fünfzehn Minuten Jobstatus, Generation Age, Disk-Druck und PSI prüft und jeden Zustand
außerhalb des Erwarteten meldet. Fehlersuche mache ich mit journald, cgroups, tcpdump und strace — nicht mit
Neustart und Hoffnung. Kundennähe kenne ich aus zwei Jahren Beratung und aus der IT-Verantwortung für ein
Unternehmen mit Tochtergesellschaften: Anforderungen aufnehmen, Varianten erklären, Entscheidungen
aufschreiben.

Was ich nicht mitbringe: keine Zertifizierungen von Red Hat oder vergleichbaren Herstellern und keine
Erfahrung mit den Plattformprodukten, die SVA sonst im Portfolio hat — Kubernetes und OpenShift habe ich
nicht produktiv administriert. Wer für ein Kundenprojekt einen zertifizierten Spezialisten ab Tag eins
braucht, findet ihn bei anderen Bewerbern; wer jemanden braucht, der Linux, Automatisierung und Übergabe
beherrscht und sich in ein Produkt einarbeitet, ist bei mir richtig.

Zum Rahmen: Ich bewerbe mich ausdrücklich für die *Geschäftsstelle Freiburg, Schnewlinstraße 12* — Gutach
liegt rund 25 Kilometer entfernt, 25 Minuten Arbeitsweg, Präsenz beim Kunden im Umkreis ist für mich kein
Thema. Meine Gehaltsvorstellung liegt bei *85.000 € brutto jährlich*. Ich bin US-Staatsbürger mit deutscher
Niederlassungserlaubnis — unbefristetes Aufenthaltsrecht, kein Sponsoring nötig. Deutsch ist C1, Englisch
Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
