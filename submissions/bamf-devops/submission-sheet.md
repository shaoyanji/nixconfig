# Bundesamt für Migration und Flüchtlinge — DevOps-Engineers (m/w/d), Public Cloud / Plattformdienste

Interamt `1513998`, Kennziffer **BAMF-2025-358**, Referat 22B. Quellen sind jetzt **native Typst-Dateien**;
der JSON-Build und der `packet`-Symlink in den Nix-Store sind entfernt. Stand: Paket fertig, **nichts
eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `bamf-devops` |
| Arbeitgeber | Bundesamt für Migration und Flüchtlinge (BAMF), Nürnberg |
| Rolle | DevOps-Engineers (m/w/d), Public Cloud / Plattformdienste |
| Kennziffer | BAMF-2025-358 |
| Ort | Nürnberg, hybrid |
| Sprache | Deutsch |
| Vergütung | TVöD Bund; Erwartung **E 11 / E 12**, keine Euro-Zahl im Brief |
| Fit | 3 (DB-Eintrag 4 wie beauftragt) |

## Fit-Map

| Anforderung (Stelle) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Linux-Plattformbetrieb | Dreizehn Hosts deklarativ, Gates, Rollback, Rebuild | stark |
| Betriebliche Automatisierung | Go, Python, Bash hinter einer Task-Oberfläche | stark |
| Reproduzierbare Systemkonfigurationen | Gepinnte Inputs, deklarierter Zustand, Rebuild als Pfad | stark |
| Virtualisierung | MicroVMs als deklarierte Gäste, systemd-Slices, PXE-Provisionierung | stark im Betrieb, ohne Hypervisor-Administration |
| Container / Orchestrierung | Container nur als gepinnte Bauumgebungen | **Lücke** |
| Public Cloud (Plattformdienste) | Oracle-Hosts, ein Lambda-Projekt | **Lücke** |
| Developer Enablement | Task-Oberfläche, Runbooks, Selbstbedienung ohne Plattformbesitzer | stark |
| Nachvollziehbarkeit / Dokumentation | Runbooks, Dokumentations-Budget, Sprach-Gate, Ledger | stark |
| Sicherheitsüberprüfung SÜ1 | kein Hindernis, ausdrücklich zugesagt | erfüllt |
| Hybrid Nürnberg | ~350 km; Präsenz zugesagt, Tage zu klären | offen, nicht ablehnend |

## Zu den Begriffen im Auftrag

Der Auftrag nennt "containerized platform engineering (Referat 22B)". Container-Orchestrierung ist im Profil
**nicht** vorhanden und steht deshalb im Anschreiben als Lücke, nicht in der Überschrift. Was belegbar ist:
Virtualisierung im Betrieb (MicroVMs, Slices, PXE), Automatisierung und Reproduzierbarkeit.

## Vergütung

Öffentlicher Dienst: keine Spanne in der Anzeige, deshalb keine Euro-Forderung. Der Brief nennt die
Erwartung **E 11 / E 12** nach TVöD Bund und überlässt die Einordnung dem Arbeitgeber. Die im Lead notierte
Angabe "E 10 – E 12" stammt aus dem Interamt-Eintrag, nicht aus dem ausgeschriebenen Text; die Erwartung im
Brief ist deshalb bewusst als Wunsch formuliert.

## Fristen und offene Punkte

- Ein Bewerbungsschluss **18.12.2026** steht nur im Lead, nicht in der Anzeige — vor dem Absenden prüfen.
- Präsenztage in Nürnberg früh klären; 350 km sind mit Hybrid machbar, mit täglicher Präsenz nicht.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 234 prose files, exit 0 |
| sha256 Lebenslauf | `825d92a39de10737305ad675d3ced1056e315afedc5598b6b2a5b0ecf249ca79` |
| sha256 Anschreiben | `59ce6753e66702d85c533de1622c5ebff90f51638973e6c2fa49e5ea5f794b0f` |
| Altlasten | `packet`-Symlink, `lebenslauf.json`, `letter.json`, `selection.json` entfernt |

## Nächste Schritte

1. Frist auf Interamt prüfen, dann über den Interamt-Link bewerben (Kennziffer nennen).
2. Präsenztage und Eingruppierung im ersten Kontakt klären.
3. SÜ1-Unterlagen bereithalten; die Bereitschaft steht im Lebenslauf.
