# Dossier — 1&1 / United Internet, Senior Linux Operations Engineer (w/m/d)

Stand: 22. November 2026
Kennziffer: 5836
Job-ID (SuccessFactors): 1362529055
Ort: Karlsruhe, DE 76137; Home-Office und deutschlandweit in den Standortdaten, laut Benefits bis zu zwei mobile Tage pro Woche
Fit: 4

## 1. Was hier neu ist

Das Paket existierte bereits als `submissions/1und1-linux/`: zwei fertig kompilierte PDFs, eine Ausschreibung und ein Datenblatt. Es war aus einem Generator entstanden — die PDFs waren schreibgeschützt (Modus 444), neben ihnen lag ein Symlink `packet` in den Nix-Store (`/nix/store/dv4yv0r…-appflow-packet-1und1-senior-linux-operations-engineer-karlsruhe`) und eine `selection.json`, die dokumentiert, welche Lebenslauf-Highlights ein Algorithmus ausgewählt hat. **Typst-Quellen gab es nicht.**

Damit war das Paket nicht wartbar: keine Zeile ließ sich ändern, ohne den Generator erneut zu befähigen, und die Auswahl der Inhalte war eine Bewertung, die niemand nachlesen kann. Dieses Dossier und die beiden `.typ`-Dateien ersetzen das.

| Alt | Größe | SHA-256 | Verbleib |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 43830 B | `376d1f40004d97e58a26cbcc4a13b20e2f89f0d0d30b1d627a7f176a673b1db1` | ersetzt, Quellen neu |
| `anschreiben.pdf` | 25472 B | `9e33abe3e1ac52dd2235ea804287ee16905216e4f0b193ae498d656cf7d640f6` | ersetzt, Quellen neu |
| `selection.json` | 6999 B | `7e455705a4134c1c6bca2b1b19d64fdafded4f4025e0da820ee40405f91cec2a` | entfernt |
| `packet` | Symlink | — | entfernt |

Die Dateien waren nie committet (das Verzeichnis war untracked), also gibt es keinen Git-Verlauf, in den sie wandern könnten. Die Hashes stehen hier und im Datenblatt, damit sich der alte Stand identifizieren lässt, solange er noch im Store liegt.

Das Verzeichnis heißt jetzt `1und1-linux-operations/`, wie für dieses Paket vorgesehen. Der Datenbank-Eintrag zeigt auf den neuen Pfad.

## 2. Die Stelle

United Internet beschäftigt rund 11.000 Mitarbeitende und betreut rund 68 Millionen User-Accounts in 18 Ländern; die Marken sind 1&1, GMX, WEB.DE, IONOS, STRATO und 1&1 Versatel. Corporate IT Services verantwortet die konzernweite interne IT, das Team Linux Application Operations betreibt LDAP, Identity- und Access-Management und weitere zentrale Plattformdienste.

Die Aufgaben sind Betrieb plus Modernisierung: stabiler, sicherer, hochverfügbarer Betrieb; Planung und Design skalierbarer, wartbarer Lösungen über den ganzen Lifecycle; Störungsanalyse auf System-, Netz- und Applikationsebene; Automatisierung mit Ansible, Shell und Python; Mitgestaltung der DevOps-Strategie; Transformation manuell betriebener Systeme in automatisierte Plattformen.

Das ist bemerkenswert ehrlich formuliert. Viele Anzeigen schreiben „Automatisierung" und meinen „Skripte"; diese beschreibt den Weg von Handarbeit zu Standardisierung als eigenes Arbeitspaket und nennt die Bereitschaft zur Rufbereitschaft im Rotationsmodell als Bedingung, nicht als Benefit.

## 3. Fit 4, und warum nicht 5

Die Kernaufgabe ist deklarativ betriebene Linux-Infrastruktur mit Telemetrie und Automatisierung — fünf Jahre lang allein verantwortet, mit Kernel- und Boot-Pinning, systemd, nftables, eigener Zertifizierungsstelle und einem Sentinel, der PSI- und Disk-Druck misst. Die Anzeige verlangt genau diese Denkweise: Betriebsmodelle hinterfragen, Automatisierungspotenziale finden, manuelle Tätigkeiten nachhaltig reduzieren.

Keine 5, weil drei Punkte fehlen, die die Anzeige ausdrücklich nennt:

1. **Ansible** steht in den Aufgaben und in den Qualifikationen. Die Automatisierung im Bestand ist Nix, Python, Go und Bash. Das ist keine Ausrede — deklarative Konfiguration ist das, was Ansible erreichen will —, aber es ist ein anderes Werkzeug mit anderer Fehlerkultur, und ein Team, das Ansible-Rollen pflegt, merkt den Unterschied in der ersten Woche.
2. **Checkmk und ElasticSearch** sind nicht im Einsatz. Die Telemetrie ist selbst gebaut (Sentinel-Ledger, PSI, Disk, Jobstatus). Konzeptionell näher als es klingt, operativ fremd.
3. **Maßstab.** Eine Plattform für 11.000 Nutzende mit LDAP und IAM im Konzern hat Matt nicht betrieben. Die Flotte ist klein; die Fragen sind übertragbar, die Lastprofile nicht.

Kein 3, weil die Anzeige Linux-Tiefe und Automatisierungsdrang über alles andere stellt, beides belegbar ist, und weil die Lücken benannt statt kaschiert werden.

## 4. Abgleich

| Anforderung | Nachweis | Bewertung |
| :--- | :--- | :--- |
| Langjährige Erfahrung mit komplexen Linux-Plattformen | Dreizehn Hosts, drei Hardware-Generationen, fünf Jahre allein | Stark |
| Sehr gute Linux-Kenntnisse | systemd, Kernel- und Initrd-Module, Boot, nftables, Speicher- und Prozessdruck | Stark |
| Automatisierung mit Ansible | nicht vorhanden | **Lücke** |
| Shell und Python sicher | Bash-Werkzeuge, Python-Auswertung, Go-Dienste | Stark |
| Monitoring, Logging, Troubleshooting | Sentinel-Ledger, PSI-Alarmierung mit Zustellbestätigung, Runbooks | Stark, andere Werkzeuge |
| Versionsverwaltung | Git, GitHub, inventargetriebene CI, Gate je Host | Stark |
| Hochverfügbarer, skalierbarer Betrieb | reproduzierbare Generationen, Rollback in einem Befehl, geprüfte Rückspielungen | Teilweise: keine HA-Architektur im Konzernmaßstab |
| DevOps- und Automatisierungsstrategie | Repository als einziger Weg in die Produktion; Prüfung vor dem Rollout | Stark |
| Störungsanalyse auf System-, Netz- und Applikationsebene | Betrieb ohne zweite Person; Runbook je Verfahren | Plausibel |
| Rufbereitschaft im Rotationsmodell | Bereitschaft erklärt | Erfüllt |
| Sehr gute Deutsch- und Englischkenntnisse | C1 und Muttersprache | Erfüllt |
| Standort Karlsruhe, bis zu zwei mobile Tage | Gutach im Breisgau, Karlsruhe gut erreichbar | Erfüllt |

## 5. Weg der Einreichung

Nur über das Online-Formular; die Anzeige sagt ausdrücklich, dass Bewerbungen per E-Mail nicht berücksichtigt werden. Kontaktadresse für Rückfragen: `jobs@united-internet.de`.

Der Weg führt über SAP SuccessFactors und verlangt ein Konto:

1. Karriereseite mit der Kennziffer 5836, Button „Jetzt bewerben".
2. SuccessFactors: `https://career55.sapsf.eu/career?career_ns=job_application&career_job_req_id=1362529055&company=telecommun&lang=de_DE`
3. Konto anlegen, E-Mail bestätigen, dann erscheint die Bewerbungsmaske. Die Feld-IDs der Maske sind ohne Konto nicht öffentlich; das Datenblatt führt die Werte, die vor dem Absenden gegen die Beschriftungen zu prüfen sind.

## 6. Gehalt

In der Anzeige steht keine Zahl. Die Untergrenze im Datenblatt ist 95.000 EUR und wird nur eingetragen, wenn das Formular ein Pflichtfeld daraus macht. Sie ist eine Untergrenze, keine Marktschätzung.

## 7. Risiken

- **Ansible** ist der wahrscheinlichste Grund für eine Ablehnung. Deshalb steht die Lücke im Anschreiben, nicht nur im Datenblatt.
- **Maßstab.** Ein Konzern mit 11.000 Nutzenden hat Betriebsprozesse, die eine Einzelperson nicht kennt: Change-Boards, Freigaben, Notfallpläne. Lernbar, aber real.
- **Rufbereitschaft** ist Bedingung. Bereitschaft ist erklärt; Erfahrung mit einem rotierenden 24/7-Dienstplan in einem Konzern ist es nicht.
- **Hybrid, nicht remote.** Zwei mobile Tage, der Rest in Karlsruhe. Von Gutach im Breisgau sind das rund anderthalb Stunden je Richtung; das ist pendelbar, aber es ist Pendeln.

## 8. Nächste Schritte

1. Konto in SuccessFactors anlegen und die Bewerbungsmaske öffnen.
2. Feldbeschriftungen gegen das Datenblatt prüfen; Pflichtfelder zuerst.
3. Lebenslauf und Anschreiben aus diesem Verzeichnis hochladen.
4. Nach dem Absenden die Bestätigung sichern und den Datensatz auf `applied` setzen.
5. Zeugnisse fehlen weiterhin in jedem Paket dieses Bestands, auch hier.
