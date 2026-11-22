# Bewerbung T-Systems — Site Reliability Engineer (SRE) (m/w/d)

Stand: 22. November 2026
Fit: 4 / 5
Kennziffer: 12444-563465374109756-DT-S

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Deutsche Telekom AG / T-Systems International GmbH |
| Rolle | Site Reliability Engineer (SRE) (m/w/d) |
| Arbeitsorte | Kassel, Bielefeld, München, Berlin, **Karlsruhe**, Hannover, Dresden, Magdeburg, Saarbrücken, Darmstadt |
| Modell | Vollzeit, Teilzeit möglich, hybrid mit mobilem Arbeiten, Start ab sofort |
| Entgelt | keine Bandbreite genannt |
| Fachkontakt | thomas.arbeit@t-systems.com |
| Weg | Bewerbung über das Telekom-/T-Systems-Portal mit der Kennziffer |

## Schwerpunkt der Stelle

Monitoring- und Observability-Stack auf Basis von Prometheus, Grafana, Loki und AlertManager für verteilte Fog- und Edge-Infrastrukturen; Alerting für autonome Betriebsmodelle, Disconnected- und Air-Gap-Szenarien; lokale Retention, Log-Rotation und Datenmanagement unter knappen CPU-, Speicher- und Storage-Ressourcen; Kubernetes-Monitoring; Infrastructure as Code mit YAML.

## Dokumente

| Dokument | Datei | Hinweis |
| :--- | :--- | :--- |
| Anschreiben | `anschreiben.pdf` | Eine Seite, deutsch, an Herrn Arbeit |
| Lebenslauf | `lebenslauf.pdf` | Zwei Seiten, deutsch |
| Quellen | `lebenslauf.typ`, `anschreiben.typ` | Typst, direkt kompilierbar |
| Zeugnisse | keine Datei | Im Portal üblich, muss ergänzt werden |

## Abgleich

| Anforderung | Nachweis | Einschätzung |
| :--- | :--- | :--- |
| Prometheus, PromQL, Federation, Remote Write, lokale Retention | Eigenes JSONL-Ledger mit 15-Minuten-Takt und Rotation | **Lücke**, anderes Werkzeug |
| Grafana, Dashboards, Provisioning as Code | Keine Dashboards; Auswertung über Skripte und Ledger | **Lücke** |
| Loki, LogQL, Compaction | Logs liegen auf den Hosts, keine zentrale Log-Plattform | **Lücke** |
| AlertManager, Routing, Inhibition, Eskalation | Eigene Go-Bridge mit Zustellbestätigung, keine Routing-Sprache | Teilweise, Konzept ja |
| Kubernetes-Monitoring | Kein Kubernetes | **Lücke** |
| Ressourcenbeschränkte Umgebungen, CPU/Memory/Storage optimieren | Sieben Jahre Betrieb auf eigener Hardware mit Limits und Speicherdruck | Stark |
| Offline-, Air-Gap-, Disconnected-Betrieb | Betrieb ausschließlich über WireGuard-Tailnet, keine öffentliche Schnittstelle | Stark im Denken, nicht im Szenario erprobt |
| YAML | Konfiguration ist Nix, nicht YAML | **Lücke** |
| IT-Sicherheit, Security Awareness | sops/age, eigene Zertifizierungsstelle, kurzlebige Zertifikate, nftables | Stark |
| SRE- oder Infrastrukturbetrieb | Fünf Jahre eigene Flotte, zehn Jahre Betrieb insgesamt | Stark |
| Deutsch C1 | C1, Studium und Arbeit in Freiburg auf Deutsch | Erfüllt |
| Terraform, Ansible, GitOps, OpenTelemetry (Nice-to-have) | Nicht vorhanden | Lücke, nicht gefordert |
| Linux-Systemadministration (Nice-to-have) | Kern der eigenen Arbeit | Übertrifft |

## Fit-Begründung: 4 von 5

Die Vorgabe nannte 5. Das ist nach Prüfung der Must-Have-Liste nicht zu halten, und eine Fünf im Datensatz, während das Anschreiben fünf Lücken einräumt, wäre intern widersprüchlich. Deshalb 4.

Vier, weil die Substanz dieser Rolle vorhanden ist: Telemetrie unter Knappheit bauen, Alarme bis zur Zustellung verfolgen, Retention begrenzen, Störungen aus Daten diagnostizieren, unter Ressourcenlimits betreiben, ohne öffentliche Angriffsfläche. Die Anzeige beschreibt genau diese Probleme, nur mit anderen Produkten.

Nicht fünf, weil fünf der Must-Haves vollständig fehlen: Prometheus samt PromQL, Grafana samt Provisioning, Loki samt LogQL, AlertManager und Kubernetes. Das ist der Werkzeugkasten, mit dem die Stelle täglich arbeitet.

## Offene Punkte

1. **Fit auf 4 korrigiert** (Vorgabe: 5). Begründung oben; die Bewertung im Datensatz folgt dem.
2. Zeugnisse fehlen.
3. Prometheus-, Grafana-, Loki-, AlertManager- und Kubernetes-Lücke steht im Anschreiben; nicht überspielen.
4. Standort Karlsruhe wählen. Von Gutach im Breisgau rund anderthalb Stunden; die anderen Standorte sind deutlich weiter.
5. Keine Gehaltszahl nennen; keine Bandbreite in der Anzeige.
6. Ansprechpartner per E-Mail prüfen, ob eine Bewerbung direkt gewünscht ist oder ausschließlich über das Portal.

## Paket

| Datei | Inhalt |
| :--- | :--- |
| `job-description.txt` | Anzeige mit Aufgaben, Must-Haves, Nice-to-Haves und Standorten. |
| `lead.md` | Fit, Lücken, Standort, Weg, Gehalt. |
| `lebenslauf.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `anschreiben.typ` | Typst-Quelle, eigenständig kompilierbar. |
| `lebenslauf.pdf` | Zwei Seiten. |
| `anschreiben.pdf` | Eine Seite. |
| `submission-sheet.md` | Diese Übersicht. |
