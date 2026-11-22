# Bewerbung DKRZ Hamburg - IT-Security-Systemadministrator (m/w/d)

Stand: 22. November 2026
Fit: 3 / 5

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Deutsches Klimarechenzentrum GmbH (DKRZ), Abteilung Systeme |
| Rolle | IT-Security-Systemadministrator (m/w/d) |
| Arbeitsort | Bundesstraße 45a, 20146 Hamburg |
| Arbeitsmodell | Vollzeit, hybrid |
| Erfahrung | Mit Berufserfahrung |
| Veröffentlicht | 27.04.2026 über softgarden |
| Frist | Keine genannt |
| Anzeige | https://www.dkrz.de/de/about/stellenangebote/64384773 |

## Bewerbungsweg

Über die DKRZ-Stellenangebotsseite, die auf das softgarden-Portal führt. Kein Ansprechpartner und kein Datum in der Anzeige; die Veröffentlichung ist vom 27. April 2026, also sieben Monate alt. Vor dem Absenden prüfen, ob die Stelle noch besetzt wird, und im Anschreiben nicht auf eine Frist verweisen, die es nicht gibt.

Es wurde nichts abgeschickt.

### Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, DIN-5008-nah, deutsch |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, direkt kompilierbar |
| Zeugnisse | keine Datei | Müssen ergänzt werden |

## Warum dieses Zentrum

Geprüft wurden am 22.11.2026 alle vier angefragten HPC-Zentren:

| Zentrum | Befund |
| :--- | :--- |
| FZ Jülich / JSC | Die Stellenpfade liefern 404, die Recruiting-Detailseite 410. Keine offene Stelle verifizierbar. |
| LRZ Garching | HPC System Administrator und HPC Interconnect Specialist existieren, beide Personio-Seiten liefern 404; die Fristen 22.07.2026 und 08.11.2026 sind abgelaufen. |
| DKRZ Hamburg | IT-Security-Systemadministrator steht auf der eigenen Stellenangebotsseite und ist über softgarden erreichbar. Offen. |
| KIT / SCC | Zwei offene Stellen, aber weder Clusteradministration noch Linux-Betrieb: Lebenszyklusanalyse von Rechenzentrumsinfrastruktur und eine IT-/Elektrofachkraft (EG 9b). |

Damit ist DKRZ der einzige belastbare Treffer. Die Rolle ist sicherheitslastig, nicht klassische Clusteradministration, und das schlägt sich in der Fit-Zahl nieder.

## HPC- und Scientific-Computing-Abgleich

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Mehrjähriger Betrieb von Linux-Systemen (Debian, Ubuntu, RHEL, Rocky, Alma) | Dreizehn NixOS-Hosts, Debian-nah, systemd bis zur Unit | Stark |
| Netzwerksicherheit: Routing, VLAN, IPv6, DNSSEC | nftables als Code, WireGuard, DNS selbst konfiguriert; kein VLAN-Design, kein DNSSEC | Teilweise |
| Linux-Security: SELinux, AppArmor, systemd-Härtung | systemd-Härtung und Ressourcenlimits; keine MAC-Profile | Teilweise |
| Kryptographische Verfahren: TLS, PKI, SSH | Eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, sops und age | Stark |
| Automatisierung: Ansible, Bash, Python, Puppet | Bash, Python, Go, Git-Gates; kein Ansible, kein Puppet | Teilweise |
| Git-basierte Infrastrukturverwaltung und IaC | Die gesamte Flotte liegt als Code in Git, Gates je Host, Rückrollung je Generation | Sehr stark, das ist der Kern |
| IDS/IPS, SIEM (Wazuh, Elastic, Graylog), zentrale Logs | Nicht vorhanden; Monitoring ist selbst gebaut, kein SIEM | Lücke |
| Schwachstellenmanagement, CVE-Bewertung, Incident Response | Keine Praxis in einer Organisation | Lücke |
| Container und Virtualisierung absichern (Docker, Podman, Kubernetes, OpenStack) | Keine Cluster- oder OpenStack-Praxis | Lücke |
| Identity Management (LDAP, FreeIPA, Keycloak), föderierte Authentifizierung | Nicht vorhanden | Lücke |
| BSI IT-Grundschutz | Sicherheitshygiene gelebt, Grundschutz nicht umgesetzt | Lücke |
| Hochleistungsrechnen im Betrieb | Keine HPC-Cluster-Praxis; wissenschaftliche IT aus ISE-Zeit bekannt | Teilweise |
| Wissenschaftliche IT-Workflows | Fraunhofer ISE 2012, Laborgeräte, Messdaten | Teilweise |

## Fit-Begründung: 3 von 5

Drei, weil zwei Dinge zusammenkommen, die selten zusammen kommen: die gesamte Infrastruktur liegt tatsächlich als Code in Git, und PKI, Schlüssel und Geheimnisse sind selbst gebaut und betrieben. Genau diese Punkte stehen in der Anzeige als Wunsch, einer davon wörtlich als "Git-basierte Infrastrukturverwaltung und Infrastructure as Code".

Nicht vier, weil die Kernaufgaben Sicherheitsbetrieb sind: IDS/IPS, SIEM, Schwachstellenmanagement, Incident Response, BSI-Grundschutz-Umsetzung. Nichts davon ist vorhanden, und ein Klimarechenzentrum kann diese Lücke nicht mit Einarbeitung in den ersten Wochen schließen. Nicht zwei, weil die Linux-, PKI- und Automatisierungsbasis echt ist und die Anzeige die Sicherheitsrolle ausdrücklich auf Open-Source-Technologien und Transparenz stellt.

## Öffentlicher Sektor und Entgelt

Das DKRZ ist eine gemeinnützige GmbH mit öffentlicher Förderung und betreibt die nationale Klimamodellierungsinfrastruktur. Ein Tarifvertrag ist in der Anzeige nicht genannt; TV-L oder eine Anlehnung daran ist bei vergleichbaren Zentren üblich, hier aber nicht belegt. Deshalb steht im Anschreiben keine Zahl, und die eigene Erwartung von 85.000 bis 95.000 EUR bleibt offen.

Was bei öffentlich geförderten Zentren zu erwarten ist: unbefristete oder lange befristete Verträge, verlässliche Arbeitszeit, Fortbildung, kein Bonusmodell. Was nicht zu erwarten ist: Gehaltssprünge durch Verhandlung. Die Stufe ist das Gesprächsthema.

## Formularzuordnung

Das softgarden-Portal wurde nicht gerendert. Werte ohne belegte Feld-IDs; Beschriftungen vor dem Absenden gegenprüfen.

| Feld | Wert |
| :--- | :--- |
| Anrede | Damen und Herren |
| Vorname | Matt |
| Nachname | Ji |
| E-Mail | matt@bountystash.com |
| Telefon | +49 1733281570 |
| Straße | Am Burgerhof 4 |
| PLZ | 79261 |
| Ort | Gutach im Breisgau |
| Stelle | IT-Security-Systemadministrator (m/w/d) |
| Referenz | DKRZ-Angebot 64384773 |
| Eintritt | Nach Vereinbarung |
| Anschreiben | `anschreiben.pdf` |
| Lebenslauf | `lebenslauf.pdf` |

## Offene Punkte

1. Prüfen, ob die Anzeige vom 27.04.2026 noch aktiv ist; sieben Monate sind für eine Sicherheitsstelle lang.
2. SIEM-, IDS/IPS- und Incident-Response-Lücke nicht überspielen; das Anschreiben benennt sie gesammelt.
3. Zeugnisse fehlen im Paket.
4. Umzug nach Hamburg entscheiden; hybrid ist zugesagt, Präsenz in Bundesstraße bleibt.
5. Entgeltband beim Erstgespräch erfragen; die Anzeige nennt keines.
6. Fit 3 ist bewusst konservativ; die DB führt denselben Wert.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Anzeige im Volltext von der DKRZ-Seite. |
| `lebenslauf.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `anschreiben.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Feldzuordnung. |
