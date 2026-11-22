# Bewerbung 1&1 / United Internet — Senior Linux Operations Engineer (w/m/d)

Stand: 22. November 2026
Kennziffer: 5836
Job-ID: 1362529055
Fit: 4
Sprache: Deutsch
Status: Paket gebaut, **nicht eingereicht** — SAP SuccessFactors verlangt ein Konto

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | 1&1 / United Internet AG |
| Bereich | Corporate IT Services, Team Linux Application Operations |
| Rolle | Senior Linux Operations Engineer (w/m/d) |
| Standort | Karlsruhe, DE 76137; laut Benefits bis zu zwei mobile Tage pro Woche |
| Konzern | rund 11.000 Mitarbeitende, rund 68 Mio. User-Accounts in 18 Ländern |
| Umfeld | Konzernweites LDAP, Identity- und Access-Management, zentrale Plattformdienste |
| Schwerpunkt | Stabiler, sicherer, hochverfügbarer Linux-Betrieb; Automatisierung, Standardisierung, Modernisierung |
| Rufbereitschaft | Teilnahme im Team-Rotationsmodell, Bedingung der Stelle |
| Quelle | Karriereseite 1&1, HTTP 200 am 22.11.2026 |
| Gehalt | keine Angabe in der Anzeige; Untergrenze 95.000 EUR nur bei Pflichtfeld |

Die Standortdaten führen zusätzlich `Home-Office, DE` und `deutschlandweit, DE`, die Benefits nennen bis zu zwei mobile Tage pro Woche. Das Paket geht von hybrid in Karlsruhe aus, nicht von einer Remote-Stelle.

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, Lücken im dritten Absatz |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar, 0 Warnungen |
| Dossier | `dossier.md` | Acht Abschnitte, inklusive Herkunft des alten Stands |
| Ausschreibung | `job-description.txt` | Bereinigte Anzeige, 79 Zeilen |
| Zeugnisse | keine | fehlen weiterhin |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) | Füllung |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 39509 | 619 | `61f9bdcf10bd0ae3` | 97 % / 90 % |
| `anschreiben.pdf` | 1 | 25702 | 345 | `e52b498f3b361f81` | 69 % |

Satz: 11,5 pt, 0,70 em Durchschuss, Ränder 1,6 cm / 1,9 cm im Lebenslauf; 10 pt, 0,58 em, 2,0 cm / 2,2 cm im Anschreiben. Beide PDFs bauen byte-identisch neu.

## Was ersetzt wurde

Das Verzeichnis hieß `1und1-linux/` und enthielt nur generierte Artefakte: zwei schreibgeschützte PDFs, einen Symlink `packet` in den Nix-Store und eine `selection.json` mit der algorithmischen Auswahl der Lebenslauf-Highlights. Typst-Quellen gab es nicht. Diese vier Dateien waren nie committet, es gibt also keinen Git-Verlauf, in den sie wandern könnten; die Hashes stehen hier, damit der alte Stand identifizierbar bleibt:

| Alt | Bytes | SHA-256 |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | 43830 | `376d1f40004d97e58a26cbcc4a13b20e2f89f0d0d30b1d627a7f176a673b1db1` |
| `anschreiben.pdf` | 25472 | `9e33abe3e1ac52dd2235ea804287ee16905216e4f0b193ae498d656cf7d640f6` |
| `selection.json` | 6999 | `7e455705a4134c1c6bca2b1b19d64fdafded4f4025e0da820ee40405f91cec2a` |
| `packet` (Symlink) | — | → `/nix/store/dv4yv0rbp2vynp9fd4kd771f3w8mm5dz-appflow-packet-1und1-senior-linux-operations-engineer-karlsruhe` |

## Bewerbungsweg

Nur über das Online-Formular; die Anzeige schließt Bewerbungen per E-Mail ausdrücklich aus. Kontakt für Rückfragen: `jobs@united-internet.de`.

1. Karriereseite, Kennziffer 5836: `https://career.1and1.org/Corporate/job/Karlsruhe-Senior-Linux-Operations-Engineer-%28wmd%29-76137/1362529055`
2. Button „Jetzt bewerben" startet per JavaScript den CAS-Workflow.
3. Stabile SuccessFactors-Adresse: `https://career55.sapsf.eu/career?career_ns=job_application&career_job_req_id=1362529055&company=telecommun&lang=de_DE`
4. Ohne Konto führt der Weg über „Richten Sie sich ein Benutzerkonto ein". Die Bewerbungsmaske erscheint erst nach Anmeldung; ihre Feld-IDs sind nicht öffentlich, die Beschriftungen sind vor dem Absenden zu prüfen.

## Konto anlegen

| Feld | Feld-ID | Pflicht | Wert |
| :--- | :--- | :--- | :--- |
| E-Mail-Adresse | `fbclc_userName` | Ja | matt@bountystash.com |
| E-Mail erneut | `fbclc_emailConf` | Ja | matt@bountystash.com |
| Kennwort | `fbclc_pwd` | Ja | im Passwortmanager erzeugen |
| Kennwort erneut | `fbclc_pwdConf` | Ja | derselbe Wert |
| Vorname | `fbclc_fName` | Ja | Matt |
| Nachname | `fbclc_lName` | Ja | Ji |
| Land des Wohnorts | `fbclc_country` | Ja | Deutschland |
| Profilsichtbarkeit | `fbclc_searPref` | Ja | `2` — nur für diese Stelle |
| Benachrichtigung | `fbclc_emailEnabled` | Nein | nicht aktivieren |
| Datenschutz | `dataPrivacyId` | Ja | lesen und bestätigen |

## Werte für die Maske

| Feld | Wert |
| :--- | :--- |
| Anrede | Herr, falls das Feld erscheint |
| E-Mail / Telefon | matt@bountystash.com / +49 1733281570 |
| Adresse | Am Burgerhof 4, 79261 Gutach im Breisgau, Baden-Württemberg |
| Geburtsdatum | nicht angeben, solange optional |
| Staatsangehörigkeit | US-amerikanisch, deutsche Niederlassungserlaubnis |
| Arbeitserlaubnis | ja, keine Visumsunterstützung nötig |
| Deutsch / Englisch | C1 / Muttersprache |
| Höchster Abschluss | M.Sc. Erneuerbare-Energien-Management, Freiburg, 2014 |
| Ansible im Produktivbetrieb | nein — Nix, Python, Go, Bash; Einarbeitung |
| Monitoring und Logging | Sentinel-Ledger, PSI- und Disk-Druck, Alarmierung mit Zustellbestätigung; Checkmk und ElasticSearch nicht im Einsatz |
| Linux-Erfahrung | dreizehn Hosts, systemd, Kernel- und Initrd-Pinning, nftables, eigene CA |
| Rufbereitschaft | ja, Teilnahme im Rotationsmodell |
| Gehaltswunsch | 95.000 EUR als Untergrenze, nur bei Pflichtfeld |
| Standort | Karlsruhe, bis zu zwei mobile Tage |
| Wie aufmerksam geworden | 1&1-Karriereseite |

## Abgleich

| Anforderung | Nachweis | Bewertung |
| :--- | :--- | :--- |
| Langjährige Erfahrung mit komplexen Linux-Plattformen | dreizehn Hosts, drei Hardware-Generationen, fünf Jahre allein | Stark |
| Sehr gute Linux-Kenntnisse | systemd, Kernel- und Initrd-Module, Boot, nftables, Prozess- und Speicherdruck | Stark |
| Automatisierung mit Ansible | nicht vorhanden | **Lücke** |
| Shell und Python | Bash-Werkzeuge, Python-Auswertung, Go-Dienste | Stark |
| Monitoring, Logging, Troubleshooting | Sentinel-Ledger, PSI-Alarmierung mit Zustellbestätigung, Runbooks | Stark, andere Werkzeuge |
| Versionsverwaltung | Git, GitHub, inventargetriebene CI, Gate je Host | Stark |
| Hochverfügbarer, skalierbarer Betrieb | reproduzierbare Generationen, Rollback in einem Befehl | Teilweise, kein Konzernmaßstab |
| DevOps- und Automatisierungsstrategie | Repository als einziger Weg in die Produktion | Stark |
| Rufbereitschaft | Bereitschaft erklärt | Erfüllt |
| Deutsch und Englisch | C1 und Muttersprache | Übertrifft die Anforderung |
| Standort Karlsruhe, hybrid | Gutach im Breisgau, Karlsruhe gut erreichbar | Erfüllt |

## Offene Punkte vor dem Absenden

1. SuccessFactors-Konto anlegen und E-Mail bestätigen; ohne Konto ist keine Bewerbung möglich.
2. Beschriftungen der Maske gegen die Wertetabelle prüfen; die IDs sind nicht öffentlich.
3. Ansible-Lücke im Formular nicht überspielen. Die Antwort oben ist die ehrliche Version.
4. Gehaltswunsch nur bei Pflichtfeld eintragen.
5. Zeugnisse nicht anhängen, solange das Formular sie nicht verlangt — sie fehlen ohnehin.
6. Nach dem Absenden Bestätigungsseite sichern und den Datensatz auf `applied` setzen.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Bereinigte Anzeige. |
| `dossier.md` | Stelle, Fit, Lücken, Weg, Risiken. |
| `lebenslauf.typ` / `.pdf` | Quelle und zwei Seiten. |
| `anschreiben.typ` / `.pdf` | Quelle und eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
