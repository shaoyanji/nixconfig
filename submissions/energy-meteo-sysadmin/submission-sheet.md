# energy & meteo systems GmbH — Systemadministrator:in

BA-Vermittlung `13644-311398-S` über get-in-it. Quellen sind jetzt **native Typst-Dateien**; der frühere
JSON-Build und der `packet`-Symlink in den Nix-Store sind entfernt. Stand: Paket fertig, **nichts
eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `energy-meteo-sysadmin` |
| Arbeitgeber | energy & meteo systems GmbH, Oldenburg (Wind- und Solarprognosen) |
| Rolle | Systemadministrator:in |
| Ort | Oldenburg, **Home-Office möglich** |
| Sprache | Deutsch |
| Gehalt | 68.000 EUR gefordert (Band im Datenbankeintrag: 65.000 – 72.000) |
| Fit | 4 |

## Fit-Map

| Anforderung (Anzeige) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Linux-Systeme bestens kennen | NixOS-Flotte, systemd, cgroups/PSI, journald, tcpdump, Rebuild-Pfad | stark |
| 1st/2nd-Level-Support, Fehleranalyse | Direkte Betreuung von Feldtechnikern und Büro bei O3, Einweisung statt Ticketweiterleitung | stark im kleinen Rahmen, kein Ticket-Helpdesk |
| Skriptsprachen wie Python | Python-, Go- und Bash-Werkzeuge hinter einer Task-Oberfläche | stark |
| IT-Sicherheit bei Installation von Hard- und Software | Patch- und Update-Tests vor Rollout, Default-Deny, SOPS/age, Minimalrechte | stark |
| Hardware-Lifecycle, Software-Rollouts | PXE/iVentoy-Provisionierung bis Außerbetriebnahme; Rollouts auf Clients bei O3 | stark |
| Monitoring der IT-Systemlandschaft | Ledger alle 15 Minuten, Alerting auf Zustand ungleich ok, Log-Analyse | stark |
| IT-Dokumentation, Wissen transparent | Runbooks, Änderungen mit Rückweg, Dokumentations-Budget und Sprach-Gate | stark |
| Ausbildung Fachinformatiker:in oder Informatikstudium | Kein Fachinformatiker; M.Sc. mit IT-Praxis, kein Informatikstudium | **Lücke, formal** |
| Energiedomäne | M.Sc. Erneuerbare Energien (1,8), Fraunhofer ISE, 10 MW PV | stark |

## Ehrliche Einordnung

Der Formfehler ist die Qualifikation: Die Anzeige nennt Fachinformatiker:in Systemintegration oder ein
Informatikstudium. Vorhanden ist ein M.Sc. Erneuerbare-Energien-Management mit zehn Jahren Betriebspraxis —
fachlich näher an Wind- und Solarprognosen als die meisten IT-Absolventen, formal aber nicht dieselbe
Zeile. Das Anschreiben sagt das im vierten Absatz.

Zweite Einordnung: Die Rolle ist zu großen Teilen 1st/2nd-Level-Support für Laptops, Drucker und Telefone —
unter dem Niveau der bisherigen Platform-Pakete. Der Grund, sie trotzdem zu bauen, ist die Domäne: Wer
Prognosen für Wind und Sonne liefert, braucht jemanden, der die Daten und die Systeme dahinter versteht.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 234 prose files, exit 0 |
| sha256 Lebenslauf | `83f979767892ea9eabba489fd0b6234d0b67df8f4788f9b1ccf5442908f931fc` |
| sha256 Anschreiben | `e56735d4ca9907e74af9d2ae5136ee4652170fb76692ce315e015284ab490424` |
| Altlasten | `packet`-Symlink und JSON-Build entfernt |

## Nächste Schritte

1. Präsenztage in Oldenburg klären, bevor beworben wird — von Gutach sind es rund 700 km.
2. Über get-in-it bewerben und die Referenz 13644-311398-S nennen.
3. Im Gespräch die formale Qualifikation offen ansprechen und auf die Domänen- und Betriebserfahrung setzen.
