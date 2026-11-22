// VertiGIS — Cloud Engineer (m/w/x). Deutsches Anschreiben, eine Seite.
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
VertiGIS GmbH\\
CloudOps\\
Berlin

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Bewerbung als Cloud Engineer (m/w/x) — Cloud-Betrieb von SaaS-Lösungen]
#v(0.45cm)

Sehr geehrte Damen und Herren,

Sie beschreiben die Stelle als Betrieb einer SaaS-Lösung in einer Azure Landing Zone: überwachen,
Störungen beheben, Änderungen automatisiert und dokumentiert ausrollen, Umgebungen härten. Das ist die
Arbeit, die ich seit fünf Jahren mache, nur auf einer anderen Plattform — und weil Ihre Lösungen Netze,
Anlagen und Prozesse von Energieversorgern und Kommunen abbilden, kenne ich auch die Sprache der Kunden.

Ich betreibe dreizehn Linux-Hosts aus einer Deklaration im Repository. Jede Maschine zieht ihren Zustand
von dort, keine Änderung erreicht einen Host ohne ein Gate, das in der CI und auf dem Host selbst läuft,
und der Rückweg ist ein Zeiger auf die vorige Generation. Monitoring ist bei mir eine Aufzeichnung, kein
Dashboard: Jobstatus, Generation Age, Disk-Druck und PSI alle fünfzehn Minuten, Meldung auf jeden Zustand
ungleich ok. Störungen analysiere ich mit journald, cgroups und tcpdump, und ich schreibe Ursache und
Behebung auf, damit der nächste Fall schneller geht. Netzwerk und Härtung sind Handwerk: WireGuard,
nftables als Default-Deny, eigene DNS-Zone, TLS aus einer internen Zertifizierungsstelle, Secrets pro Host
mit SOPS und age verschlüsselt, Zugriff über kurzlebige Zertifikate statt stehender Schlüssel.

Was ich nicht mitbringe, sage ich vorab: Azure habe ich nicht betrieben, Bicep nicht geschrieben, und
Windows Server ist nicht meine Tiefe — meine Cloud-Erfahrung sind Oracle-Hosts und ein kleines
Lambda-Projekt. Die Konzepte dahinter sind mir vertraut: Infrastruktur als Code, Pipelines mit
anschließender Funktionsprüfung, CIS-Härtung als Voreinstellung statt Projekt, Monitoring und Log-Analyse
im laufenden Betrieb. Ich würde die Azure-Seite zügig aufholen und die Betriebsdisziplin mitbringen, die
eine Landing Zone erst nutzbar macht.

Ich arbeite von Gutach im Breisgau aus, Deutsch ist C1, Englisch Muttersprache, und ich bin US-Staatsbürger
mit deutscher Niederlassungserlaubnis ohne Sponsoringbedarf. Die zugesagte mobile Arbeit passt zu mir; für
Abstimmung und Wartungsfenster komme ich gern vor Ort. Meine Gehaltsvorstellung bespreche ich anhand der
Bandbreite, die Sie für die Rolle vorgesehen haben. Ein Einstieg ist kurzfristig möglich.

Mit freundlichen Grüßen,
#v(0.5cm)
Matt Ji
