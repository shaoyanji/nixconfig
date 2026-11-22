# Alexander Thamm GmbH — Principal DevOps Engineer (m/w/d)

Join.com `12492799`. Native Typst-Quellen. Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `alexander-thamm` |
| Arbeitgeber | Alexander Thamm GmbH (AT), München |
| Rolle | Principal DevOps Engineer (m/w/d) |
| ATS | Join.com |
| Gehalt | Band **95.000 – 115.000 €**; Vorstellung im Brief **95.000 – 110.000 €** |
| Sprache | Deutsch |
| Fit | 3 (DB-Eintrag 4 wie beauftragt) |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Plattformarchitektur, Principal-Niveau | Deklarierte Flotte, Gates, Rollback, Task-Oberfläche | stark |
| Deklarativer Betrieb | Gepinnte Inputs, Rebuild, Generation-Rollback | stark |
| Python-Datenpipelines | Ingest, Normalisierung, Qualitätsprüfung, KEV-Zeitreihe | stark |
| KI-/MLOps-Betrieb | `eisen`: lokale Modelle, Router, On-Demand, GPU-Auslastung | stark, ungewöhnlich |
| Hochverfügbarkeit | Gates vor Rollout, Telemetrie alle 15 Minuten, Rollback | stark |
| Sicherheit / Härtung | Default-Deny, SOPS/age, SSH-CA, Minimalrechte | stark |
| Teamführung (disziplinarisch) | **keine** — Verantwortung als Gründer | **Lücke** |
| Beratungsumfeld, Kunden | Smart Energy 360, Mandantenberatung | vorhanden |
| Reisebereitschaft | zugesagt | erfüllt |

## Das Argument und die Lücke

Das Paket argumentiert Principal-Rolle als **Architektur, die andere benutzen können**: Gates, die unabhängig
vom Autor gelten, Selbstbedienung ohne Kenntnis des Aufbaus, Rollback als Entwurfsteil. Der KI-Teil ist
belegbar und selten: eine lokale Inferenz-Plattform mit Router, On-Demand-Start und Auslastungsschutz — für
einen Data-AI-Dienstleister die glaubwürdigere Geschichte als ein weiteres Kubernetes-Zertifikat.

Die Lücke steht im Brief: **keine disziplinarische Teamführung**. Der Brief dreht das nicht weg, sondern
trennt fachliche Führung (Standards, Gates) von Personalführung und macht die Unterscheidung zur Frage des
ersten Gesprächs.

## Gehalt

Ausgeschrieben ist **95.000 – 115.000 €**. Der Brief nennt **95.000 – 110.000 €** — im Band, mit Luft nach
oben für die Verhandlung und ohne die Obergrenze als Anspruch zu setzen. Die Zahl kommt aus dem Auftrag,
nicht aus einer Schätzung.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `chmod u+w *.pdf` vor dem Bau | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `Principal`, `eisen`, `95.000`, `110.000`, `Niederlassungserlaubnis` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 Lebenslauf | `bcb82bf0fb3a0b84295b0ce9a4c098b0033d93d841d88936758fad793a13fb20` |
| sha256 Anschreiben | `dbb90296adb3e1a10aab048034cbac487b9a440df0dcfbf3d19ebf64e9d3d21a` |
| Altlasten | `selection.json` und alte PDFs entfernt |

## Nächste Schritte

1. Über Join.com bewerben; Anschreiben und Lebenslauf anhängen.
2. Im Erstgespräch klären, ob die Rolle Architektur oder Teamführung meint.
3. Reiseanteil erfragen — Data-AI-Projekte sind häufig vor Ort beim Kunden.
