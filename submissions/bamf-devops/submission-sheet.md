# Bewerbung Bundesamt für Migration und Flüchtlinge - DevOps Engineer Public Cloud / Plattformdienste

Stand: 22. November 2026
Kennziffer: BAMF-2025-358
Interamt-Angebots-ID: 1513998
Fit: 4

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Bundesamt für Migration und Flüchtlinge, Referat 22B Plattform- und Cloudservices |
| Rolle | mehrere DevOps-Engineers (m/w/d), Bereiche Public Cloud / Plattformdienste |
| Dienstort | Nürnberg |
| Anstellung | Unbefristet sowie befristet auf 24 Monate nach § 14 Abs. 2 TzBfG |
| Teilzeit | Grundsätzlich geeignet |
| Entgelt | E 10 bis E 12 TV EntgO Bund, Beamtinnen und Beamte A 10 bis A 12 BBesO |
| Besetzung | Zeitnah |
| Bewerbungsfrist | 18.12.2026 |
| Bewerbungsweg | Ausschließlich über Interamt, Online-Bewerbung |
| Anzeige | https://interamt.de/koop/app/stelle?id=1513998 |

Mehrere Stellen sind ausgeschrieben, unbefristet und befristet. Das ist der Grund, warum der Fit hier auf 4 steht und nicht auf 3: Die Lücke bei Kubernetes und VMware betrifft mehrere Bewerbende, nicht eine einzelne Stelle.

## Bewerbungsweg

1. Interamt-Konto anlegen: `https://www.interamt.de/koop/app/registrieren` oder mit vorhandenem Login anmelden.
2. Anzeige `https://interamt.de/koop/app/stelle?id=1513998` öffnen und auf "Online bewerben" klicken.
3. Lebenslauf hochladen. Weitere Unterlagen nur, wenn der Dialog sie verlangt.
4. Absenden und die Bestätigung sichern.

Das Formular wurde nicht gerendert. Die Zuordnung unten nennt Werte ohne belegte Feld-IDs; es wurde nichts abgeschickt und kein Konto angelegt.

**Anschreiben:** Laut Ausschreibung ist ein Anschreiben oder Motivationsschreiben nicht erforderlich. `anschreiben.pdf` liegt trotzdem im Paket, falls das Formular ein Feld dafür anbietet oder eine Nachfrage kommt. Wer es weglässt, verliert nichts.

### Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, Pflicht |
| Anschreiben | `anschreiben.pdf` | Eine Seite, laut Ausschreibung nicht erforderlich |
| Zeugnisse, Nachweise | keine Datei | Nachreichen, wenn der Dialog fragt |
| ZAB-Vergleichbarkeit | nicht nötig | Abschluss ist deutsch, Universität Freiburg |

## Kandidat

| Feld | Wert |
| :--- | :--- |
| Name | Matt Ji |
| Adresse | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-Mail | matt@bountystash.com |
| Telefon | +49 1733281570 |
| Sprachen | Deutsch C1, Englisch Muttersprache |
| Abschluss | M.Sc. Erneuerbare-Energien-Management, Albert-Ludwigs-Universität Freiburg, 2014 |
| Berufserfahrung | Zehn Jahre, davon fünf Jahre eigene Plattform- und DevOps-Verantwortung |
| Staatsangehörigkeit | US-amerikanisch, unbefristete deutsche Niederlassungserlaubnis |
| Verfügbarkeit | Ab sofort |
| SÜ1 | Bereitschaft vorhanden |

## Abgleich mit der Ausschreibung

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Virtualisierungs- und Containerisierungsplattformen auf Linux und Kubernetes über den Lifecycle | Linux ja, dreizehn NixOS-Hosts; Kubernetes nicht im Produktivbetrieb | Lücke beim Cluster, im Anschreiben benannt |
| Störungen und Engpässe erkennen, entstören, Monitoring im Blick behalten | Sentinel-Ledger, Gatus, Go-Bridge mit Zustellbestätigung, PSI-Druck | Stark |
| Services konzeptionell und technisch weiterentwickeln: Automatisierung, Security, Hochverfügbarkeit | Modulgrenzen, Gates je Host, Secrets über sops und age, Rollback je Generation | Stark, Hochverfügbarkeit nur auf Hostebene |
| Enablement: Kolleginnen und Kollegen bei der Plattformnutzung unterstützen, Betriebswissen verankern | Runbooks, Skill-Seiten, Tasks mit klarer Schnittstelle im Repository | Stark |
| Technische Konzepte und Dokumentationen erstellen und pflegen | Jede Betriebsprozedur liegt als Seite oder Task im Repository | Stark |
| Studium mindestens Bachelor, MINT oder IT-Schwerpunkt | M.Sc. Universität Freiburg | Erfüllt |
| Erfahrung in IT-Betrieb, Systemadministration oder DevOps | Zehn Jahre Berufspraxis, fünf Jahre Plattformbetrieb | Erfüllt |
| Linux und Containerisierung von Vorteil | Linux täglich, Container als Grundlage der KI-Plattform | Erfüllt |
| Fundierte Kenntnisse Infrastructure-as-Code, Ansible oder Terraform | Deklarativ mit Nix, nicht mit Ansible oder Terraform | Teilweise; Werkzeug weicht ab |
| Scripting, Bash oder Python | Go, Python und Bash im Produktivbetrieb | Erfüllt |
| Deutsch C1 | C1, deutschsprachiges Studium in Freiburg | Erfüllt, Nachweis über den Abschluss |
| SÜ1 | Bereitschaft vorhanden | Erfüllt |

Auswahl im Lebenslauf: die Auswahl steht in `selection.json`; der Selektor hat 16 von 32 Highlights und 4 von 5 Projekten behalten.

## Gehalt: TV EntgO Bund E 10 bis E 12

Die Stelle ist mit E 10 bis E 12 bewertet. E 12 setzt nach der Ausschreibung voraus, dass die persönlichen Voraussetzungen im Einzelfall vorliegen; mit M.Sc. und zehn Jahren Berufserfahrung ist E 12 das Ziel, E 11 die realistische Eingruppierung.

Das Entgelt ist tariflich festgelegt. Verhandelbar sind die Erfahrungsstufe und, bei speziellen Qualifikationen, eine Fachkräftezulage, die die Ausschreibung ausdrücklich nennt. Dazu kommen Jahressonderzahlung, betriebliche Altersvorsorge und eine BAMF-Zulage von bis zu 125 EUR monatlich, befristet bis 31.12.2027.

Eine Forderung von 85.000 bis 95.000 EUR passt nicht in diese Entgeltgruppe und sollte nicht genannt werden. Im Anschreiben steht keine Zahl.

## Formularzuordnung

Der Interamt-Dialog wurde nicht gerendert. Werte ohne belegte Feld-IDs; Beschriftungen vor dem Absenden gegenprüfen.

### Person

| Beschriftung | Wert |
| :--- | :--- |
| Anrede | Herr |
| Vorname | Matt |
| Nachname | Ji |
| E-Mail | matt@bountystash.com |
| Telefon | +49 1733281570 |
| Straße | Am Burgerhof 4 |
| PLZ | 79261 |
| Ort | Gutach im Breisgau |
| Land | Deutschland |
| Geburtsdatum | Nur bei Pflichtfeld; Wert aus dem PII-Speicher |

### Stelle und Konditionen

| Beschriftung | Wert |
| :--- | :--- |
| Kennziffer | BAMF-2025-358 |
| Interamt-ID | 1513998 |
| Eintritt | Zeitnah, ab sofort |
| Beschäftigungsart | Vollzeit; Teilzeit möglich |
| Entgeltvorstellung | E 12 angestrebt, E 11 akzeptiert; keine Zahl |
| Sicherheitsüberprüfung SÜ1 | Bereitschaft, zeitnah zu durchlaufen |
| Schwerbehinderung | Keine Angabe, solange freiwillig |
| Einwilligung Datenverarbeitung | Lesen und bestätigen |

## Offene Punkte vor dem Absenden

1. Frist 18.12.2026. Danach nimmt Interamt keine Bewerbung mehr an.
2. Interamt-Konto anlegen; die Bewerbung läuft ausschließlich über das System, nicht per E-Mail.
3. Standort entscheiden. Nürnberg ist von Gutach rund 350 km entfernt; Umzug oder Pendeln ist eine Entscheidung des Bewerbers, im Anschreiben steht dazu nichts.
4. Anschreiben ist optional. Wer es anhängt, hängt eine Seite an, die niemand verlangt hat.
5. Kubernetes- und VMware-Lücke nicht überspielen; das Anschreiben benennt sie und bietet Lernen statt Behauptung.
6. Keine Gehaltsforderung nennen; E 12 anstreben, Stufe und Zulage im Gespräch klären.
7. Nach dem Absenden Bestätigung sichern; der Datensatz steht auf `stage=prep` und wechselt nach dem Absenden auf `applied`.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Ausschreibung mit Aufgaben, Profil, Angebot und Bewerbungsweg. |
| `lebenslauf.pdf` | Deutscher Lebenslauf, zwei Seiten. |
| `anschreiben.pdf` | Deutsches Anschreiben, eine Seite, mit benannten Lücken. |
| `selection.json` | Audit der Auswahl. |
| `submission-sheet.md` | Diese Feldzuordnung. |
