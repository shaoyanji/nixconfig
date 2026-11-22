# Bewerbung Bechtle AG / KubeOps - DevOps Engineer Kubernetes & Application Operations (w/m/d) (Remote)

Stand: 22. November 2026
Job-ID: 82956
Referenz: 15086-44522805-1021-S

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Bechtle AG, Bereich KubeOps (Unternehmen der Bechtle Gruppe) |
| Rolle | DevOps Engineer - Kubernetes & Application Operations (w/m/d) (Remote) |
| Standort | Bechtle Platz 1, 72336 Balingen; Remote Deutschland |
| Umfeld | KubeOps betreibt containerbasierte Infrastrukturen für Public Sector und regulierte Kunden; über 90 Mitarbeitende, mehrheitlich technische Spezialisten |
| Schwerpunkt | Betrieb Kubernetes-basierter Plattformen, CI/CD, Infrastructure as Code, Observability, Linux |
| Arbeitsmodell | 90 Präsenztage pro Jahr; vollständig remote aus Deutschland ab 60 km Entfernung zum Standort |
| Sicherheitsprüfung | Bereitschaft zur Sicherheitsüberprüfung SÜ2 wird verlangt |
| Sprachen | Sehr gutes Deutsch im Kundenumfeld, gutes Englisch |
| Anstellung | Unbefristet, 30 Tage Urlaub |
| Kontakt | Christopher Waldraff, Recruiting, christopher.waldraff@bechtle.com |

### Adressen

Die übergebene Anzeige zeigt auf Bisingen (`72406`, SAP-ID `1367643157`) und leitet auf die aktuelle Ausschreibung um:

```
https://jobs.bechtle.com/job/Balingen-DevOps-Engineer-Kubernetes-&-Application-Operations-(wmd)-(Remote)-72336/82956-de_DE/
```

Für die Bewerbung gilt die Balinger Fassung mit Job-ID `82956`. Der Datensatz in Delphi trägt noch die alte Bisinger URL; das Anschreiben nennt die Stelle ohne URL, damit kein veralteter Link im Dokument steht.

## Bewerbungsweg

1. Anzeige auf `jobs.bechtle.com` öffnen, Button "Jetzt bewerben".
2. Der Button startet die Quick-Apply-Anwendung:

```
https://bechtle-production.p78quickapply.com/comp78sfrecruitingp78quickapplyui/index.html?Reqid=82956&sap-language=de_DE&sap-theme=bechtlequickapplytheme&sap-ui-versionedLibCss=true#/Attachment
```

3. Die Anwendung ist eine SAPUI5-Shell. Sie rendert ihre Felder erst zur Laufzeit und spricht `https://production.api.recruiting-solutions.org` mit `customerId=bechtle-prod` an. Ohne Konto und Sitzung sind die Feldbeschriftungen nicht abrufbar; die Zuordnung unten stammt aus dem ausgelieferten Schema der Anwendung und aus der Bechtle-Bewerbungs-FAQ.
4. Ein Bechtle-Konto wurde nicht angelegt. Der erste Schritt im Formular ist die Anlage oder Anmeldung; dort ist auch eine Passwort-Rücksetzung vorhanden.

### Dokumente laut FAQ

| Regel | Wert |
| :--- | :--- |
| Lebenslauf | Pflicht |
| Anschreiben | Optional |
| Zeugnisse und Zertifikate | Aktuelle Nachweise erwünscht |
| Formate | pdf, doc, docx, odt, rtf, txt, jpeg, gif, png |
| Größe | 5 MB pro Datei, 10 MB gesamt |

## Kandidat

| Feld | Wert |
| :--- | :--- |
| Name | Matt Ji |
| Adresse | Am Burgerhof 4, 79261 Gutach im Breisgau, Deutschland |
| E-Mail | matt@bountystash.com |
| Telefon | +49 1733281570 |
| Sprachen | Deutsch C1, Englisch Muttersprache |
| Abschluss | M.Sc. Erneuerbare-Energien-Management, Albert-Ludwigs-Universität Freiburg, 2014 |
| Berufserfahrung | Zehn Jahre, davon fünf Jahre eigene Infrastruktur- und DevOps-Verantwortung |
| Arbeitsberechtigung | US-Staatsangehörigkeit mit unbefristeter deutscher Niederlassungserlaubnis; keine Visumsunterstützung nötig |
| Verfügbarkeit | Ab sofort |
| Gehaltswunsch | 85.000 EUR |
| Entfernung | Gutach im Breisgau liegt über 60 km von Balingen entfernt; das Remote-Modell greift |

## Abgleich mit der Ausschreibung

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Betrieb Kubernetes-basierter Plattformen | Keine produktive Kubernetes-Plattform verantwortet; Flotte läuft auf NixOS mit systemd, nicht auf einem Cluster | Lücke, im Anschreiben offen benannt |
| Container-Technologien | Container für Dienste und Builds im Einsatz; kein Betrieb als Orchestrierungsplattform | Teilweise |
| CI/CD | Inventargetriebene CI im Flake, Per-Host-Gates, reproduzierbare Deployments | Stark |
| Infrastructure as Code | Gesamte Flotte deklarativ in einem Repository; Hosts, Dienste, Secrets und Netz als Code | Stark |
| Linux | NixOS-Flotte mit dreizehn Hosts, systemd, nftables, Tailscale, sops, Binary-Cache, Rollback | Stark |
| Monitoring, Logging, Observability | Sentinel-Ledger für Jobstatus, Generation-Alter, Disk- und PSI-Druck alle 15 Minuten; Gatus-Alarmierung bei Abweichung | Stark |
| Störungsanalyse und nachhaltige Lösungen | Messen, eingrenzen, Runbook hinterlassen; Ursachenbehebung statt Neustart | Stark |
| Automatisierte Betriebsprozesse | Tasks als einziger Weg zur Produktion; keine manuellen Schritte auf dem Host | Stark |
| Sicherheit und Compliance | Verschlüsselte Secrets, eigene CA, Zugriff nur über das Tailnet, Least Privilege | Stark |
| GitOps | Deklarativer Zustand im Git, aber ohne ArgoCD oder Flux; Ausrollen über Push statt Pull | Teilweise |
| Deutsch im Kundenumfeld | C1 | Erfüllt |
| Englisch | Muttersprache | Übertrifft |
| SÜ2 | Bereitschaft vorhanden | Erfüllt |
| Konzernmaßstab | Keine IT für 16.000 Mitarbeitende verantwortet | Lücke, nicht beschönigt |

Auswahl im Lebenslauf: 16 von 36 Highlights, 4 von 10 Projekten.

## Formularzuordnung

Die Beschriftungen sind vor dem Absenden gegen das gerenderte Formular zu prüfen. Die Feldnamen folgen dem Schema der Quick-Apply-Anwendung.

### Profil

| Feld im Schema | Wert |
| :--- | :--- |
| `firstName` | Matt |
| `lastName` | Ji |
| `contactEmail`, `primaryEmail` | matt@bountystash.com |
| `address` | Am Burgerhof 4 |
| `zip` | 79261 |
| `city` | Gutach im Breisgau |
| `country` | Deutschland |
| `candidateLocale` | de_DE |
| `dateOfBirth` | Leer lassen, solange das Feld optional ist |
| `shareProfile` | Nur für diese Stelle freigeben |
| `consentToMarketing` | Nicht aktivieren |
| `privacy`, `privacyId`, `privacyVersionId` | Datenschutzhinweis lesen und bestätigen |

### Anhänge

| Feld im Schema | Datei | Hinweis |
| :--- | :--- | :--- |
| `resume` | `lebenslauf.pdf` | Pflichtfeld, zwei Seiten |
| `coverLetter` | `anschreiben.pdf` | Optional, eine Seite |
| `attachments` | keine | Zeugnisse nur anhängen, wenn das Formular danach fragt |

### Fragen

| Frage | Antwort |
| :--- | :--- |
| Berechtigt, in Deutschland zu arbeiten? | Ja, unbefristete Niederlassungserlaubnis. |
| Visumsunterstützung erforderlich? | Nein. |
| Produktive Kubernetes-Plattformen betrieben? | Nein. Container und deklarative Deployments ja, Orchestrierung mit Helm, ArgoCD oder vergleichbar nein. |
| Erfahrung mit CI/CD und IaC? | Ja, Repository und Tasks als einziger Weg zur Produktion, Gates pro Host. |
| Monitoring-Erfahrung? | Ja, eigener Sentinel mit Ledger und Alarmierung. |
| Deutschkenntnisse? | C1. |
| Englischkenntnisse? | Muttersprache. |
| Bereit zur SÜ2-Prüfung? | Ja. |
| Bereit zu 90 Präsenztagen? | Ja; die Entfernung erlaubt zusätzlich das Remote-Modell. |
| Gehaltswunsch? | 85.000 EUR; nur eintragen, wenn das Feld Pflicht ist. |
| Frühester Eintritt? | Ab sofort. |
| Wie aufmerksam geworden? | Bechtle-Karriereseite. |

## Offene Punkte vor dem Absenden

1. Konto in der Quick-Apply-Anwendung anlegen und E-Mail bestätigen; ohne Sitzung ist das Formular nicht sichtbar.
2. Beschriftungen und Pflichtflags im gerenderten Formular gegen die Tabellen oben prüfen.
3. Kubernetes-Lücke im Freitextfeld nicht überspielen; die Antwort oben ist die ehrliche Fassung.
4. Gehaltswunsch nur bei Pflichtfeld eintragen.
5. Nach dem Absenden Bestätigungsseite und Eingangs-E-Mail sichern.
6. Delphi-Datensatz steht auf `stage=prep`; nach dem Absenden auf `applied` wechseln.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Bereinigte deutsche Ausschreibung. |
| `lebenslauf.pdf` | Deutscher Lebenslauf, zwei Seiten. |
| `anschreiben.pdf` | Deutsches Anschreiben, eine Seite. |
| `selection.json` | Audit der ausgewählten Highlights und Projekte. |
| `submission-sheet.md` | Diese Feldzuordnung. |
