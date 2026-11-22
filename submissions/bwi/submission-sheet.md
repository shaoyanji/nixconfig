# BWI GmbH — Senior Infrastructure/Platform Engineer (m/w/d)

**Status:** versandfertig nach Prüfung — keine Bewerbung eingereicht
**Stand:** 2026-11-21
**Paket:** `submissions/bwi/`

## Rolle

| Feld | Stand |
| :--- | :--- |
| Unternehmen | BWI GmbH |
| Bereich | DevSecOps Engineering / Competence Center IT-Security (CCITS) |
| Rolle | Senior Infrastructure/Platform Engineer (m/w/d) |
| Stellen-ID | 64059 |
| Standorte | Bonn, Köln oder Meckenheim |
| Arbeitsmodell | Präsenz an einem der Standorte, Homeoffice nach BWI-Regelung; die Remotive-Fassung nennt "remote", der Originaltext nennt die drei Standorte |
| Anstellung | Vollzeit, unbefristet, ab sofort |
| Vergütung | 71.000–91.650 EUR brutto p. a. (BWI-Band); Ziel: 88.000–92.000 EUR |
| Bewerbung | https://www.bwi.de/karriere/stellenangebote/job/senior-infrastructure-platform-engineer-m-w-d-64059 |
| Karriereseite | https://www.bwi.de/karriere |
| JD im Paket | `job-description.txt` |
| JD-Quelle | `~/.config/appflow/jd/bwi-senior-infrastructure-platform.txt` |
| Verifiziert | 2026-11-21: BWI-Stellenseite HTTP 200, Titel "Senior Infrastructure/Platform Engineer (m/w/d)", Stellen-ID 64059 |

**Kontakt BWI:** `bewerbung@bwi.de` · +49 (0)2225 988 25000 · BWI GmbH, Auf dem Steinbüchel 22, 53340 Meckenheim.

## Kandidat

| Feld | Angabe |
| :--- | :--- |
| Name | Matt Ji |
| Adresse | Am Burgerhof 4, 79261 Gutach im Breisgau, DE |
| E-Mail | matt@bountystash.com |
| Telefon | +49 1733281570 |
| LinkedIn | https://linkedin.com/in/mattji |
| GitHub | https://github.com/shaoyanji |
| Staatsangehörigkeit | Vereinigte Staaten |
| Aufenthalt | Deutschland — unbefristete Niederlassungserlaubnis |
| Arbeitsberechtigung | Deutschland/EU ohne Sponsoring; US-Staatsbürger |
| Deutsch | C1 |
| Englisch | Muttersprache |
| Verfügbar ab | 01.12.2026 |
| Gehaltsvorstellung | 88.000–92.000 EUR brutto p. a. |
| Reisebereitschaft | Ja |

## Bewerbungsunterlagen

| Datei | Zweck |
| :--- | :--- |
| `anschreiben.pdf` | Deutsches Anschreiben, 1 Seite A4 |
| `lebenslauf.pdf` | Deutscher Lebenslauf, 2 Seiten A4 |
| `selection.json` | Audit der ausgewählten Projekte, Skills und Stationen |
| `job-description.txt` | Saubere Stellenbeschreibung mit Quellenkopf |
| `submission-sheet.md` | Diese Übersicht |

Zeugnisse, Zertifikate und Nachweise: nicht beigefügt. Im BWI-Portal prüfen, ob Arbeitszeugnisse, Hochschulnachweise oder ein Nachweis der Niederlassungserlaubnis verlangt werden.

## Portal und Formular

Die BWI-Stellenseite führt in das BWI-Bewerbungsportal. Die einzelnen Formularfelder wurden nicht separat ausgelesen; vor dem Absenden im Portal prüfen. Staged sind die üblichen Angaben:

- Vorname: Matt
- Nachname: Ji
- E-Mail: matt@bountystash.com
- Telefon: +49 1733281570
- Anschreiben: `anschreiben.pdf`
- Lebenslauf: `lebenslauf.pdf`
- frühester Eintritt: 01.12.2026
- Gehaltsvorstellung: 88.000–92.000 EUR brutto p. a.
- Deutschkenntnisse: C1
- Englischkenntnisse: Muttersprache
- Reisebereitschaft: Ja
- Staatsangehörigkeit/Aufenthalt: US-amerikanisch; unbefristete deutsche Niederlassungserlaubnis

Keine Angabe zu einer bereits erfolgten Sicherheitsüberprüfung: Das JD nennt keine SÜG-Anforderung. Falls das Portal danach fragt, wahrheitsgemäß beantworten und keine Prüfung behaupten, die nicht stattgefunden hat.

## Anforderungen → Evidenz

| BWI-Anforderung | Evidenz im Paket | Bewertung |
| :--- | :--- | :--- |
| Infrastruktur, Linux, Nix/NixOS | 13-Host-NixOS-Flotte aus einem Flake; gepinnte Inputs, systemd, hermetische Builds, CI-Gate und Rollback | Stärke |
| Kubernetes, ideal CKA/CKS | Kubernetes in den DevOps-Skills; keine CKA/CKS-Zertifizierung, keine air-gapped-Cluster in Produktion | Offene Lücke, im Anschreiben benannt |
| Automation / Infrastructure as Code | Flake, Taskfile-Steuerung, CI/CD, Go-/Python-/Bash-Automatisierung, reproduzierbare Builds | Stärke |
| Linux-Härtung | SOPS/age-Secrets, SSH-CA mit kurzlebigen Zertifikaten, systemd-Dienste, keine stehenden Host-Schlüssel | Stärke, keine formale BSI-Härtungszertifizierung |
| Virtualisierung | KVM-/microVM-Labore und systemd-Gäste | Laborerfahrung, keine großen VMware-/OpenStack-Umgebungen |
| Network Storage / Ceph | ZFS, SMART/NVMe, Backup- und Restore-Praxis | Ceph nicht produktiv; im Anschreiben benannt |
| Go | `bountystash`-Dienst, Go-Fuzzer, CLI/TUI | Stärke |
| Deutsch C1, Englisch gut | Deutsch C1, Englisch Muttersprache | Erfüllt |
| Reisebereitschaft | Ausdrücklich zugesagt | Erfüllt |
| Dokumentation / Stakeholder | Runbooks, technische Dokumentation, Kunden- und Teamkommunikation | Plausibel, im Anschreiben adressiert |

## Positionierung im Anschreiben

Das Anschreiben führt mit der NixOS-Flotte und der DevSecOps-Schnittstelle, nicht mit der Energie-Historie. Es nennt drei Grenzen ausdrücklich:

1. **Kubernetes:** Werkzeugkasten und Grundlagen, aber keine CKA/CKS-Zertifizierung und keine air-gapped-Produktion.
2. **Ceph:** nicht produktiv betrieben; Storage-Erfahrung über ZFS, SMART/NVMe und Backups.
3. **Virtualisierung:** KVM-/microVM-Labore, keine großen VMware- oder OpenStack-Umgebungen.

Diese Offenheit ist bewusst: BWI betreibt sicherheitskritische Infrastruktur, und ein Gespräch über die Lücken ist besser als eine Behauptung, die im Technical Interview auffällt.

## Gehalt und Start

- BWI-Band: 71.000–91.650 EUR brutto p. a.
- Staged: 88.000–92.000 EUR brutto p. a. — oberes Ende, innerhalb der vom Auftraggeber genannten Bandbreite von 71.000–92.000 EUR.
- Frühester Eintritt: 01.12.2026.
- Reisebereitschaft: ja.
- Kein Sponsoring erforderlich.

## Vor dem Absenden

- [ ] Im BWI-Portal prüfen, ob Anschreiben und Lebenslauf als PDF hochgeladen oder einzelne Felder manuell befüllt werden.
- [ ] Prüfen, ob Zeugnisse, Hochschulnachweise oder Niederlassungserlaubnis verlangt werden.
- [ ] Prüfen, ob das Portal eine Sicherheitsüberprüfung/SÜG abfragt; keine nicht erfolgte Prüfung behaupten.
- [ ] Standortpräferenz Bonn, Köln oder Meckenheim angeben; Homeoffice-Regelung bestätigen.
- [ ] Gehaltsfeld mit 88.000–92.000 EUR brutto p. a. füllen.
- [ ] Nach dem Absenden: Bestätigungsmail archivieren und Status in `apps-db` auf `applied` setzen.

## Offene Punkte

- **Kubernetes-Tiefe:** Die Rolle verlangt sehr gute Kubernetes-Kenntnisse, ideal CKA/CKS. Das Paket behauptet weder Zertifizierung noch air-gapped-Produktion; es stellt die Linux-, Automatisierungs- und Sicherheitsseite in den Vordergrund.
- **Ceph:** Nicht produktiv; ZFS/SMART/NVMe sind die belegbare Storage-Basis.
- **Sicherheitsüberprüfung:** Nicht im JD genannt, aber bei BWI/Bundeswehr-Umfeld im Portal klären.
- **Standort:** Die Anzeige nennt Bonn, Köln und Meckenheim; die Remotive-Fassung bezeichnet die Rolle als remote. Die Präsenz- und Homeoffice-Erwartung vor dem Absenden bestätigen.

Keine Bewerbung wurde eingereicht.
