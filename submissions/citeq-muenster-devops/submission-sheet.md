# Bewerbung citeq Münster — DevOps Engineer (m/w/d)

Stand: 22. November 2026
Fit: 4 / 5
Ausschreibungsnummer: 22-029/26
Frist: **29.11.2026**

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | citeq, zentraler IT-Dienstleister der Stadt Münster und weiterer Kommunen im Münsterland |
| Team | Web-Entwicklung und -Betrieb |
| Rolle | DevOps Engineer (m/w/d) |
| Standort | Scheibenstraße 109, 48153 Münster; hybrid und remote möglich |
| Entgelt | TVöD-VKA E 9a bis E 11 (A 11) |
| Vertrag | Unbefristet, Vollzeit, Start zum nächstmöglichen Zeitpunkt |
| Frist | 29.11.2026 |
| Weg | Online-Bewerbung über das Verfahren der Stadt Münster; Interamt-Anzeige 1510832 |

## Quellenlage

Die Interamt-Seite liefert eine Redirect-Schleife und ließ sich nicht rendern; der Anzeigentext stammt aus dem baito-Spiegel derselben Ausschreibung (Team, Entgelt, Frist, Standort stimmen mit der DB überein). Aufgabendetails und Ansprechpartner sind deshalb nicht vollständig belegt und vor dem Absenden am Original zu prüfen.

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, direkt kompilierbar |
| Zeugnisse | keine Datei | Im Bewerbungsverfahren der Stadt üblich, muss ergänzt werden |

## Abgleich

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Hochschulstudium IT oder IT-Ausbildung | M.Sc. Erneuerbare-Energien-Management, Modellierung mit neuronalen Netzen | Erfüllt über vergleichbare Qualifikation |
| Mehrjährige Erfahrung mit Linux-Webservern | Zehn Jahre Linux-Betrieb, Dienste hinter Reverse Proxy, kein Apache/IIS-Betrieb im großen Stil | Teilweise |
| Mehrjährige Erfahrung IT-Security | sops/age, eigene Zertifizierungsstelle, nftables, keine offene Schnittstelle | Stark im Betrieb, ohne Zertifizierung |
| Container-Technologien | Kein Kubernetes, kein Docker im Produktivbetrieb | Lücke |
| CI/CD-Pipelines | CI-Gates je Host, identische Prüfung vor dem Ausrollen, Rückrollung je Generation | Stark im Konzept, Werkzeuge weichen ab |
| deklarative Infrastruktur | Vollständig in einem Flake, Git als einzige Quelle | Stark |
| Monitoring und Betriebssicherheit | Sentinel-Ledger, Gatus, Zustellbestätigung, geprüfte Wiederherstellungen | Stark |
| Öffentliche Verwaltung, Vergaberecht | Keine Erfahrung | Lücke |
| Deutsch C1 | C1, Studium und Arbeit in Freiburg auf Deutsch | Erfüllt |

## Fit-Begründung: 4 von 5

Vier, weil das Team Web-Entwicklung und -Betrieb genau die Kombination braucht, die hier belegt ist: Linux-Betrieb, deklarative Automatisierung, CI-Gates, Monitoring mit Zustellbestätigung, Sicherheit im Betrieb und Dokumentation. Die Ausschreibung nennt Container, CI/CD und IT-Security als wünschenswert, nicht als Bedingung; das ist der Unterschied, der die Vier trägt.

Nicht fünf, weil die Container-Ebene fehlt: kein Kubernetes, kein OpenShift, kein Docker im Produktivbetrieb. Dazu kommen Ansible und Terraform als ungewohnte Werkzeuge und fehlende Erfahrung mit kommunalen Verfahren.

## Gehalt

TVöD-VKA E 9a bis E 11, unbefristet; die Anzeige nennt eine Spanne von rund 46.500 bis 75.900 EUR. Die eigene Erwartung von 85.000 bis 95.000 EUR liegt über E 11 und wird im Anschreiben nicht genannt. Verhandelbar ist die Stufe und die Eingruppierung, nicht die Gruppe.

## Offene Punkte

1. **Frist 29.11.2026** — eine Woche. Bewerbung über das Verfahren der Stadt Münster, nicht per E-Mail.
2. **Präsenzanteil klären.** Wohnort Gutach im Breisgau, rund 600 km; hybrid ist genannt, der erwartete Umfang nicht. Das ist die entscheidende Frage vor einer Zusage, keine Formalie.
3. Zeugnisse fehlen.
4. Container-, Ansible- und Terraform-Lücke steht im Anschreiben; nicht überspielen.
5. Eingruppierung E 9a bis E 11 ansprechen; E 11 ist das Ziel, nicht E 9a.
6. Originalanzeige prüfen, weil der Text aus einem Spiegel stammt.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Anzeigentext aus dem Spiegel, mit Quellenhinweis. |
| `lead.md` | Fit, Lücken, Lage, Gehalt, Weg. |
| `lebenslauf.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `anschreiben.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
