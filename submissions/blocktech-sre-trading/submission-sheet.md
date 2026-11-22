# BlockTech — Senior Site Reliability Engineer, Trading Infrastructure (Python/Linux)

Arbeitnow-NL-Inserat, gefunden im Scouting-Lauf 2026-11-22. Paket am selben Tag gebaut, **nichts
eingereicht**. Eigenständige Typst-Quellen neben den PDFs.

| Feld | Wert |
| :--- | :--- |
| Role ID | `blocktech-sre-trading` |
| Arbeitgeber | BlockTech (algorithmischer Handel mit Optionen und Derivaten, Betrieb rund um die Uhr) |
| Rolle | Senior Site Reliability Engineer, Trading Infrastructure |
| Ort | **Amsterdam, hybrid** |
| Sprache | Englisch |
| Gehalt | keine Bandbreite veröffentlicht; im Gespräch erfragen |
| Fit | **3** (DB-Eintrag 4, wie beauftragt) |

## Die zwei Achsen dieser Stelle

Handelsysteme und Bare-Metal-Linux treffen selten in einer Anzeige zusammen. Beide Achsen sind im Profil
belegt, aber unterschiedlich tief:

| Achse | Nachweis | Tiefe |
| :--- | :--- | :--- |
| Derivate und Risiko | Options-/Hedging-Algorithmus auf Wetterderivaten, als intern Risk Manager gefahren; Volatilitätsmodelle auf Langzeitreihen | fachlich stark, Marktumfeld anders |
| Bare-Metal-Betrieb | Dreizehn Linux-Hosts über PXE/iVentoy provisioniert, deklarativ verwaltet, Rebuild-Pfad | stark |
| 24/7-Zuverlässigkeit | Ledger alle 15 Minuten, Page auf jeden Zustand ungleich ok, Incident-Notizen im Repo | stark im Maßstab einer Flotte |
| Latenz und Kernel | cgroups, PSI, systemd-Slice-Limits, tcpdump für MTU/Path; **kein Kernel-Tuning, keine Colocation** | **Lücke** |
| Python | Go-, Python- und Bash-Werkzeuge hinter einer Task-Oberfläche | stark |
| Rust | **nicht vorhanden** | **Lücke** |

## Trading-System-Abgleich

| Anforderung (Anzeige) | Nachweis | Urteil |
| :--- | :--- | :--- |
| SRE für ein 24/7-Handelssystem | Betriebsdisziplin, Rollback, Gate, Ledger | Muster passt, Domäne nicht identisch |
| Bare-Metal-Linux-Flotte | Provisionierung, Erstkonfiguration, Rebuild, kein Hypervisor dazwischen | stark |
| Low-Latency-Netzwerk | WireGuard, nftables, DNS, MTU-Analyse; keine Kernel-Bypass- oder Colocation-Erfahrung | teilweise |
| Python-Automatisierung | Werkzeuge, Dienste, Pipelines | stark |
| Rust | nicht vorhanden | Lücke |
| Quantitative Risikofunktion | Hedging-Entscheidungen mit echtem Geld, Modellierung der Volatilität | stark, anderer Markt |
| Incident Response | Ursache und Behebung dokumentiert, Pages auf Zustandswechsel | stark |

## Bewertung

Der Derivate-Hintergrund ist der Grund, warum diese Bewerbung überhaupt sinnvoll ist: Wer Optionen auf
Wetter gepreist und gehedgt hat, versteht, warum ein System um drei Uhr nachts richtig liegen muss. Die
Betriebsseite ist ebenfalls echt — Bare Metal, Deklaration, Gates, Telemetrie. Was fehlt, ist die
Latenz-Kultur: Colocation, Kernel-Tuning, Rust. Fit **3**, nicht 4.

Das Anschreiben sagt das im vierten Absatz in einem Satz ("If the role needs someone to walk into the cage
on day one and shave a hundred microseconds, that is not me yet") und stellt den Temperaments-Teil
dagegen: jede Änderung umkehrbar, Telemetrie als Hauptartefakt, Incidents werden aufgeschrieben.

## Standort

Amsterdam hybrid, von Freiburg rund 700 km — ein Umzug, kein Pendelarrangement. Das Anschreiben sagt das
offen; für eine Senior-Rolle mit 24/7-Betrieb ist Präsenz in Amsterdam ohnehin die realistische Annahme.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 232 prose files, exit 0 |
| sha256 Lebenslauf | `6f672dec6ae448b99280b79af57ac0bcade4931e6bb0cc18941c5d28ad66022c` |
| sha256 Anschreiben | `48f3cd532586ddede2e7a044fae56cbcdc47dadf2a887c4423c3d3824ca0c99a` |

## Nächste Schritte

1. Über den Arbeitnow-Link bewerben; Derivate-Story zuerst, Latenz-Lücke offen.
2. Umzugsentscheidung vor dem Gespräch klären — Amsterdam hybrid heißt Präsenz, nicht Pendeln.
3. Bandbreite erfragen; die Anzeige nennt keine Zahl.
