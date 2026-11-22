# Bewerbung — A3M Global Monitoring, Senior Linux DevOps Engineer

Stand: 22. November 2026
Fit: 4
Sprache: Deutsch
Status: migriert auf native Typst-Quellen, kompiliert und gemessen

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | A3M Global Monitoring GmbH |
| Rolle | Senior Linux DevOps Engineer (m/f/d) |
| Ort | Hamburg, Schopenstehl 20; Fernarbeit aus ganz Deutschland möglich |
| Anstellung | Vollzeit, 40 Stunden, unbefristet, Eintritt zum nächstmöglichen Termin |
| Produkt | Global Monitoring — Frühwarn-, Informations- und Kommunikationssysteme für Krisenmanagement |
| Team | klein, verteilt über Hamburg, Verona, London, Auckland |
| Quelle | a3mglobe.com, Anzeige im Paket |

## Migration

| Vorher | Nachher |
| :--- | :--- |
| `packet` → `/nix/store/2dg4dyqmc58ka0b89byspf6v907apbhp-…` (Symlink) | entfernt |
| `selection.json` (Modus 444, read-only) | entfernt |
| `lebenslauf.pdf`, `anschreiben.pdf` (Modus 444, read-only) | durch native Quellen ersetzt, beschreibbar |

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 37509 | 528 | `9e4e7c1f9673e7ac` |
| `anschreiben.pdf` | 1 | 24280 | 334 | `5041d65a6e177f02` |

## Fit-Map

| Anforderung der Anzeige | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| Administration, Wartung, Härtung der Linux-Landschaft | 13 Hosts, drei Hardware-Generationen, fünf Jahre allein | Stark |
| Erweiterung und Optimierung der Netzwerk-Infrastruktur | WireGuard zwischen Standorten, nftables, DNS, keine öffentlichen Verwaltungsdienste | Stark |
| Strategische Infrastruktur-Upgrades | Hardware-Auswahl, Aufbau, PXE-Installation, Übergabe in den Betrieb | Stark |
| Automatisierte Deployment- und Delivery-Prozesse | Gepinnte Eingaben, Gate vor dem Rollout, Rückrollung über Generationen | Stark |
| Monitoring, Alerting, Incident Response | Ledger alle 15 Minuten, Prüfungen von außen, Alarmbrücke mit Zustellbestätigung, Vorfallroutine | **Stärkster Nachweis** |
| ISO-27001-konforme Betriebsführung | Sicherheitspraxis vorhanden, Audit und Nachweisführung nicht | **Lücke** |
| Studium oder vergleichbare Erfahrung | M.Sc. Freiburg, fünf Jahre Betrieb | Erfüllt |
| Verteiltes internationales Team | Fernbetrieb ja, Zeitzonen-Team nein | **Teilweise** |
| Deutsch, Englisch | C1, Muttersprache | Erfüllt |

## Fit-Begründung: 4

Das Produkt ist ein Frühwarnsystem, und der stärkste Nachweis im Paket ist genau das: Alarmierung, die erst als gemeldet gilt, wenn die Zustellung bestätigt ist. Dazu Härtung, Netz und Automatisierung aus eigenem Betrieb.

Keine 5, weil ISO 27001 und der verteilte Teamkontext fehlen; keine 3, weil die Technik vollständig belegt ist.

## Offene Punkte

1. **ISO 27001** als Lücke im Anschreiben benannt.
2. **Cloud, Kubernetes, Container-Orchestrierung** nicht vorhanden, im Anschreiben benannt.
3. **Zeugnisse** fehlen.
4. Hamburg-Präsenz möglich, aber nicht zugesagt — Fernarbeit ist laut Anzeige ausdrücklich möglich.
