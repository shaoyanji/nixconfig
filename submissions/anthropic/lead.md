# Lead: Anthropic — Staff+ Software Engineer, Data Infrastructure

Fit: 2
Stand: 22.11.2026
Ort: Remote-friendly mit Reise, San Francisco / Seattle / New York — Präsenz in den USA erwartet
Greenhouse-Req: 5114768008
Sprache: Englisch

## Quellenlage

Verzeichnis und Datensatz waren nicht vorhanden; keine `selection.json` und keine alten nix-gebauten PDFs zu entfernen. Die Anzeige liegt vollständig im Paket (HTTP 200 am 22.11.2026). Anthropic beschreibt die Rolle als Ingenieursarbeit an Datenverarbeitung, Speicherung und Zugriff: von Finanzberichts-Pipelines über Zugriffskontrollsysteme bis zur Zuverlässigkeit von Cloud-Speicher, mit Spark und verteilten Datenverarbeitungssystemen im Profil.

## Warum überhaupt eingereicht wird

Weil die Nachbarschaft echt ist: Telemetrie-Pipelines, Speicherbetrieb, Zugriffskontrolle und Audit-Spuren sind gebaut und betrieben worden — nur in Kleinformat und ohne verteilte Datenverarbeitung. Wer eine Flotte allein betreiben musste, versteht die Fehlerbilder, die eine Datenplattform nachts zeigt.

## Was passt

- Telemetrie als Pipeline: JSONL-Ledger alle 15 Minuten, Auswertung in Python und Go, Zustellbestätigung für Alarme.
- Speicherbetrieb: Kapazität aus gemessenem Druck, NAS-Ziele, geprüfte Wiederherstellungen statt gezählter Sicherungsläufe.
- Zugriff und Audit: eigene SSH-CA mit kurzlebigen Zertifikaten, sops/age je Host, nachvollziehbare Git-Historie.
- Linux-Performance unter Last: PSI, OOM, Disk-Druck, cgroups und Namespaces.
- Reproduzierbarkeit: hermetische Builds aus gepinnten Inputs, Rollback über Generationen.
- Sicherheitshaltung: keine öffentlichen Listener, WireGuard-Mesh, nftables am Rand.
- Englisch Muttersprache, Deutsch C1.

## Was fehlt

- **Spark und verteilte Datenverarbeitung** — nicht vorhanden.
- **Petabyte-Maßstab** — die Flotte umfasst 13 Hosts.
- **Cloud-Speicherdienste** — eigene Hardware statt S3, GCS oder verwalteter Speicher.
- **Staff+-Reichweite** — keine teamübergreifende technische Führung.
- **Datenplattform-Produktarbeit** — keine Pipelines für Finanzberichte oder Zugriffssysteme für Organisationen.
- **US-Präsenz** — Wohnsitz Deutschland, Rolle mit Reise und Standortbezug in den USA.

## Weg

Greenhouse-Bewerbung über Req 5114768008. Ohne US-Präsenz und ohne verteilte Datenverarbeitung ist das ein Langschuss.

## Gehalt

Keine Zahl im Anschreiben; die Anzeige nennt keine.

## Fit-Begründung: 2 von 5, nicht 4

Der Auftrag nennt 4. Zwei ist die belastbare Zahl: gesucht wird eine Staff+-Ingenieursrolle für verteilte Datenverarbeitung im Petabyte-Maßstab, und der Nachweis besteht aus Ein-Host-Plattformarbeit mit Telemetrie. Die Übertragung ist konzeptionell, nicht direkt.

Zwei heißt: Das Paket ist ehrlich, die Nachbarschaft ist sichtbar, und ein Treffer ist unwahrscheinlich.
