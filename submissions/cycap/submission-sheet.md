# CYCAP Asset Management GmbH — PPA Originator (m/w/d)

Speersort 10, 20095 Hamburg · Vollzeit, Festanstellung · hybrid (bis 2 Tage mobil) · Personio **2467046**.
**Keine Gehaltsbandbreite veröffentlicht**; 85.000–95.000 EUR brutto p.a. ist die eigene Vorstellung für das Pflichtfeld, kein Angebot.
DB-Zeile `cycap-ppa-originator`, Stufe **prep** — vorbereitet, nicht eingereicht.

## Provenance

In diesem Ordner lag **keine Stellenbeschreibung**. `job-description.txt` ist aus dem abgelösten `Cycap_Submission_Sheet.txt` rekonstruiert, das am
2026-11-21 die Karriereseite und das Personio-Formular geprüft hat (Stelle offen, Formular erreichbar). Kein frischer Abruf. Die Kontaktdaten des
Recruitings stehen dort und in der JD.

Deutsche Typst-Quellen, 2026-11-22 — Typst 0.15.1, ausschließlich DejaVu Sans.

## Dateien

| Datei | Seiten | Wörter | Warnungen | sha256 (erste 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 660 | 0 | `5f72f03b72555d41` |
| `anschreiben.pdf` | 1 | 382 | 0 | `81f4dd337ada0315` |

Dazu beide `.typ`-Quellen, `job-description.txt` und dieses Blatt.

## In die Git-Historie verschoben

| Artefakt | sha256 (erste 16) | Was es war |
| :--- | :--- | :--- |
| `Matt_Ji_Lebenslauf_Cycap.pdf` | `10a21c3034976a0f…` | Nix-PDF, deutsches CV-Projektion mit Auswahl aus dem Korpus |
| `Cycap_Anschreiben.pdf` | `110da7089f8a7c2f…` | Nix-PDF, einseitiges Anschreiben mit Gehaltsangabe im Text |
| `Cycap_Anschreiben.txt` | gleicher Text | Klartext-Duplikat des Anschreibens |
| `Cycap_Submission_Sheet.txt` | — | Personio-Feldzuordnung, Kandidatenangaben, Gehaltsvorstellung, Checkliste |

Alle vier bleiben in der Git-Historie des vorherigen Commits erhalten.

## Was sich inhaltlich geändert hat

Das alte Anschreiben behauptete eine PPA-Praxis, die der Korpus nicht deckt: „verhandelte PPA- und Direktvermarktungsstrukturen“, Bewertung von
Corporate- und Utility-PPA-Strukturen, Preis- und Ertragsabsicherungsstrategien — als wäre Origination über Jahre betrieben worden. Der Korpus belegt
ein **dreimonatiges PPA-Mandat für die EWE Trading (2023)**, risikoadjustierte PPA- und Hedging-Modelle, vier Jahre Solar-Asset-Management und die
Wetter-/Volatilitätsarbeit. Das neue Anschreiben nennt das Mandat mit seiner Dauer und sagt ausdrücklich, dass eine eigene Abschlussliste im
PPA-Vertrieb fehlt. Das ist der Unterschied zwischen einem Paket, das ein Fachgespräch übersteht, und einem, das beim ersten Nachfragen bricht.

Der Lebenslauf führt jetzt die 10 MW PV-Leistung und das Portfolio über 100 Mio. USD als eigene Position, ergänzt um die Due-Diligence- und
Bankenschnittstelle — beides Korpus-belegt und für diese Stelle relevanter als die Software-Projekte, die in der alten Projektion dominierten.

## Lücken, in beiden Dokumenten benannt

Keine eigene Origination-Historie: keine über Jahre gewonnenen Großkunden, keine abgeschlossenen Corporate-PPAs in eigener Verantwortung. Keine
Direktvermarktungs-Erfahrung im operativen Betrieb. Keine BESS-Projektierung, nur die technische Grundlage, um darüber zu sprechen. Hamburg-Präsenz
ist ungeklärt — Wohnsitz Gutach im Breisgau, die Stelle erwartet bis zu zwei mobile Tage und Präsenz vor Ort.

## Einordnung

**3 von 5.** Stark auf der Bewertungs- und Risikoseite (PPA-Modellierung, Solar-Asset-Management, Finanzmodelle, Bankenschnittstelle), dünn auf der
Vertriebsseite, die diese Rolle im Titel trägt. Die DB-Zeile stand zuvor auf „other / Deprioritized — commercial/asset-management role, poor
technical fit“; das war an einer dünneren Projektion gemessen und ist jetzt auf `prep` mit Fit 3 korrigiert, ohne die Lücke zu kaschieren.

Gehalt steht nur im Blatt (Pflichtfeld im Personio-Formular), nicht im Anschreiben. Verfügbar ab 01.12.2026.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile` beide Quellen | je 0 Warnungen |
| Seitenbudget | CV 2 Seiten, Anschreiben 1 Seite (vor dem Commit geprüft) |
| `**` in den Quellen | 0 |
| Typografische Anführungszeichen | 0 |
| Unbelegte PPA-Origination-Behauptungen | 0 außerhalb des Absatzes, der die Lücke benennt |
| Gehalt im Anschreiben | 0 Nennungen |
| `task checks:prose` | exit 0 |
| Altlasten | alle vier verschoben, Hashes oben |
