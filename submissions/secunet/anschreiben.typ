// secunet Security Networks — Senior Software Engineer Infrastructure / Linux Security (j3550). Deutsches Anschreiben.
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
Frau Nicole Schulz\\
secunet Security Networks AG\\
Kurfürstenstraße 58\\
45138 Essen

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Senior Software Engineer Infrastructure / Linux Security (ID 3550/F)]
#v(0.45cm)

Sehr geehrte Frau Schulz,

Sicherheit in einer Linux-Infrastruktur entsteht nicht durch eine Maßnahme, sondern durch Eigenschaften, die
man an der Konfiguration ablesen kann. Bei mir heißt das: Firewall-Regeln, Zertifikate und Secrets sind Code
mit Historie, dreizehn Hosts entstehen aus einer Deklaration, jede Änderung läuft durch ein Gate, das in der CI
und auf dem Host identisch ist, und der Rückweg ist ein Zeiger auf die vorige Generation. Wer später prüft, ob
ein System gehärtet ist, findet die Antwort im Repository statt in einer Erinnerung.

Konkret: nftables als Default-Deny mit expliziten Freigaben, WireGuard zwischen Standorten, eine eigene
Zertifizierungsstelle für TLS und eine SSH-CA mit kurzlebigen Zertifikaten statt langlebiger Schlüssel, Secrets
pro Host mit SOPS und age verschlüsselt und außerhalb des Repositories im Klartext. Dazu Härtung durch
Minimalumfang und Rechteprüfung, Abhängigkeitsprüfung auf bekannte Schwachstellen und Fehlersuche mit journald,
cgroups, tcpdump und strace bis zur Ursache.

Zur Sicherheitsüberprüfung, weil sie in Ihrer Ausschreibung steht: Ich bin bereit, die Überprüfung nach SÜG
Stufe 2 zu durchlaufen, und habe kein Interesse daran, diesen Punkt später zu relativieren. Ich bin
US-Staatsbürger mit deutscher Niederlassungserlaubnis — unbefristetes Aufenthaltsrecht, kein Sponsoring nötig.
Die Niederlassungserlaubnis ist ein Aufenthaltstitel und keine Staatsbürgerschaft; ob und wie eine Einstufung
nach SÜG 2 für einen nichtdeutschen Staatsangehörigen erteilt wird, entscheidet die zuständige Stelle, nicht
ich. Wenn die Stelle eine erteilte Freigabe voraussetzt, ist das der Punkt, an dem wir früh sprechen sollten;
wenn die Bereitschaft genügt und der Prozess später läuft, ist von meiner Seite alles offen.

Was ich nicht mitbringe: Kubernetes und OpenShift habe ich nicht produktiv administriert. Ich kenne die
Konzepte und den Betrieb darunter — Linux, Netzwerk, Zertifikate, Gates —, aber keinen Mehr-Mandanten-Betrieb
und keine Upgrade-Pfade über Cluster-Versionen. Für eine Rolle, in der Cluster-Administration den Kern bildet,
ist das die ehrliche Lücke.

Meine Beweggründe für secunet sind fachlich: Sicherheit als Produkt und nicht als Prüfpunkt am Projektende.
Ich arbeite auf Deutsch auf C1-Niveau, Englisch ist meine Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
