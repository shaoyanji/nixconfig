// BWI GmbH — Senior Infrastructure/Platform Engineer (m/w/d), Stellen-ID 64059.
// Deutsches Anschreiben, eine Seite.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(left)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.38cm)
#text(size: 9pt)[BWI GmbH]
#linebreak()
#text(size: 9pt)[Auf dem Steinbüchel 22 · 53340 Meckenheim]

#v(0.42cm)
#text(size: 8.6pt, fill: muted)[22. November 2026]

#v(0.42cm)
#text(weight: "bold", size: 10pt)[Bewerbung: Senior Infrastructure/Platform Engineer (m/w/d), Stellen-ID 64059]
#v(0.34cm)

Sehr geehrte Damen und Herren,

Ihre Stelle im DevSecOps Engineering verbindet die drei Themen, an denen ich in den letzten sechs Jahren gearbeitet habe: Linux-Plattformen,
Automatisierung und Sicherheit. Ich habe eine NixOS-Flotte mit dreizehn Hosts allein aufgebaut und betrieben, deklariert in einem Flake mit gepinnten
Inputs. Jeder Host ist eine Liste von Modulen, die Auswertung läuft pro Host und bricht ab, bevor ein fehlerhafter Stand gebaut wird, und jede Änderung
ist eine Generation, die sich zurückrollen lässt. Für air-gapped Rechenzentren ist genau das der entscheidende Teil: nicht das Werkzeug, sondern dass
ein Zustand reproduzierbar und der Rückweg geprüft ist.

Sicherheit habe ich als Teil der Deklaration gebaut, nicht als Nacharbeit: systemd-Dienste mit `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp` und
`NoNewPrivileges`, ein eigener Benutzer je Dienst, Firewall-Freigaben je Dienst und Netz mit datierten Streichungen, Zugriff über eine eigene SSH-
Zertifizierungsstelle mit kurzlebigen Zertifikaten statt stehender Schlüssel, Secrets SOPS-verschlüsselt mit einem age-Schlüssel je Host.

Automatisierung ist bei mir ein Vertrag: Aufgaben mit typisierten Argumenten, Planungslauf ohne Wirkung, JSON-Ausgabe und einem Exit-Code je Ergebnis,
dazu Pre-Commit- und Pre-Push-Gates für Format, Syntax und Textregeln. Im Betrieb schreibt ein Sentinel Job-Status, Generationsalter, Disk- und
PSI-Werte alle fünfzehn Minuten in ein Journal und alarmiert auf schlechten Zustand und auf Stille, weil ein ausgefallener Melder sonst wie ein gesunder
Host aussieht. PostgreSQL betreibe ich mit geordneten Migrationen und einem Wiederherstellungsdrill, der einen Dump in einen temporären Cluster spielt
und Tabellen- und Zeilenzahlen prüft.

Wo ich unter Ihrem Profil bleibe, sage ich vorab: Kubernetes habe ich nicht in Produktion betrieben, weder als Cluster noch air-gapped, und ich habe
weder CKA noch CKS. Ceph kenne ich nicht aus dem Betrieb; meine Storage-Erfahrung sind ZFS, SMART/NVMe, NFS/SMB und Backups. Virtualisierung kenne ich
aus KVM- und microVM-Laboren, nicht aus VMware oder OpenStack im Großbetrieb. Mit bringe ich die Basis, auf der ein Cluster trägt: Härtung,
reproduzierbare Images, klare Netzgrenzen und einen geprüften Rückweg. Diese Lücke würde ich in den ersten Monaten schließen.

Ich bin US-amerikanischer Staatsbürger mit unbefristeter deutscher Niederlassungserlaubnis, also ohne Sponsoring arbeitsberechtigt; einer
Sicherheitsüberprüfung nach SÜG sehe ich offen entgegen. Deutsch spreche ich auf C1-Niveau, Englisch als Muttersprache. Für die Rolle ziehe ich an einen
der Standorte Bonn, Köln oder Meckenheim, Reisebereitschaft bringe ich mit, mein frühester Eintritt ist der 01.12.2026. Meine Gehaltsvorstellung liegt
mit 88.000 bis 91.650 EUR brutto jährlich an der Oberkante Ihres ausgeschriebenen Bandes.

Mit freundlichen Grüßen,
#v(0.4cm)
Matt Ji
