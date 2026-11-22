# Bewerbung hep global GmbH — Initiativbewerbung IT-Systemadministration und Infrastruktur

Stand: 22. November 2026
Fit: 4
Sprache: Deutsch (C1)
Art: **Initiativbewerbung** — keine Stelle ausgeschrieben

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | hep global GmbH |
| Zielrolle | IT-Systemadministration und Infrastruktur (nicht ausgeschrieben) |
| Ort | Güglingen, Baden-Württemberg; zweites Office Hamburger Speicherstadt |
| Quelle | Personio-Portal und Karriereseite, beide HTTP 200 am 22.11.2026 |
| Offene Stellen laut Personio | 3: Kaufmännischer Assetmanager PV & BESS · Projektentwickler Solar & BESS · Senior PV / BESS engineer |
| Kanäle | Bewerbungsformular im Jobportal, Kontaktformular, `info@hep.global` |
| Gehalt | keine Angabe, keine Zahl im Anschreiben |

Die Karriereseite lädt ausdrücklich zur Initiativbewerbung ein: „Auch wenn wir derzeit keine passende Stelle ausgeschrieben haben, die deinen Vorstellungen entspricht, freuen wir uns über deine Initiativbewerbung."

Es gibt bewusst **keine `job-description.txt`**: eine Anzeige zu erfinden und gegen sie zu schreiben, würde jede Prüfung entwerten.

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, ohne Anrede mit Namen, Lücken im vierten Absatz |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, eigenständig kompilierbar, 0 Warnungen |
| Dossier | `dossier.md` | Zehn Abschnitte, inklusive belegter Stellensuche |
| Zeugnisse | keine | fehlen weiterhin |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) | Füllung |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 38586 | 580 | `bdb08fac08a797e9` | 93 % / 87 % |
| `anschreiben.pdf` | 1 | 24412 | 378 | `1cd6d02dfb302828` | 76 % |

Satz: 11,5 pt, Zeilendurchschuss 0,70 em, Ränder 1,6 cm / 1,9 cm im Lebenslauf; 10 pt, 0,58 em, Ränder 2,0 cm / 2,2 cm im Anschreiben.

## Anforderungsprüfung

Keine Anzeige, also keine Anforderungsliste des Arbeitgebers. Geprüft wird gegen das, was hep global selbst über seine Anlagen und den Arbeitsplatz schreibt, plus die Anforderungen, die eine IT-Rolle dieser Größe üblicherweise trägt. Die Einschätzung ist entsprechend als abgeleitet markiert.

| Anforderung (abgeleitet) | Nachweis | Bewertung |
| :--- | :--- | :--- |
| Linux-Server betreiben | 13 Server, drei Hardware-Generationen, fünf Jahre allein | Stark |
| Messdaten von Anlagen verstehen | Fraunhofer ISE 2012: Geräteanbindung in C++, Auswertung in Python, Interferometrie | Stark |
| Automatisierte Wartung und Überwachung | Gepinnte Updates, Zustandsprüfung alle 15 Minuten, Alarmierung mit Zustellbestätigung | Stark |
| Sicherung und Wiederherstellung | restic mit geprüften Rückspielungen, Rückrollung über Generationen | Stark |
| Mehrere Standorte verbinden | WireGuard zwischen Standorten, keine öffentlichen Verwaltungsdienste | Stark |
| Nutzerbetreuung | Rechte, Zugänge, Anleitungen über fünf Jahre | Teilweise |
| Anlagenkontext | 10 MW Solar-PV kaufmännisch betreut, Portfolio über USD 100 Mio. | Stark |
| Dokumentation | Runbook je Verfahren, aus dem Bestand erzeugt | Stark |
| Windows Server, Active Directory, Entra ID | nicht vorhanden | **Lücke** |
| VMware, Hyper-V | nicht vorhanden | **Lücke** |
| Netzwerkhardware (Cisco, Fortinet, Aruba) | nicht vorhanden | **Lücke** |
| ISO 27001, BSI-Grundschutz | nicht vorhanden | **Lücke** |
| Umzug nach Baden-Württemberg | zugesagt, Güglingen rund zwei Stunden entfernt | Offen, aber erklärt |
| Deutsch und Englisch | C1 beziehungsweise Muttersprache | Erfüllt |
| Arbeitserlaubnis | US-Staatsangehörigkeit mit Niederlassungserlaubnis | Erfüllt |

## Fit-Begründung: 4

Vier für die technische Passung, nicht für die Stelle — die existiert nicht. Linux-Betrieb, Automatisierung, Überwachung und Sicherungen sind belegt und für ein Unternehmen mit Anlagen und zwei Standorten unmittelbar brauchbar. Dazu kommt der Teil, den die meisten Systemadministratoren nicht mitbringen: Messkette und Anlagenökonomie aus eigener Arbeit, am Fraunhofer ISE und bei einem Solar-Projektentwickler.

Keine 5, weil die Microsoft-Seite vollständig fehlt und weil eine Initiativbewerbung ohne Stelle kein Fit im Sinne einer Ausschreibung sein kann. Keine 3, weil die Kernaufgabe — Systeme betreiben, die verlässlich Daten liefern — genau das ist, was hier fünf Jahre lang getan wurde.

## Offene Punkte

1. **Kein ausgeschriebener Posten.** Vor dem Absenden klären, ob Initiativbewerbungen in den Prozess aufgenommen werden.
2. **Anrede.** Ohne Namen; sobald eine IT-Verantwortliche oder ein IT-Verantwortlicher bekannt ist, das Anschreiben adressieren.
3. **Windows-Lücke** im Anschreiben und im Lebenslauf benannt, nicht kaschiert.
4. **Zeugnisse** fehlen weiterhin.
5. Fit 4 gesetzt; in einem Befehl änderbar.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `dossier.md` | Lage, Begründung, Lücken, Weg, Risiken. |
| `lebenslauf.typ` | Typst-Quelle, zwei Seiten. |
| `anschreiben.typ` | Typst-Quelle, eine Seite. |
| `lebenslauf.pdf` | Zwei Seiten, 580 Wörter. |
| `anschreiben.pdf` | Eine Seite, 378 Wörter. |
| `submission-sheet.md` | Diese Übersicht. |
