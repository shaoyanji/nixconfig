#set document(title: "Bewerbung True Talent — Senior System Administrator", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  True Talent Solutions Partners \
  Recruiting-Team \
  Freiburg im Breisgau
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Senior System Administrator, Freiburg im Breisgau]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ich wohne in Gutach im Breisgau, rund 30 Kilometer von Freiburg, und kann sofort anfangen. Für eine Stelle vor Ort ist das kein Nebensatz, sondern der Unterschied zwischen einem Kandidaten mit Umzugsplan und einem, der am ersten Tag im Team steht. Seit fünf Jahren betreibe ich die Infrastruktur eines kleinen Betriebs selbst: dreizehn Linux-Server über drei Hardware-Generationen, gemietet, installiert, in Betrieb genommen und über die Jahre getragen.

#v(2pt)
Der Betrieb ist als Code geschrieben, nicht als Gedächtnisleistung. Zugriffsrechte sind Rollen je Host, Netz und Firewall liegen als nftables-Regeln neben den Diensten, DNS und ein WireGuard-Tailnet verbinden die Standorte. Gesichert wird mit restic auf ein NAS, und ich stelle Wiederherstellungen tatsächlich wieder her, statt mich auf die Sicherung zu verlassen. Ein Sentinel-Ledger schreibt alle 15 Minuten Jobstatus, Generation-Alter sowie Disk- und PSI-Druck, Gatus prüft Endpunkte, eine Go-Bridge bestätigt einen Alarm erst, wenn die Zustellung passiert ist. Störungen verfolge ich bis zur systemd-Unit. Geheimnisse liegen in sops und age, Host-Schlüssel kommen aus einer eigenen Zertifizierungsstelle mit kurzlebigen Zertifikaten, und kein Dienst hängt ungeschützt im Netz.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: Proxmox VE habe ich nicht im Produktivbetrieb, Kubernetes nicht als Cluster betrieben, Ceph nicht aufgesetzt. Microsoft 365 und Azure in hybriden Umgebungen sowie Windows Server mit Active Directory sind nicht meine Praxis, Windows betreue ich auf Workstation-Ebene. ISO 27001 und C5 habe ich nicht auditiert, sondern nur die Hygieneseite davon gelebt. Die Anzeige verlangt Proxmox ausdrücklich als Produktionserfahrung; das ist meine größte Lücke, und ich überspiele sie nicht.

#v(2pt)
Deutsch ist bei mir C1, Englisch Muttersprache, also besser als die geforderten B2. Ich arbeite gern in einem kleinen Team, in dem man die Systeme selbst anfasst, und ich dokumentiere, damit das auch andere können. Bitte nennen Sie mir im Erstgespräch den Namen des Unternehmens und die Gehaltsspanne; beides steht nicht in der Anzeige. Mein Repository zeigt die Arbeit ungeschminkt: github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
