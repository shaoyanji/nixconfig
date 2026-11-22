# Deutsche Rentenversicherung Bund — DevOps Platform Engineer OpenShift (m/w/div)

Interamt **1511057**, TechnoCampus Spandau, hybrid. Native Typst-Quellen. Stand: Paket fertig,
**nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `drv-devops-platform-openshift` |
| Arbeitgeber | Deutsche Rentenversicherung Bund |
| Rolle | DevOps Platform Engineer OpenShift (m/w/div) |
| Interamt | 1511057 |
| Ort | Berlin, TechnoCampus Spandau — hybrid |
| Vergütung | **TVöD Bund E 11**, unbefristet |
| Sprache | Deutsch |
| Fit | 3 (DB-Eintrag 4 wie beauftragt) |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| OpenShift / Kubernetes betreiben | **nicht produktiv administriert** | **Lücke** |
| Plattform-Engineering | Deklarierte Hosts, Gates, Rollback, Rebuild | stark |
| DevEx / Selbstbedienung | Task-Oberfläche, Runbooks, Verträge für Dritte | stark |
| Deklarative Infrastruktur | Flake mit gepinnten Inputs, reproduzierbarer Zustand | stark |
| Container-Automatisierung | Container als gepinnte Bauumgebungen; MicroVMs, Slices | teilweise |
| Linux und Netzwerk | nftables, WireGuard, CA, TLS, Fehlersuche | stark |
| Betrieb und Monitoring | Ledger alle 15 Minuten, Alerting, Incident-Analyse | stark |
| Lokale souveräne KI | `eisen`: lokale Modelle, Router, On-Demand, Auslastungsschutz | stark, ungewöhnlich |
| Präsenz Spandau | ~700 km; Präsenzblöcke zugesagt, Pendeln nicht | offen, nicht ablehnend |

## Warum `eisen` im Lebenslauf steht

Der Auftrag nennt "local sovereign LLM infrastructure (eisen stack)" als Hervorhebung. Das ist belegbar:
die Maschine betreibt lokale Modelle hinter einem Router, mit On-Demand-Start und einem Schutz, der
schwere Jobs gegen interaktive Anfragen abwägt. Für eine Behörde ist der Punkt nicht Technikfolklore,
sondern Datenhoheit — nichts verlässt das Haus. Deshalb steht es als eigenes Projekt und im Brief, aber als
das, was es ist: eine Inferenz-Plattform, keine Container-Orchestrierung.

## Was der Brief nicht behauptet

OpenShift und Kubernetes stehen im Brief als Lücke, nicht als Erfahrung. Die Stelle trägt den Begriff im
Titel; eine Bewerbung, die hier blufft, fällt im ersten Fachgespräch durch. Der Brief bietet stattdessen
die Schicht darunter (Linux, Netzwerk, Zertifikate, Gates) und die Arbeitsweise darüber (Selbstbedienung,
Nachvollziehbarkeit) und benennt die Bereitschaft, die Lücke mit Zertifizierung zu schließen.

## Vergütung

**E 11 TVöD Bund** ist ausgeschrieben — deshalb steht die Eingruppierung im Brief und keine Euro-Zahl. Eine
Forderung über der ausgeschriebenen Gruppe wäre gegenstandslos, eine darunter ein Eigentor.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `chmod u+w *.pdf` vor dem Bau | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `OpenShift`, `eisen`, `1511057`, `E 11`, `700 Kilometer` |
| `task checks:prose` | 238 prose files, exit 0 |
| sha256 Lebenslauf | `2352442d68c3d27442d94fd6203bd55c9f3291f5a6ed7a88f9a1c811e0a14e20` |
| sha256 Anschreiben | `c06a19f51b75f4bb99cd3540a84e5f5cdbc458f462d22f49ae632c06ce94bfe1` |

## Nächste Schritte

1. Über Interamt mit ID **1511057** bewerben; Anschreiben und Lebenslauf anhängen.
2. Präsenztage klären, bevor ein Vorstellungsgespräch in Berlin vereinbart wird.
3. Im Gespräch offen fragen, wie viel der Rolle Cluster-Betrieb ist und ob eine Zertifizierung im ersten
   Jahr vorgesehen ist.
