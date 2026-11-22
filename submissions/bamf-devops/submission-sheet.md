# Bundesamt für Migration und Flüchtlinge (BAMF) — mehrere DevOps-Engineers (m/w/d) — Public Cloud / Plattformdienste

**Interamt `1513998`, Kennziffer `BAMF-2025-358`.** Referat 22B — Plattform- und Cloudservices,
Dienstort Nürnberg. Mehrere Stellen: unbefristet sowie befristet auf 24 Monate. Status: Packet
fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `bamf-devops` |
| Interamt-ID | 1513998 |
| Kennziffer | BAMF-2025-358 |
| Arbeitgeber | Bundesamt für Migration und Flüchtlinge |
| Organisationseinheit | Referat 22B — Plattform- und Cloudservices |
| Dienstort | Nürnberg, hybrid |
| Entgelt | **E 10 – E 12 TV EntgO Bund** (bzw. A 10 – A 12 BBesO) |
| Laufzeit | unbefristet oder befristet auf 24 Monate |
| Sicherheitsüberprüfung | **SÜ1** nach § 5 AsylG i. V. m. § 8 SÜG, Bereitschaft erforderlich |
| Sprache | Deutsch, C1 nach GER nachzuweisen |
| Bewerbungsweg | Interamt bzw. Bewerbungsseite der Behörde |

## Frist — was der Text hergibt

Der Ausschreibungstext in `job-description.txt` nennt **kein Datum** für die Bewerbungsfrist; er
verweist nur darauf, dass ein Studium bis drei Monate nach Fristende abgeschlossen sein darf. Die
Angabe **18.12.2026** stammt aus `lead.md` (Sweep-Notiz), nicht aus dem Dokument — sie ist vor der
Bewerbung am Interamt-Eintrag zu prüfen, nicht zu übernehmen.

## Kandidatenangaben

| Angabe | Wert |
| :--- | :--- |
| Name | Matt Ji |
| Anschrift | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-Mail / Telefon | matt@bountystash.com / +49 173 3281570 |
| Sprachen | Deutsch C1, Englisch Muttersprache |
| Arbeitserlaubnis | US-Staatsbürger mit deutschem Niederlassungsrecht, kein Sponsoring |
| Entfernung | ~400 km nach Nürnberg; hybrid, Präsenzblöcke |
| Eintritt | nächstmöglicher Zeitpunkt |

## TV EntgO Bund E 10 – E 12 — Struktur statt Zahl

Die Ausschreibung nennt die Bandbreite selbst und macht die Bedingung für die oberste Stufe
ausdrücklich: **E 12 setzt voraus, dass die persönlichen Voraussetzungen in jedem Fall vorliegen und
im Einzelfall geprüft werden.** Deshalb steht im Anschreiben keine Eurosumme, sondern das Ziel
E 12 mit dem Mindestanspruch E 11 — bei einer Eingruppierung entscheidet die Fallprüfung, nicht die
Forderung.

| Punkt | Stand |
| :--- | :--- |
| Entgeltgruppe | E 10 – E 12 TV EntgO Bund, Stufe nach Berufserfahrung |
| Ziel im Anschreiben | **E 12 angestrebt, mindestens E 11** |
| Laufzeit | unbefristet **oder** 24 Monate — die Ausschreibung nennt beides |
| Beamtenlaufbahn | A 10 – A 12 BBesO, für Beamtinnen und Beamte offen |
| Eurobetrag | keiner im Anschreiben; die Tabelle ist nicht Teil der Ausschreibung |
| Sicherheitsüberprüfung | SÜ1, Bereitschaft im Anschreiben ausdrücklich erklärt |

## Fit-Map

| Anforderung (Ausschreibung) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Virtualisierte und containerisierte Plattformen über den Lifecycle betreiben | Deklarierte MicroVMs als Gäste, PXE-Bereitstellung, Rebuild, Rollback; keine Container-Plattform als Ganzes | teilweise |
| Linux und Kubernetes als Plattformbasis | Linux stark; **Kubernetes/OpenShift nicht produktiv betrieben** | **Lücke** bei Kubernetes |
| Störungen identifizieren, Entstörung, Monitoring im Blick | Sentinel-Ledger, journald, cgroups, tcpdump; Analyse über Host-, Unit- und Zeitgrenzen | stark |
| Automatisierung von Betriebsprozessen | Deklaration, Gates in CI und Host, wiederkehrende Handgriffe als Checks | stark |
| Infrastructure as Code (z. B. Ansible/Terraform) | **Nix statt Ansible/Terraform**; gepinnte Inputs, gleiche Prüfung in CI und Host | **Lücke** im Werkzeug, Konzept stark |
| Scripting (Bash, Python) | Go, Python, Bash hinter einer Task-Schnittstelle | stark |
| Konzepte und Dokumentation erstellen und pflegen | Runbooks, Host-Dossiers, Entscheidungsnotizen auf Deutsch | stark |
| Enablement: Teams bei der Plattformnutzung unterstützen | Anwenderbetreuung bei O3 Energy; Betriebswissen im Repository statt im Kopf | stark |
| Hochverfügbarkeit und Skalierung | Dreizehn Hosts, keine Rechenzentrums-Redundanz verantwortet | teilweise |
| Public Cloud | kleines AWS-Lambda-Projekt, Oracle-Cloud-Hosts; kein Multi-Account-Betrieb | teilweise |
| Deutsch C1 | Anschreiben und Unterlagen auf Deutsch, C1 | stark |
| SÜ1-Bereitschaft | im Anschreiben ausdrücklich erklärt | erfüllt |
| Studium/Berufserfahrung nach E 10 – E 12-Bewertung | M.Sc. und B.Sc., über zehn Jahre IT-Betrieb | erfüllt |

## Interamt-Zuordnung

| # | Feld | Antwort |
| :-- | :--- | :--- |
| 1 | Interamt-ID / Kennziffer | 1513998 / BAMF-2025-358 |
| 2 | Anrede / Vorname | Herr, Matt |
| 3 | Nachname | Ji |
| 4 | E-Mail | matt@bountystash.com |
| 5 | Telefon | +49 173 3281570 |
| 6 | Anschrift | Am Burgerhof 4, 79261 Gutach im Breisgau |
| 7 | Anschreiben | `anschreiben.pdf` (1 Seite) |
| 8 | Lebenslauf | `lebenslauf.pdf` (2 Seiten) |
| 9 | Qualifikation | M.Sc. Erneuerbare-Energien-Management, B.Sc. Erdöltechnik |
| 10 | Berufserfahrung | 2010 – heute, zuletzt selbstständige Plattformarbeit |
| 11 | Entgeltvorstellung | E 12 angestrebt, mindestens E 11 |
| 12 | Frühester Eintritt | nächstmöglicher Zeitpunkt |
| 13 | Arbeitsmodell | hybrid, Präsenzblöcke in Nürnberg |
| 14 | Sicherheitsüberprüfung SÜ1 | Bereitschaft, ja |
| 15 | Schwerbehinderung | keine Angabe |
| 16 | Einverständnis Datenverarbeitung | ja |

## Was das Anschreiben sagt

Es beginnt mit der Aufgabenbeschreibung selbst — Plattformen über den Lifecycle betreiben,
Betriebsprozesse automatisieren, Entwicklungsteams befähigen — und beschreibt dann die eigene
Plattform: Deklaration, Gate, Rollback, MicroVMs, PXE, Ledger, Entstörung mit journald, cgroups und
tcpdump. Der dritte Absatz nennt die Lücken: kein produktives Kubernetes oder OpenShift, kein
Ansible oder Terraform (Nix), Public Cloud nur als kleines Projekt, keine Rechenzentrums-HA. Der
vierte Absatz ist Enablement und Dokumentation, der fünfte Nürnberg, E 12/E 11 und die ausdrückliche
SÜ1-Bereitschaft.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 213 prose files, exit 0 |
| selection | / highlights, / projects |
| sha256 Lebenslauf | `6594993149022be988a7157c13c2e5e2f33292e37dc7efc2d55d5ddd10315b21` |
| sha256 Anschreiben | `abb9fd658b3cbb213987162385a380ebc8a1e4861f5ae0dde7eb72b0db0c0d61` |

## Nächste Schritte

1. Frist am Interamt-Eintrag prüfen — die 18.12.2026 stehen nur in der Lead-Notiz.
2. Über Interamt bewerben; die Kennziffer BAMF-2025-358 in Anschreiben und Formular führen.
3. Auf die Kubernetes-Frage vorbereitet sein: MicroVMs, PXE und Deklaration sind ehrliche Nachbarschaft,
   ein Cluster-Betrieb ist es nicht.
