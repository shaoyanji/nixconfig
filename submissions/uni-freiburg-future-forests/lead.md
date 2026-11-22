# Lead: Universität Freiburg - IT-Administration im Exzellenzcluster Future Forests

Fit: 4
Stand: 22.11.2026

## Warum interessant

Future Forests ist ein interdisziplinäres Forschungszentrum der Universität Freiburg zu Anpassung und Wandel von Wäldern: Fernerkundung, Modellierung von Waldökosystemen, digitale Beteiligung. Die Forschung ist daten- und softwareintensiv, und genau dafür wird jemand gesucht, der die IT des Clusters betreut: Server, Desktops, Laptops, Netzwerk, Peripherie, Telefonie, dazu Forschungsdaten-Repositorien, Virtualisierung und Datenanalyse-Plattformen. Dazu Verfügbarkeit über Monitoring, Patch-Management und Backups mit Wiederherstellungstests, Datenschutz und BSI-Grundschutz, Dokumentation und Zusammenarbeit mit dem Rechenzentrum.

Der Ort ist der eigentliche Grund: Gutach im Breisgau liegt rund 20 km entfernt, die Universität Freiburg ist die Alma Mater (M.Sc. 2014). Kein Umzug, kein Pendelzimmer, sofort verfügbar.

## Was passt

- Linux-Betrieb über dreizehn Hosts und drei Hardware-Generationen, inklusive Beschaffung und Inbetriebnahme.
- Backup und Wiederherstellung: restic auf ein NAS, und die Rücksicherung wird tatsächlich durchgeführt, nicht nur der Job geprüft. Die Anzeige verlangt genau das.
- Monitoring: Sentinel-Ledger alle 15 Minuten mit Jobstatus, Generation-Alter, Disk- und PSI-Druck, Gatus-Prüfungen, Go-Bridge mit Zustellbestätigung.
- Netzwerk: nftables als Code, DNS selbst konfiguriert, WireGuard-Tailnet zwischen Standorten, TCP/IP bis zur Fehlersuche.
- Sicherheit und Datenschutz: sops und age für Geheimnisse, eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, keine öffentliche Schnittstelle, Rechte als Rollen je Host.
- Dokumentation und Service: jede Prozedur als Runbook, Anleitung von Nutzenden, Support bei Hard- und Softwarefragen.
- Hochschulabschluss vorhanden (M.Sc. Universität Freiburg), Deutsch C1, Englisch Muttersprache.
- Wissenschaftliche Umgebung aus eigener Zeit: 2012 am Fraunhofer ISE mit Laborgeräten und Messdaten.

## Was fehlt

- Windows- und macOS-Administration im geforderten Umfang: Windows nur auf Workstation-Ebene, macOS nicht administriert. Die Anzeige verlangt fundierte Kenntnisse in allen drei Systemen.
- Virtualisierung mit VMware, Hyper-V oder KVM und Container mit Docker oder Kubernetes: keine Praxis, und beides ist als Vorteil genannt.
- Identity und Access Management: kein Active Directory, kein LDAP, kein Keycloak.
- Matrix, Microsoft 365 und Collaboration-Tools im Institutsbetrieb: nicht administriert.
- Patch-Management über eine Flotte mit heterogenen Clients: im eigenen Umfeld ja, im Institutsmaßstab nein.
- BSI IT-Grundschutz: Sicherheitshygiene gelebt, Grundschutz nicht umgesetzt.
- Teilzeit 50 Prozent: das ist der größte praktische Vorbehalt, nicht die Qualifikation.

## Weg

Schriftlich oder elektronisch an die Universität Freiburg, Exzellenzcluster Future Forests, Stadtstr. 5, 79104 Freiburg, unter der Kennziffer 00005265. Kontakt für Fragen: Dr. May-Britt Becker, +49 761 203-3648, may-britt.becker@futureforests.uni-freiburg.de.

Die Frist ist widersprüchlich: Die deutsche Fassung nennt den 31.12.2026, die englische den 4. Januar 2027. Vor dem Absenden die Anzeige erneut öffnen.

## Gehalt

Kein Entgelt in der Anzeige. Universitäten in Baden-Württemberg zahlen nach TV-L; bei einem 50-Prozent-Umfang liegt das Gehalt entsprechend bei der Hälfte einer Vollzeitstelle. Die eigene Erwartung von 85.000 bis 95.000 EUR ist damit nicht erreichbar. Im Anschreiben steht keine Zahl.
