# Bundesdruckerei Gruppe GmbH — Site Reliability Engineer (m/w/d)

BA-Referenz `15933-0067012870-S`. Quellen sind jetzt **native Typst-Dateien**; der JSON-Build und der
`packet`-Symlink in den Nix-Store sind entfernt. Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `bundesdruckerei-sre` |
| Arbeitgeber | Bundesdruckerei Gruppe GmbH, Berlin |
| Rolle | Site Reliability Engineer (m/w/d) |
| Ort | Berlin — Umzug, kein Pendeln; Schicht und Rufbereitschaft Teil der Rolle |
| Sprache | Deutsch (C1) |
| Gehalt | keine Spanne veröffentlicht → **Entgeltgruppe erfragen**, keine Euro-Zahl im Brief |
| Fit | 3 (DB-Eintrag 4 wie beauftragt) |

## Fit-Map

| Anforderung (Anzeige) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Souveräner, sicherer Linux-Betrieb | Deklarierte Flotte, Gates, Rollback, Default-Deny, kurzlebige Zertifikate | stark |
| Reproduzierbare Systeme | Gepinnte Inputs, Rebuild-Pfad, deklarierter Zustand statt Handarbeit | stark |
| Automatisierte CI/CD-Validierung | Identisches Modul-Gate in CI und Host; kein Ausrollen ohne Check | stark im Muster, keine eigene CI-Plattform |
| SLOs und Zuverlässigkeitsmetriken | Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok, Incident-Notizen | Messung stark, **Governance nicht geführt** |
| Container-Isolation | MicroVMs als deklarierte Gäste, systemd-Slices; **keine Container-Orchestrierung** | teilweise |
| Container-Registry | nicht administriert | **Lücke** |
| Bereitschaft, Schicht | ausdrücklich zugesagt | erfüllt |
| Sicherheitsüberprüfung | kein Hindernis; Niederlassungserlaubnis vorhanden | erfüllt |

## Zu den Begriffen im Auftrag

Der Auftrag nennt "container runtime isolation" und "SLOs and reliability metrics". Beides steht im
Lebenslauf nur in der Form, die belegbar ist: Isolation über MicroVMs und systemd-Slices, Zuverlässigkeit
über ein Ledger. Container-Orchestrierung und eine formale Fehlerbudget-Steuerung stehen als Lücke im
Anschreiben — nicht als Überschrift.

## Gehalt

Öffentlichkeitsnaher Arbeitgeber ohne veröffentlichte Spanne: Der Brief fragt nach der Entgeltgruppe, statt
eine Zahl zu erfinden. Eine Euro-Forderung wäre hier gegen den Tarif geraten und würde die Einordnung
erschweren.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 234 prose files, exit 0 |
| sha256 Lebenslauf | `77b10a84e074d8773b9fde270ffef8ae2756e153897c9c9139bdf9eb166f9242` |
| sha256 Anschreiben | `c87209317befbfe6d72bf6e8f0c7337d66862f924faa4f7577dd94629c53012a` |
| Altlasten | `packet`-Symlink, `lebenslauf.json`, `letter.json`, `selection.json` entfernt |

## Nächste Schritte

1. Über die BA-Anzeige bewerben und die Referenz 15933-0067012870-S nennen (im Brief: 15933-0067012870-S).
2. Entgeltgruppe erfragen.
3. Umzugsentscheidung vor dem Gespräch treffen — Schicht plus Rufbereitschaft schließt Pendeln aus.
