# Bewerbung SVA System Vertrieb Alexander – Cloud Engineer / Consultant Terraform Specialist (m/w/d)

Stand: 22. November 2026
Stellen-ID: j732

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | SVA System Vertrieb Alexander GmbH, inhabergeführtes Systemhaus |
| Rolle | Cloud Engineer / Consultant – Terraform Specialist (m/w/d) |
| Standorte | 29 SVA-Standorte, unter anderem Bensheim, Berlin, Bonn, Dresden, Düsseldorf, Hamburg, Karlsruhe, Köln, Leipzig, München, Nürnberg, Leinfelden-Echterdingen, Freiburg, Würzburg |
| Anstellung | Vollzeit, unbefristet |
| Reise | Reisebereitschaft innerhalb Deutschlands, im Support- und Betriebsbereich eingeschränkt |
| Veröffentlicht | 6. November 2026, gültig bis 6. Januar 2027; keine Bewerbungsfrist |
| Arbeitsmodell | Mobile Arbeit und Präsenz je nach Aufgabengebiet, flexible Arbeitszeiten, 30 Urlaubstage |
| Vergütung | Keine Spanne in der Anzeige; siehe Abschnitt Gehalt |
| Anzeige | https://www.sva.de/de/job-portal/Cloud-Engineer-Consultant-Terraform-Specialist-mwd-de-j732.html |

Die Anzeige nennt keinen konkreten Einsatzort. Sie führt alle Standorte und verlangt Reisebereitschaft. Karlsruhe, Freiburg und Leinfelden-Echterdingen liegen in zumutbarer Nähe zu Gutach im Breisgau; die Standortwahl ist im Gespräch zu klären.

## Bewerbungsweg

1. Anzeige öffnen: `https://www.sva.de/de/job-portal/Cloud-Engineer-Consultant-Terraform-Specialist-mwd-de-j732.html`
2. Button "Jetzt bewerben!" führt auf das Bewerbungsformular derselben Stelle:

```
https://www.sva.de/de/job-portal/Cloud-Engineer-Consultant-Terraform-Specialist-mwd-de-f732.html
```

3. Das Formular ist ein rexx-systems-Formular, `name="bewerbung_form"`, POST auf dieselbe `f732`-Adresse. Kein Konto nötig. Es wurde nichts abgeschickt.
4. Die Anzeige verlangt die Unterlagen ausschließlich online: Anschreiben, Lebenslauf, Zeugnisse, Gehaltsvorstellung, Eintrittsdatum. Die letzten beiden sind Formularfelder, keine Dokumente.

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
| Reisebereitschaft | Innerhalb Deutschlands vorhanden |

## Abgleich mit der Ausschreibung

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Terraform konzipieren, implementieren, automatisieren | Keine Terraform- oder OpenTofu-Module im Betrieb, kein Terraform-Code im Repository | Lücke, im Anschreiben benannt |
| Terraform-Dateien und -Module optimieren | Modulgrenzen und Wiederverwendung in Nix, nicht in HCL | Übertragbar im Denken, nicht im Werkzeug |
| Terraform Enterprise | Nicht eingesetzt | Lücke |
| HashiCorp Vault | Nicht eingesetzt; Secrets über sops mit age und eigene SSH-CA | Teilweise: Secret-Management ja, anderes Werkzeug |
| Infrastructure as Code, tiefgehend | Dreizehn NixOS-Hosts als ein Flake, jeder Dienst ein Modul, Netz und Firewall als Code | Stark, anderes Werkzeug |
| Virtualisierung und Cloud-Plattformen | Container und deklarative Hosts; kein VMware-Betrieb, keine Enterprise-Migration | Teilweise |
| Linux-Betriebssysteme und Skriptsprachen | NixOS, systemd, nftables, Bash, Python, Go | Stark |
| CI/CD-Tools | Inventargetriebene CI, Modul-Gate je Host, sops-Drift, Link- und Oberflächenchecks | Stark |
| Container-Technologien | Container im Einsatz, Kubernetes als Grundlage | Grundlagen |
| Secret-Management-Tools | sops, age, SSH-CA, keine stehenden Secrets | Stark, nicht Vault |
| Workshops und Schulungen | Mandantenberatung und interne Wissensvermittlung; Terraform-Schulung erst nach Einarbeitung | Teilweise |
| Presales und technische Dokumentation | Beratung, Due Diligence, technische Konzepte, Runbooks, Dokumentation im Repository | Stark |
| Deutsch C1, Englisch B2 | C1 und Muttersprache | Übertrifft |
| Reisebereitschaft | Vorhanden | Erfüllt |

Auswahl im Lebenslauf: 18 von 30 Highlights, 4 von 5 Projekten. Der Korpus ist auf IaC, Provisioning und Betrieb zugeschnitten; die Energie- und Finanzprojekte treten zurück.

## Gehalt

Die Anzeige nennt keine Spanne. Ein Zielfenster wurde nicht vorgegeben.

Im Anschreiben steht 85.000 EUR brutto jährlich. Das ist eine Annahme, abgeleitet aus den Parallelbewerbungen (Bechtle 85.000, BWI 85.000 bis 95.000), und vor dem Absenden zu bestätigen oder zu ersetzen. Das Feld `bewerbung_form[gehaltswunsch]` ist Pflicht; ein leerer Wert blockiert das Formular.

## Formularzuordnung

Feldnamen aus dem ausgelieferten Formular `bewerbung_form`. Pflichtfelder sind mit * markiert.

### Stammdaten

| Feld | Beschriftung | Pflicht | Wert |
| :--- | :--- | :--- | :--- |
| `bewerbung_form[gender]` | Anrede | * | Herr |
| `bewerbung_form[titel]` | Anredetitel | * | Leerzeichen oder "---" wählen; kein Titel vorhanden |
| `bewerbung_form[vorname]` | Vorname | * | Matt |
| `bewerbung_form[nachname]` | Nachname | * | Ji |
| `bewerbung_form[strasse]` | Straße | * | Am Burgerhof 4 |
| `bewerbung_form[plz]` | PLZ | * | 79261 |
| `bewerbung_form[ort]` | Ort | * | Gutach im Breisgau |
| `bewerbung_form[country]` | Land | * | Deutschland |
| `bewerbung_form[geburtsdatum]` | Geburtsdatum | * | Aus dem PII-Speicher eintragen; nicht in diesem Paket ablegen |
| `bewerbung_form[telefon]` | Telefon | * | +49 1733281570 |
| `bewerbung_form[mail]` | E-Mail | * | matt@bountystash.com |

### Qualifikation und Konditionen

| Feld | Beschriftung | Pflicht | Wert |
| :--- | :--- | :--- | :--- |
| `bewerbung_form[schulabschluss]` | Schulabschluss | * | Abitur oder Hochschulreife, je nach Auswahl |
| `bewerbung_form[berufsausbildung_o_sb]` | Berufsausbildung, Freitext | * | "Studium M.Sc. Erneuerbare-Energien-Management, Universität Freiburg" |
| `bewerbung_form[berufsausbildung_m_sb]` | Berufsausbildung, Auswahl | * | Studium oder vergleichbar, je nach Auswahl |
| `bewerbung_form[erfahrung_pref_inJ]` | Berufserfahrung in Jahren | * | 10 |
| `bewerbung_form[eintrittsdatum]` | Eintrittsdatum | * | Ab sofort |
| `bewerbung_form[gehaltswunsch]` | Gehaltswunsch | * | 85.000 EUR |
| `bewerbung_form[wie_gefunden]` | Wie gefunden | * | SVA-Karriereseite oder Jobportal, je nach Auswahl |
| `agbs_check` | AGB und Datenschutz | * | Lesen und bestätigen |

Die Feldnamen `berufsausbildung_o_sb` und `berufsausbildung_m_sb` sind nicht selbsterklärend. Vor dem Absenden die Beschriftung im Formular lesen und die Auswahl danach setzen.

### Uploads

| Feld | Inhalt | Hinweis |
| :--- | :--- | :--- |
| `cv_lebenslauf` | `lebenslauf.pdf` | Optionaler Parser-Upload vor dem Ausfüllen; er liest Stammdaten aus dem PDF |
| `lebenslauf` | `lebenslauf.pdf` | Pflichtanhang, zwei Seiten |
| `anschreiben` | `anschreiben.pdf` | Pflichtanhang laut Anzeige, eine Seite |
| `anlage1`, `anlage2` | Zeugnisse | Nur anhängen, wenn vorhanden; die Anzeige verlangt Zeugnisse |
| `anlage8`, `anlage9`, `anlage10` | Weitere Nachweise | Leer lassen, solange nichts Passendes vorliegt |
| `foto` | Kein Foto | Leer lassen; Bewerbungsfoto ist in Deutschland optional |

## Offene Punkte vor dem Absenden

1. Gehaltswunsch bestätigen. 85.000 EUR ist eine Annahme, kein vorgegebenes Ziel.
2. Geburtsdatum bereithalten; das Feld ist Pflicht und steht nicht im Paket.
3. Beschriftungen von `berufsausbildung_o_sb` und `berufsausbildung_m_sb` im Formular lesen.
4. Standort klären: Karlsruhe, Freiburg oder Leinfelden-Echterdingen sind die nächsten SVA-Standorte.
5. Terraform-Lücke nicht überspielen; das Anschreiben benennt sie und bietet die Nix-IaC-Erfahrung als Übertragung an.
6. Zeugnisse nur anhängen, wenn sie vorliegen; die Anzeige verlangt sie, das Paket enthält keine.
7. Nach dem Absenden Bestätigung und Eingangs-E-Mail sichern.
8. Delphi-Datensatz steht auf `stage=prep`; nach dem Absenden auf `applied` wechseln.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Bereinigte Ausschreibung mit Aufgaben, Profil, Benefits und Unterlagenliste. |
| `lebenslauf.pdf` | Deutscher Lebenslauf, zwei Seiten. |
| `anschreiben.pdf` | Deutsches Anschreiben, eine Seite, mit Gehaltswunsch und Eintrittsdatum. |
| `selection.json` | Audit der ausgewählten Highlights und Projekte. |
| `submission-sheet.md` | Diese Feldzuordnung. |
