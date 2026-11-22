# citeq — DevOps Engineer (m/w/d), IT-Dienstleister der Stadt Münster

Interamt `1510832`, Ausschreibungsnummer **22-029/26**. Native Typst-Quellen, `packet`-Symlink entfernt.
Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `citeq-muenster-devops` |
| Arbeitgeber | citeq — IT-Dienstleister der Stadt Münster |
| Rolle | DevOps Engineer (m/w/d) |
| Ausschreibungsnummer | 22-029/26 |
| Interamt | 1510832 |
| Ort | Scheibenstraße 109, 48153 Münster — hybrid |
| Ansprechpartner | Tobias Burgmann, Oliver Musiolik |
| Vergütung | **TVöD / TV IKT E 11**, unbefristet |
| Frist | **29.11.2026** |
| Sprache | Deutsch |
| Fit | 3 (DB-Eintrag 4 wie beauftragt) |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Linux-Plattformbetrieb | Dreizehn deklarierte Hosts, Gates, Rollback | stark |
| Deklaratives Flottenmanagement | Gepinnte Inputs, Rebuild, Generation-Rollback | stark |
| Web-Plattform-Hosting | nginx, TLS über eigene CA, virtuelle Hosts | stark |
| Container-Automatisierung | Gepinnte Bauumgebungen, MicroVMs, Slices | teilweise |
| Sicherheitshygiene | nftables Default-Neny, SOPS/age, SSH-CA, Minimalrechte | stark |
| Digitale Souveränität | lokale Inferenz auf eigener Hardware, keine Fremd-API | stark, ungewöhnlich |
| Kommunale Verfahren / Verwaltung | **nicht vorhanden** | **Lücke** |
| TVöD E 11 | Eingruppierung im Brief genannt, keine Euro-Zahl | erfüllt |
| Präsenz Münster | Umzug zugesagt | erfüllt |

## Das Argument

citeq betreibt die IT einer Stadt, also gilt dort eine andere Beweislast als bei einem Produktunternehmen:
Der Betrieb muss erklärbar bleiben, auch wenn die Person nicht mehr da ist, die ihn aufgebaut hat. Das
Anschreiben führt deshalb nicht Werkzeuge auf, sondern die Kette aus Deklaration, Gate, Generation und
Rollback — und ergänzt sie um die Souveränitätspointe, die bei einer Kommune zieht: Secrets verschlüsselt,
Zugang über kurzlebige Zertifikate, Inferenz lokal statt über eine Fremd-API.

Die Lücke ist ehrlich benannt: **keine Verwaltungserfahrung** — kein Rechenzentrum mit kommunalen
Verfahren, keine Haushaltsvorgänge, keine Abstimmung mit Fachämtern, kein IT-Verbund. Der Brief dreht das
nicht weg, sondern stellt es gegen das, was schwerer nachzulernen ist.

## Vergütung

**TVöD / TV IKT E 11** ist ausgeschrieben; der Brief nennt die Eingruppierung und keine Euro-Zahl, weil eine
Forderung über der ausgeschriebenen Gruppe gegenstandslos wäre.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `chmod u+w *.pdf` vor dem Bau | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `22-029/26`, `1510832`, `E 11`, `citeq`, `Niederlassungserlaubnis` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 Lebenslauf | `27864b2fc9533f9fcd7ffd860c3c824de095a225b7e3af3d2e0366de7d1b6cab` |
| sha256 Anschreiben | `7f2aade0f9a9bdb5cd58447c49b0a02f4444d73f1d62a2e4748c4d2d12a1345d` |
| Altlasten | `packet`-Symlink, JSON-Quellen entfernt |

## Nächste Schritte

1. Über Interamt mit ID **1510832** und Ausschreibungsnummer 22-029/26 bewerben.
2. Anschreiben an beide Ansprechpartner adressiert — bei kommunalen Stellen ist das üblich und wird bemerkt.
3. Im Gespräch klären, wie viel der Rolle Container-Plattform ist und wie viel klassisches Hosting.
