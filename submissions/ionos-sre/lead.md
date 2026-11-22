# Lead: IONOS SE — Site Reliability Engineer (f/m/d)

Fit: 4 (auf der Werkzeugachse eher 3)
Stand: 22.11.2026
Ort: Karlsruhe, Hinterm Hauptbahnhof 3-5
Kennziffer: 1585

## Warum interessant

IONOS ist Europas größter Hosting-Anbieter und positioniert sich als souveräne Cloud für Europa, mit über 6,2 Millionen Kunden und einer Infrastruktur, die von GPU-Clustern bis zu KI-Automatisierung reicht. Die Stelle sitzt im Application Hosting Team und bildet das technische Rückgrat der Produktplattform: Managed Nextcloud, Nextcloud Workspace, IONOS GPT und weitere Web Services auf einer Kubernetes-Plattform.

Zwei Dinge passen genuinely: Der Betrieb läuft auf Linux, containerisiert, unter Last und mit Verfügbarkeitsversprechen; und die eigene Arbeit umfasst eine autarke KI-Plattform auf eigener Hardware mit Modellserver und Go-Router. Wer IONOS GPT mitbetreibt, betreibt genau die Klasse von Dienst, die hier seit drei Jahren im Keller läuft — nur in klein.

Karlsruhe ist von Gutach im Breisgau rund anderthalb Stunden entfernt, hybrides Arbeiten ist zugesagt. Das ist der nächste der drei genannten Standorte und der Grund, warum die Bewerbung sinnvoll ist.

## Was passt

- Linux-Betrieb über dreizehn Hosts und drei Hardware-Generationen, inklusive Beschaffung, Installation und Inbetriebnahme.
- Deklarative Infrastruktur: jeder Dienst ein Modul, jeder Host eine Feature-Liste, jede Änderung ein Commit mit Gate und Rückrollung.
- Automatisierung mit Shell, Python und Go; CI-Gate identisch mit dem Ausrollgate.
- Telemetrie im Betrieb: Sentinel-Ledger alle 15 Minuten mit Jobstatus, Generation-Alter, Disk- und PSI-Druck, Gatus-Prüfungen, Alarmzustellung mit Bestätigung.
- Störungsdiagnose aus Daten statt aus Vermutungen; Runbooks als Ergebnis.
- Sicherheit: sops und age, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, nftables, keine offene Schnittstelle.
- Betrieb einer KI-Plattform auf eigener Hardware: Modellserver, Go-Router, Zugang nur über das Tailnet.
- Ressourcenknappheit als常态: Limits je Dienst, Speicherdruck als Messgröße.

## Was fehlt

- Kubernetes im Betrieb; die Anzeige nennt es als Kern der Infrastruktur.
- Terraform und ArgoCD; die eigene Automatisierung ist Nix plus Git.
- GitLab CI/CD als Plattform.
- Prometheus, Grafana und ELK-Stack.
- Betrieb im Maßstab eines Hosting-Anbieters mit SLA und 6,2 Millionen Kunden.
- Nextcloud- oder SaaS-Produktbetrieb.

## Weg

Bewerbung über Greenhouse (Kennziffer 1585): https://job-boards.eu.greenhouse.io/ionos/jobs/4956674101. Keine Frist genannt. Hybrides Modell, Vertrauensarbeitszeit.

## Gehalt

Keine Bandbreite in der Anzeige. Die eigene Erwartung von 85.000 bis 95.000 EUR ist für eine SRE-Stelle bei IONOS in Karlsruhe plausibel, aber unbelegt. Keine Zahl im Anschreiben.

## Fit-Begründung

Vier, weil die betriebliche Grundlage stimmt und die Produktnähe ungewöhnlich ist: Linux, Automatisierung, Telemetrie, Störungsdiagnose, Sicherheit und eine eigene KI-Plattform, die den Dienst IONOS GPT spiegelt.

Auf der Werkzeugachse ist es eine Drei: Kubernetes, Terraform, ArgoCD, GitLab CI und der Prometheus-Grafana-ELK-Stack sind der Alltag dieser Rolle und allesamt nicht vorhanden. Vier gilt für die Passung der Arbeit, nicht für die Übereinstimmung der Werkzeuge. Das Anschreiben sagt das offen.
