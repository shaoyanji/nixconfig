// Mittwald CM Service — DevOps Engineer. Deutsches Anschreiben, eine Seite.
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
Mittwald CM Service GmbH & Co. KG\\
Espelkamp

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als DevOps Engineer (m/w/d)]
#v(0.45cm)

Sehr geehrte Damen und Herren,

Sie schreiben, dass Sie längst kein klassischer Webhosting-Anbieter mehr sind. Genau das ist der Punkt,
an dem ich arbeite: Wer tausende Webprojekte trägt, kann Zuverlässigkeit nicht behaupten, sondern muss sie
belegen. Ich betreibe dreizehn Linux-Hosts, und ich kenne ihren Zustand, ohne eine Shell zu öffnen.

Der Zustand dieser Hosts steht in einer Deklaration im Repository, jede Maschine zieht ihn von dort, und
keine Änderung erreicht einen Host ohne ein Gate, das in der CI und auf dem Host selbst läuft. Ein Release
ist ein Schritt; der Rückweg ist ein Zeiger auf die vorige Generation. Web-Dienste laufen hinter nginx mit
TLS und Reverse Proxy, die Zertifikate kommen aus einer eigenen Zertifizierungsstelle mit kurzlebigen
Zertifikaten. Logs und Ereignisse laufen über journald, Last lese ich über PSI und cgroups, Speichergrenzen
setze ich pro systemd-Slice, und wenn MTU oder DNS nicht stimmen, zeigt tcpdump es. Instanzen entstehen über
PXE und iVentoy, nicht über Handarbeit; Caching ist bei mir Betriebsmittel, nicht Nachgedanke.

Was ich nicht mitbringe, sage ich vor dem ersten Gespräch: Kubernetes und Helm habe ich nicht betrieben,
weder Cluster noch Operatoren noch Bare-Metal-Deployments. Container waren für mich gepinnte
Bauumgebungen, keine Plattform. Genau deshalb bewerbe ich mich bei Ihnen und nicht auf eine
Senior-Plattformstelle: Sie schreiben, dass Sie die Leute für den Stack fit machen — Go, Linux, Kubernetes
und Helm —, und das ist für mich der Grund, diesen Schritt jetzt zu gehen statt ihn zu behaupten. Go und
Linux bringe ich mit; das Cluster-Layer ist der Lernanteil, den ich im viermonatigen Onboarding abarbeiten
will.

Zum Rahmen: Espelkamp liegt rund 700 Kilometer von Gutach im Breisgau entfernt. Für die Einarbeitung und
regelmäßige Teamtage komme ich gern vor Ort; ob die Stelle teilweise remote ausgeübt werden kann, frage ich
offen, weil andere Mittwald-Stellen ein hybrides Arbeitsumfeld nennen und diese Ausschreibung es nicht
ausdrücklich tut. Meine Gehaltsvorstellung liegt bei 58.000 bis 62.000 Euro brutto; ich weiß, dass die
ausgeschriebene Bandbreite bei 60.000 endet, und über eine Einordnung am oberen Ende spreche ich gern.
Start zum 04.01.2027 passt. Deutsch ist C1, Englisch Muttersprache, ich bin US-Staatsbürger mit deutschem
Niederlassungsrecht und brauche kein Sponsoring.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
