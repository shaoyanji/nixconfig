// SVA — DevOps Consultant Infrastructure Automation. Deutsches Anschreiben, eine Seite.
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
#text(weight: "bold", size: 10.3pt)[Bewerbung als DevOps Consultant Infrastructure Automation (m/w/d)]
#v(0.45cm)

Sehr geehrte Damen und Herren,

Automatisierung ist im Kundenprojekt eine Frage mit zwei Antworten. Die erste ist technisch: Lässt sich der
Zustand beschreiben, statt ihn herzustellen? Die zweite ist organisatorisch: Nimmt der Kunde die Automatisierung
danach selbst in Betrieb, oder braucht er mich dafür? Ich baue deshalb für die zweite Antwort: dreizehn
Linux-Hosts aus einer Deklaration im Repository, jede Änderung durch ein Gate, das in der CI und auf dem Host
identisch läuft, jeder Rückweg ein Zeiger auf die vorige Generation, und jeder wiederkehrende Handgriff als
Werkzeug hinter einer Task-Oberfläche mit Argumenten und Hilfetext.

Konkret heißt das: Provisionierung über PXE und iVentoy vom Installer bis zur Erstkonfiguration; Go-, Python-
und Bash-Werkzeuge für Abläufe, die vorher jemand aus dem Gedächtnis ausgeführt hat; ein Ledger, das alle
fünfzehn Minuten Jobstatus, Generation Age, Disk-Druck und PSI prüft und jeden Zustand ungleich ok meldet;
Härtung mit nftables als Default-Deny, SOPS/age-verschlüsselten Secrets pro Host und einer SSH-CA mit
kurzlebigen Zertifikaten. Kleine Werkzeuge mit klarer Schnittstelle statt eines Skripts, das alles tut — weil
eine Automatisierung, die niemand mehr ändern kann, nur eine andere Form von Handarbeit ist.

Zur Beratungsseite: Zwei Jahre habe ich Mandanten zu Strategie und Risiko beraten, mit Datenmodellen als
Grundlage, und davor die IT eines Unternehmens mit Tochtergesellschaften verantwortet. Anforderungen aufnehmen,
Varianten erklären, Entscheidungen aufschreiben und eine Übergabe liefern, die ohne Rückfrage funktioniert —
das ist die Arbeit, die zwischen Technik und Kunde liegt.

Was ich nicht mitbringe: keine Zertifizierungen von Herstellern, keine produktive Erfahrung mit Terraform,
Ansible oder Kubernetes, und keine Praxis mit den Plattformprodukten, die SVA sonst im Portfolio hat. Meine
Automatisierung ist in Nix, Go und Shell zu Hause. Wer für ein Kundenprojekt einen zertifizierten Spezialisten
ab Tag eins braucht, findet ihn bei anderen Bewerbern; wer jemanden braucht, der Automatisierung sauber aufbaut
und erklären kann, ist bei mir richtig.

Zum Rahmen: Ich bewerbe mich für die Geschäftsstelle Freiburg, Schnewlinstraße 12 — rund 25 Kilometer von
meinem Wohnort, Präsenz beim Kunden im Umkreis ist für mich normal. Ich bin US-Staatsbürger mit deutscher
Niederlassungserlaubnis, unbefristetes Aufenthaltsrecht, kein Sponsoring nötig. Deutsch C1, Englisch
Muttersprache.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
