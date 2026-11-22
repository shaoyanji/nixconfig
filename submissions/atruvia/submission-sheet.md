# Bewerbung Atruvia AG - DevOps Engineer (m/w/d)

Stand: 22. November 2026
Kennziffer: 2399
Requisition-ID: 300000607387917
Bewerbungs-ID: eb172867-17ed-442e-af26-b5714d144c53

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Atruvia AG |
| Rolle | DevOps Engineer (m/w/d), Geschäftsfeld Data, Security and Identity, Tribe Advanced Intelligence, Chapter Transition |
| Standorte | Karlsruhe und Aschheim (München); hybrid |
| Umfang | Vollzeit, 38 Stunden pro Woche, teilzeitgeeignet |
| Gehaltsrahmen | 70.000 bis 102.000 EUR Jahresgehalt, 14 Monatsgehälter |
| Visumspflicht | Keine. US-Staatsangehörigkeit mit deutscher Niederlassungserlaubnis |
| Sprachen | Deutsch C1, Englisch Muttersprache |

Die Ausschreibung nennt Karlsruhe oder München. Im Oracle-Datensatz ist Aschheim der primäre Standort, Karlsruhe der zweite Standort. Die Bewerbung nennt Karlsruhe als ersten Wunsch; Aschheim (München) ist mit Präsenztagen erreichbar.

## Bewerbungsweg

Der sichtbare Button "Bewerben" führt nicht in das native talentsconnect-Formular, sondern zu Oracle Recruiting Cloud. Der verbindliche Einstieg ist:

https://fa-exxd-saasfaprod1.fa.ocs.oraclecloud.com/hcmUI/CandidateExperience/de/sites/CX_3/jobs/preview/2399/apply/email

Der Pfad `apply/email` startet mit der E-Mail-Verifizierung. Danach folgen Kandidatenprofil, Fragen, Dokumente und die Zusammenfassung. Die Karriereseite bleibt die Referenz für die Ausschreibung:

https://karriere.atruvia.de/offer/devops-engineer-m-w-d/eb172867-17ed-442e-af26-b5714d144c53

## Live-Formular

Quelle: `recruitingCEApplyFlows`, Flow `ATR_ExternalApplyFlow`, Flow-Version `300000061406179`, Sprache Deutsch, Site `CX_3`.

| Abschnitt | Block | Regel |
| :--- | :--- | :--- |
| Personal Info | `ORA_PROFILE_IMPORT` | Optional. LinkedIn-Import ist aktiv; Indeed und Resume-Parser sind inaktiv. |
| Personal Info | `ORA_NAME_CONTACT_INFO` | Pflicht. Kontaktdaten und Anschrift. |
| Personal Info | `ORA_SENSITIVE_PERSONAL_INFO` | Optional. Geburtsdatum sichtbar, aber nicht Pflicht; nationale ID nicht sichtbar. |
| Job Application Questions | `ORA_DQ_QUESTIONS` | Fragenblock vorhanden. Die Fragen-Metadaten sind ohne Kandidatensitzung nicht öffentlich. |
| More About You | `ORA_DOCUMENTS` | Lebenslauf Pflicht; Anschreiben optional; soziale URLs optional. |
| More About You | `ORA_MISC_DOCUMENTS` | Optional. Weitere Dokumente. |
| Summary | `ORA_SUMMARY` | Prüfen und absenden. E-Signatur ist im Flow deaktiviert. |

Die Kontakt- und Fragen-Metadaten liefern ohne E-Mail-Verifizierung HTTP 401. Die Blockstruktur, Pflichtflags und Dokumentenregeln stammen aus dem Live-Flow. Die Feldnamen der Kontaktmaske sind die Oracle-Standardbezeichnungen; die Werte sind vollständig vorbereitet.

## Kontaktdaten

| Feld | Wert | Hinweis |
| :--- | :--- | :--- |
| Anrede | Herr | Nur setzen, wenn das Feld erscheint. |
| Vorname | Matt | Pflicht. |
| Nachname | Ji | Pflicht. |
| E-Mail | matt@bountystash.com | Pflicht. Für die Verifizierung verwenden. |
| Telefon | +49 1733281570 | Pflicht, falls abgefragt. |
| Land | Deutschland | Pflicht. |
| Adresse | Am Burgerhof 4 | Pflicht, falls abgefragt. |
| Adresszusatz | leer | Kein Zusatz vorhanden. |
| Stadt | Gutach im Breisgau | Pflicht, falls abgefragt. |
| Bundesland | Baden-Württemberg | Pflicht, falls abgefragt. |
| Postleitzahl | 79261 | Pflicht, falls abgefragt. |
| Geburtsdatum | leer | Sichtbar, aber nicht Pflicht. Nicht ohne Notwendigkeit angeben. |
| Nationale ID | nicht sichtbar | Nicht ausfüllen. |

## Fragen und Antworten

Diese Antworten sind für den Fragenblock vorbereitet. Exakte Prompts erscheinen erst nach der Verifizierung.

| Frage | Antwort |
| :--- | :--- |
| Sind Sie berechtigt, in Deutschland zu arbeiten? | Ja. US-Staatsangehörigkeit mit unbefristeter deutscher Niederlassungserlaubnis. |
| Benötigen Sie Visumsunterstützung? | Nein. |
| Deutschkenntnisse? | C1. |
| Englischkenntnisse? | Muttersprache. |
| OpenShift im Produktivbetrieb? | Nein, keine eigene Produktivverantwortung. Linux, systemd und deklarative Infrastruktur sind die Tiefe; OpenShift ist Einarbeitung. |
| Kubernetes im Produktivbetrieb? | Grundlagen vorhanden, keine eigene Produktivverantwortung. |
| Terraform im Produktivbetrieb? | Nicht produktiv. Infrastructure as Code erfolgt mit Nix; Terraform ist Einarbeitung. |
| Berufserfahrung? | Zehn Jahre Berufserfahrung, davon fünf Jahre eigene Infrastruktur- und DevOps-Verantwortung. |
| Höchster Abschluss? | M.Sc. Erneuerbare-Energien-Management, Albert-Ludwigs-Universität Freiburg, 2014. |
| Verfügbarkeit? | Ab sofort. |
| Gehaltswunsch? | 85.000 EUR bei 38 Stunden; verhandelbar im Korridor 70.000 bis 102.000 EUR. Nur ausfüllen, wenn das Feld Pflicht ist. |
| Bevorzugter Standort? | Karlsruhe. Aschheim (München) ist mit Präsenztagen erreichbar. |
| Wie sind Sie auf uns aufmerksam geworden? | Atruvia-Karriereseite. |

## Dokumente

| Dokument | Datei | Regel | Aktion |
| :--- | :--- | :--- | :--- |
| Lebenslauf | `lebenslauf.pdf` | Pflicht | Hochladen. Zwei Seiten. |
| Anschreiben | `anschreiben.pdf` | Optional | Hochladen. Eine Seite. |
| Arbeitszeugnisse | fehlt | Laut Ausschreibung wesentlich | Vor dem Absenden ergänzen. Ohne diese Anlage ist die Bewerbung nicht vollständig. |
| Soziale URLs | siehe unten | Optional | Nur eintragen, wenn das Feld erscheint. |
| Weitere Dokumente | keine | Optional | Leer lassen. |

Soziale URLs:

- GitHub: https://github.com/shaoyanji/nixconfig
- LinkedIn: https://linkedin.com/in/mattji
- Xing: https://xing.com/profile/Shaoyan_Ji
- Website: https://www.bountystash.com

## Abgleich mit der Ausschreibung

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Linux und Betrieb von Applikationen | NixOS-Flotte, systemd-Dienste, Rebuilds, Rollback, Sentinel | Stark. |
| OpenShift | Keine Produktivverantwortung | Lücke, im Anschreiben offen benannt. |
| Kubernetes onPrem und Cloud | Grundlagen, keine Produktivverantwortung | Lücke. |
| Infrastructure as Code | Nix-Flake, gepinnte Inputs, Per-Host-Gate | Stark, anderer Werkzeugpfad als Terraform. |
| Terraform | Nicht produktiv | Lücke, im Anschreiben offen benannt. |
| CI/CD | Inventargetriebene CI, gemeinsamer Binary-Cache, Remote-Builder | Stark. |
| Monitoring, Logging, Alerting | Sentinel-Ledger, PSI-, Disk- und Jobstatus, Gatus-Alarm | Stark. |
| Incident- und Problemmanagement, 2nd Level | Betriebliche Runbooks, Sentinel, Fehlerisolierung | Plausibel, keine formale 2nd-Level-Historie. |
| Go und Python | Go-Dienste, Python-Werkzeuge | Stark. |
| PostgreSQL | Betrieb und Migrationen | Vorhanden. |
| Deutsch C1, Englisch B2 | C1 und Muttersprache | Übertrifft die Anforderung. |
| Studium oder vergleichbare Qualifikation | M.Sc. Freiburg, langjährige IT-Praxis | Erfüllt über den vergleichbaren Weg. |
| Arbeitserlaubnis | Niederlassungserlaubnis | Keine Visumsfrage. |

## Offene Punkte vor dem Absenden

1. Arbeitszeugnisse als PDF ergänzen. Die Ausschreibung verlangt Lebenslauf und wesentliche Arbeitszeugnisse; im Paket liegen nur Lebenslauf und Anschreiben.
2. Im Oracle-Fragenblock prüfen, ob OpenShift, Kubernetes oder Terraform als Pflichtfrage erscheinen. Die Antworten oben nicht beschönigen.
3. Gehaltswunsch nur eintragen, wenn das Feld Pflicht ist. 85.000 EUR ist der Zielwert, nicht der ausgeschriebene Rahmen.
4. Nach dem Absenden die Bestätigungsseite und die Eingangsbestätigung speichern.
5. Den Delphi-Datensatz auf `stage=prep` setzen. Nach dem Absenden auf `applied` wechseln.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Bereinigte deutsche Ausschreibung, 31 Zeilen. |
| `lebenslauf.pdf` | Deutscher Lebenslauf, zwei Seiten. |
| `anschreiben.pdf` | Deutsches Anschreiben, eine Seite. |
| `selection.json` | Audit der ausgewählten Lebenslauf-Highlights und Projekte. |
| `submission-sheet.md` | Diese Feldzuordnung. |
