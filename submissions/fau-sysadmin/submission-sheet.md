# Bewerbung — FAU Erlangen-Nürnberg, IT-Systemadministrator Linux und Windows

Stand: 22. November 2026
Fit: 3
Sprache: Deutsch
Frist: 01.12.2026
Status: Paket kompiliert und konsistent; zwei Punkte vor dem Absenden zu klären

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Friedrich-Alexander-Universität Erlangen-Nürnberg, Technische Fakultät |
| Einheit | Lehrstuhl für Fertigungstechnologie (LFT), Blech- und Massivumformung |
| Rolle | IT-Systemadministrator Linux und Windows (m/w/d) |
| Kennung | Interamt 1513404, Kennung 2015 |
| Entgelt | TV-L; Entwicklungsmöglichkeit bis E 11 |
| Dauer | **unbefristet**, angelegt als Nachfolge der IT-Leitung des Lehrstuhls |
| Standorte | Erlangen, Haberstraße 9 und Konrad-Zuse-Straße 5, Betreuung aller Standorte |
| Quelle | Interamt, abgerufen 22.11.2026 (HTTP 200) |
| Weg | interamt.de, Onlineplattform; keine Post- oder E-Mail-Bewerbung |

## Aufgabe laut Anzeige

Wartung und Pflege der IT-Infrastruktur (Linux und Windows, Server, NAS, Workstations, PCs, Cluster) an allen Standorten einschließlich Transport und Inbetriebnahme; selbstständige Planung und Umsetzung von Infrastrukturprojekten; technische Anwenderbetreuung vor Ort und per Fernzugriff; Benutzerkonten in Linux- und Windows-Umgebungen mit komplexer Rechteverwaltung; Beschaffung nach den Richtlinien der FAU.

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, Lücke im dritten Absatz |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar |
| Ausschreibung | `job-description.txt` | Volltext plus Abgleich |
| Zeugnisse | keine | fehlen weiterhin |

Beim Umbau entfernt: `letter.json`, `resume.json`, `selection.json`. Beide PDFs neu erzeugt.

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 36976 | 535 | `a720f76e9d36472d` |
| `anschreiben.pdf` | 1 | 24538 | 357 | `c8692d3ede21dbc6` |

## Anforderungsprüfung

| Anforderung | Nachweis | Bewertung |
| :--- | :--- | :--- |
| Linux-Systeme administrieren | 13 Server, drei Hardware-Generationen, fünf Jahre allein | Stark |
| Serverbetrieb an mehreren Standorten | Mehrere Standorte und Netze, WireGuard zwischen ihnen, keine öffentlichen Verwaltungsdienste | Stark |
| Benutzerkonten und Rechteverwaltung | Rechte, Zugänge, Nutzerbetreuung über Jahre | Stark |
| Automatisierte Wartung und Überwachung | Gepinnte Updates, Zustandsprüfung alle 15 Minuten, Alarmierung mit Zustellbestätigung | Stark |
| Sicherung und Wiederherstellung | restic mit geprüften Rückspielungen, Rückrollung über Generationen | Stark |
| Beschaffung und Inbetriebnahme | Auswahl, Aufbau, Installation, Übergabe selbst gemacht | Stark |
| Anwenderbetreuung | Nutzende ohne Administratorrolle betreut, Anleitungen geschrieben | Stark |
| Hochschulabschluss Informatik oder vergleichbar | M.Sc. Renewable Energy Management, 1,8; Berufserfahrung statt Informatikstudium | Teilweise |
| Windows Server 2019/2022/2025, Active Directory, DNS, GroupPolicies | nicht vorhanden | **Lücke** |
| Hyper-V, Virtualisierung | nicht vorhanden | **Lücke** |
| PowerShell, MS-Office | Shell-Erfahrung ja, PowerShell nicht; Office nicht belegt | **Lücke** |
| Lizenzserver, CAD-/FE-Software | nicht vorhanden | **Lücke** |
| Führerschein Klasse B | nicht bestätigt | **Offen** |
| Deutsch C1, Englisch B2 | C1 beziehungsweise Muttersprache | Erfüllt |
| Personal- und Budgetverantwortung als Perspektive | Budget und Beschaffung im eigenen Betrieb, keine disziplinarische Führung | Teilweise |

## Fit-Begründung: 3

Die Linux-Seite und der automatisierte Betrieb sind stark und für einen Lehrstuhl mit mehreren Standorten unmittelbar brauchbar: beschreiben statt von Hand ändern, Gates vor dem Rollout, Rückrollung in Minuten, geprüfte Sicherungen, Betreuung von Menschen, die keine Administratoren sind.

Keine 4, weil die Anzeige Windows als gleichrangig führt: Windows Server bis 2025 mit Active Directory, DNS, Firewall und GroupPolicies, dazu Hyper-V, PowerShell und Lizenzserver. Nichts davon ist belegt. Keine 2, weil die Stelle ohne diese Kenntnisse führbar ist, wenn jemand Serverbetrieb und Automatisierung wirklich beherrscht — und weil die Anzeige Lernbereitschaft ausdrücklich verlangt.

## Offene Punkte

1. **Führerschein Klasse B** — in der Anzeige gefordert, im Lebenslauf nicht behauptet. Vor dem Absenden bestätigen.
2. **IT-Leitung als Perspektive** — die Stelle ist als Nachfolge der IT-Leitungsfunktion angelegt, mit fachlicher und disziplinarischer Personal- und Budgetverantwortung. Das Anschreiben verspricht keine Führungserfahrung; im Gespräch ist zu klären, ob die Perspektive Bedingung oder Angebot ist.
3. **Windows-Seite** — Windows Server, AD, Hyper-V, PowerShell als Lücke im Anschreiben benannt.
4. **Hochschulabschluss** — die Anzeige nennt Informatik oder vergleichbare Fachrichtung; der Abschluss ist fachfremd, die Berufserfahrung ist der Ausgleich.
5. Zeugnisse fehlen weiterhin.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Ausschreibungstext plus Abgleich. |
| `lead.md` | Fit, Lücken, Weg. |
| `lebenslauf.typ` | Typst-Quelle, zwei Seiten. |
| `anschreiben.typ` | Typst-Quelle, eine Seite. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
