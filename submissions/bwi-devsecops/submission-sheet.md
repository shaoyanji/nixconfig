# Bewerbung BWI GmbH - Senior DevOps Engineer DevSecOps (m/w/d)

Stand: 22. November 2026
Stellen-ID: 69424

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | BWI GmbH, IT-Systemhaus der Bundeswehr |
| Rolle | Senior DevOps Engineer - DevSecOps (m/w/d) |
| Standort | Bevorzugt Berlin, Bonn, Frankfurt a.M., München; alternativ an einem BWI-Standort; mobiles Arbeiten möglich |
| Umfeld | On-Prem Cloud-Native-Plattform für das Krisenvorsorgeinformationssystem der Bundeswehr; über 8.000 Mitarbeitende, eine der größten IT-Infrastrukturen Deutschlands |
| Schwerpunkt | GitOps, CI/CD-Werkzeuge, IaC, SDN-Netz und Virtualisierung, Secure Software Supply Chain (SBOM, Image-Signierung), Informationssicherheit |
| Erfahrung | Mindestens 5 Jahre DevOps |
| Vergütung | 71.000 bis 91.650 EUR laut Ausschreibung |
| Urlaub | 30 Tage, anpassbar |
| Kontakt | Sebastian Stange, Recruiter |
| Anzeige | https://www.bwi.de/karriere/stellenangebote/job/senior-devops-engineer-devsecops-m-w-d-69424 |

Die Ausschreibung nennt keinen expliziten Remote-Anteil. Sie spricht von mobilem Arbeiten und Vertrauensarbeitszeit und führt vier bevorzugte Standorte. Die Bewerbung geht daher von Präsenz an einem dieser Standorte plus mobilen Tagen aus, nicht von einer vollständig remote besetzbaren Stelle.

## Bewerbungsweg

1. Anzeige öffnen, Button "Jetzt bewerben".
2. Der Button führt auf das BWI-Bewerberportal:

```
https://karriere.bwi.de/bewerber/landingpage.php?prj=33P69424&b=2&lang=de_DE&ie=1&oid=
```

3. Das Portal leitet auf das Formular um:

```
https://karriere.bwi.de/candidate/formapply?prj=69424&b=2&oid=&quelle=0&ie=1&gpid=33P69424&lang=de_DE
```

4. Die Feldnamen unten stammen aus dem ausgelieferten HTML dieses Formulars. Ein Konto ist nicht nötig; das Formular wird direkt abgeschickt. Ein BWI-Konto wurde nicht angelegt, und es wurde nichts abgeschickt.

### Dokumente

Das Formular verlangt Bewerbungsunterlagen und meldet, wenn eines der erwarteten Dokumente fehlt. Die Upload-Felder werden erst im Dokumentenschritt gerendert; im ersten Schritt ist kein `input type="file"` enthalten. Vorgesehen sind Lebenslauf, Anschreiben und Zeugnis.

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Lebenslauf | `lebenslauf.pdf` | Pflicht, zwei Seiten |
| Anschreiben | `anschreiben.pdf` | Eine Seite, hochladen |
| Zeugnisse | keine Datei | Nur anhängen, wenn das Formular danach fragt |

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
| Umzug | Gutach im Breisgau; keine der vier Städte ist zumutbarer Tagesweg, Umzug oder Präsenz mit Reise ist die Entscheidung des Bewerbers |

## Abgleich mit der Ausschreibung

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| GitOps und Deployment-Automatisierung | Flottenzustand vollständig im Repository, Ausrollen über Tasks und Pull Request, Gates vor dem Deploy | Stark, aber Push-basiert; kein ArgoCD |
| Infrastructure as Code | Dreizehn NixOS-Hosts als ein Flake, jeder Dienst ein Modul, Firewall und Netz deklarativ | Stark, anderes Werkzeug als Terraform oder Ansible |
| Secure Software Supply Chain | Jede Abhängigkeit im Lock per Hash gepinnt, Sandbox-Build ohne Netzwerkzugriff, gleiche Eingaben ergeben denselben Store-Pfad | Stark auf Build-Ebene; SBOM-Erzeugung und Image-Signierung sind nicht im Einsatz |
| Secret-Management und Absicherung | sops mit age, eigene SSH-Zertifizierungsstelle mit kurzlebigen Zertifikaten, keine stehenden Secrets, Least Privilege | Stark |
| CI/CD-Werkzeuge | Inventargetriebene CI, Modul-Gate je Host, sops-Drift, Oberflächen- und Linkchecks | Stark im eigenen Aufbau; GitLab, ArgoCD und SonarQube nicht im Kundenbetrieb geführt |
| Container und Orchestrierung | Container im Einsatz, Kubernetes als Grundlage | Lücke: kein Produktivbetrieb von Kubernetes, Helm oder Kustomize |
| Observability | Sentinel-Ledger für Jobstatus, Generation-Alter, Disk- und PSI-Druck, Alarmierung bei Ausfall | Stark, eigene Werkzeuge statt Prometheus oder Grafana |
| Linux-Administration | NixOS-Flotte mit systemd, nftables, Tailscale, Rollback je Generation | Stark |
| Netzwerk und Virtualisierung | nftables, Tailscale-Netz, deklarative Netzregeln | Teilweise: Layer 2/3 ja, SDN und VMware nein |
| Windows-Server | Nicht administriert | Lücke |
| Skripting, bevorzugt Python | Python, Go und Bash für Dienste, Auswertung und Automatisierung | Stark |
| IT-Grundschutz-Härtung | Keine Zertifizierung; Härtung über minimale Angriffsfläche und keine stehenden Secrets | Teilweise, im Anschreiben offen benannt |
| Schwachstellenbetrieb | KEV-Zeitreihe, Aufwandscluster, Konzept mit Exposition und 90-Tage-Frist | Nachweis als Konzept und Werkzeug, kein laufendes Unternehmensprogramm |
| Deutsch und Englisch | C1 und Muttersprache | Übertrifft die Anforderung |
| Bundeswehr-Umfeld und Sicherheitsprüfung | Bereitschaft zur Sicherheitsüberprüfung erklärt | Erfüllt die Erwartung, kein Vorlauf |

Auswahl im Lebenslauf: 17 von 32 Highlights, 4 von 10 Projekten. Die Auswahl bevorzugt Build-Lieferkette, Secrets und Gates; die Finanz- und Energieprojekte der früheren Rollen bleiben im Korpus, treten aber zurück.

## Gehalt

Zielfenster laut Vorgabe: 90.000 bis 105.000 EUR.

Die Ausschreibung nennt 71.000 bis 91.650 EUR. Das Fenster liegt damit vollständig über der ausgeschriebenen Spanne; schon die Untergrenze von 90.000 EUR entspricht fast dem Bandmaximum. Im Formular gibt es ein Pflicht- oder optionales Feld `KarGehalt` mit Währung und Zeitraum. Empfehlung: 90.000 EUR eintragen, wenn das Feld verlangt wird, und die Differenz im Gespräch über Verantwortungsbereich und Erfahrung begründen. 105.000 EUR ist in dieser Stelle nicht erreichbar.

## Formularzuordnung

Die Feldnamen sind aus dem Formular übernommen. Die Beschriftungen im gerenderten Formular vor dem Absenden gegenprüfen.

### Person

| Feld | Wert |
| :--- | :--- |
| `sex` | Herr, falls die Auswahl es verlangt |
| `title` | Leer lassen |
| `FirstName` | Matt |
| `LastName` | Ji |
| `email` | matt@bountystash.com |
| `tel` | +49 1733281570 |
| `street` | Am Burgerhof 4 |
| `PLZ` | 79261 |
| `ort` | Gutach im Breisgau |
| Land | Deutschland |

### Gehalt

| Feld | Wert |
| :--- | :--- |
| `KarGehalt` | 90000 |
| `currency_KarGehalt` | EUR |
| `expected_salary_periode` | Jahr, falls die Auswahl das verlangt |

### Sprachkenntnisse und Mobilität

| Feld | Beschriftung | Wert |
| :--- | :--- | :--- |
| `antworten[119]` | Sprachkenntnisse Deutsch | C1 - Fließend in Wort und Schrift |
| `antworten[137]` | Sprachkenntnisse Englisch | Verhandlungssicheres Niveau (C2) oder Muttersprache, je nach Auswahl |
| `antworten[393]` | Weitere Sprachkenntnisse | Leer lassen; im Formular prüfen, ob es ein Freitextfeld ist |
| `antworten[387]` | Umzugsbereitschaft? | Nein, oder Eingeschränkt mit Nennung von Baden-Württemberg und Süddeutschland; die Entscheidung trifft der Bewerber |

### Einwilligungen

| Feld | Bedeutung | Wert |
| :--- | :--- | :--- |
| `antworten[107]` | Interne Weiterleitung an andere BWI-Stellen | Nicht einverstanden, solange keine ausdrückliche Freigabe vorliegt |
| `antworten[1504]` | Datenweitergabe für weitere Stellen, freiwillig, widerruflich per bewerbung@bwi.de | Nach Wunsch; die Einwilligung ist freiwillig |
| `datenschutzok`, `datenschutztop` | Datenschutzhinweise | Lesen und bestätigen |

## Offene Punkte vor dem Absenden

1. Dokumentenschritt prüfen: Upload-Felder und Pflichtflags erscheinen erst dort.
2. Kubernetes-, Helm-, Kustomize-, Terraform-, Ansible-, VMware- und Windows-Lücken nicht überspielen; das Anschreiben benennt sie.
3. Gehaltsfeld nur mit 90.000 EUR füllen; das liegt bereits am oberen Rand der ausgeschriebenen Spanne.
4. Umzugsbereitschaft ehrlich beantworten; die Stelle ist nicht als vollständig remote ausgeschrieben.
5. Einwilligung zur Weitergabe an andere BWI-Stellen bewusst setzen, nicht vorsorglich.
6. Nach dem Absenden Bestätigung und Eingangs-E-Mail sichern.
7. Delphi-Datensatz steht auf `stage=prep`; nach dem Absenden auf `applied` wechseln.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Bereinigte deutsche Ausschreibung. |
| `lebenslauf.pdf` | Deutscher Lebenslauf, zwei Seiten. |
| `anschreiben.pdf` | Deutsches Anschreiben an Sebastian Stange, eine Seite. |
| `selection.json` | Audit der ausgewählten Highlights und Projekte. |
| `submission-sheet.md` | Diese Feldzuordnung. |
