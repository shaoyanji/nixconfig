# Mittwald CM Service GmbH & Co. KG — DevOps Engineer (m/w/d)

BA-Referenz `17338-f04a2b59e269f0c21e-S`; vollständige Anzeige von
`mittwald.de/karriere/job/devops-engineer-2729390`. Quellen sind jetzt **native Typst-Dateien**; der
JSON-Build und der `packet`-Symlink in den Nix-Store sind entfernt. Stand: Paket fertig, **nichts
eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `mittwald-devops` |
| Arbeitgeber | Mittwald CM Service GmbH & Co. KG, Espelkamp bei Minden |
| Rolle | DevOps Engineer (m/w/d), neue Plattform-Teams |
| Stack | Go, Linux, Kubernetes, Helm (Kubernetes auf Bare Metal) |
| Vertrag | Vollzeit, unbefristet, Start **04.01.2027**, viermonatiges Onboarding |
| Band | 45.000 – 60.000 EUR/Jahr |
| Ask | 58.000 – 62.000 EUR |
| Fit | 3 |

## Fit-Map

| Anforderung (Anzeige) | Nachweis | Urteil |
| :--- | :--- | :--- |
| Systemumgebung der Webhosting-Produkte gestalten und betreiben | Dreizehn Linux-Hosts, nginx mit TLS, Provisionierung über PXE, Rebuild | stark im kleinen Maßstab |
| Kubernetes-basierte Plattform weiterentwickeln | **Keine Cluster-Erfahrung**; MicroVMs als deklarierte Gäste | **Lücke** |
| Kubernetes-Operatoren, Bare-Metal-Deployments | Nicht vorhanden; Bare-Metal-Provisionierung und Rebuild-Pfad dagegen vorhanden | **Lücke**, Nachbarschaft real |
| Automatisierungen, die tausende Instanzen stabil halten | Deklaration, Gate in CI und Host, Rollback-Zeiger, Task-Schnittstelle | stark im Muster |
| Go, Linux, Kubernetes, Helm (Onboarding-Stack) | Go und Linux stark; Kubernetes und Helm sind der Lernanteil | 2 von 4 |
| Betrieb, Störungsanalyse, Telemetrie | Ledger, journald, cgroups/PSI, tcpdump | stark |
| Caching | Build-Cache und Store-Substitution, HTTP-Caching vor Web-Diensten | stark |
| Deutsch | Anschreiben und Unterlagen auf Deutsch, C1 | stark |

## Zu den Werkzeugen im Auftrag

Der Auftrag nennt "Kubernetes platform operations" und "Prometheus/Grafana telemetry" als Hervorhebung.
Beides ist im Profil **nicht** vorhanden: Kubernetes ist der Lernanteil, den Mittwald selbst zusagt, und die
Telemetrie ist ein eigenes Ledger statt Prometheus/Grafana. Beides steht so im Anschreiben und im Sheet,
statt in die Überschrift zu wandern und im ersten Gespräch zu zerfallen.

## Gehalt

Die Bandbreite endet bei 60.000; die Forderung von 58.000 bis 62.000 liegt am oberen Rand und mit dem
Höchstwert darüber. Das Anschreiben sagt das offen und bittet um Einordnung am oberen Ende. Realistisch ist
ein Abschluss bei 58.000 bis 60.000.

## Bewerbungsverfahren

Mittwald schreibt ausdrücklich, dass kein perfekt polierter Lebenslauf erwartet wird, sondern Antworten auf
einige Fragen; danach folgt eine kleine Aufgabe zu Hause. Das Paket ist **Belegmaterial**: erst die Fragen
beantworten, dann CV und Anschreiben anhängen, die Aufgabe als eigentliche Prüfung einplanen.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 234 prose files, exit 0 |
| sha256 Lebenslauf | `e967e6423862b59713f4253e17480f1ed6853064af8bce64a30377063caa5959` |
| sha256 Anschreiben | `b0e09f577695870a02808304b431a8114b1ab510d56d0313d6caa8b2500a2f73` |
| Altlasten | `packet`-Symlink, `lebenslauf.json`, `letter.json`, `selection.json` entfernt |

## Nächste Schritte

1. Bewerbungsfragen auf der Mittwald-Seite beantworten — sie sind der erste Filter, nicht der CV.
2. Aufgabe zu Hause einplanen; sie entscheidet vermutlich mehr als das Anschreiben.
3. Hybrid oder remote klären, bevor die 700 km zum Thema werden.
