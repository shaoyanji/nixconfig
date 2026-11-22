# STACKIT / Schwarz Digits — DevOps / Cloud Engineer (m/w/d), Kubernetes & Infrastructure as Code

Requisition **GT4627**, Am Campus 1, 74177 Bad Friedrichshall. Native Typst-Quellen, `packet`-Symlink und JSON
entfernt. Stand: Paket gebaut und geprüft, **nichts eingereicht**. **[eingereicht laut Apps-DB `stackit-iac` — Stand dieses Blatts liegt vor der Einreichung]**

| Feld | Wert |
| :--- | :--- |
| Role ID | `stackit-iac` |
| Arbeitgeber | STACKIT / Schwarz Digits (Schwarz Gruppe) |
| Rolle | DevOps / Cloud Engineer (m/w/d) — Kubernetes & Infrastructure as Code |
| Req | **GT4627** |
| Ansprechpartnerin | Lara Schlimgen, recruiting\@mail.schwarz |
| Ort | Bad Friedrichshall, Baden-Württemberg |
| Sprache | Deutsch (Anzeige deutschsprachig) |
| Gehalt | keine Zahl im Brief — keine Bandbreite im Auftrag genannt |
| Fit | 2 |

## Was die Anzeige tatsächlich verlangt

Hochverfügbare Services auf dem **STACKIT-Kubernetes-Cluster** als Laufzeitumgebung für ServiceNow Shared
Services (AI Search, ML, Document Intelligence); **CI/CD mit GitLab**; Automatisierung mit **Terraform, Ansible
und helm**; Netzwerkintegration zwischen Kubernetes-Microservices, Java-basierten ServiceNow-Knoten und
Load-Balancer-Clustern; **Sovereign-Cloud-SLAs** über Autoscaling und Observability; **Cluster-Hardening**
(Pod Security, Network Policies) und Compliance nach **BSI C5 und DORA**; Arbeit im agilen Team.

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Kubernetes in Enterprise-Szenarien | **nicht als Administrator betreut** | **Lücke** |
| Terraform, Ansible, helm | **nicht produktiv eingesetzt** | **Lücke** |
| GitLab-CI/CD | Gates gebaut, aber nicht in GitLab | **Lücke** |
| ServiceNow-Plattform | nur als Anwender | **Lücke** |
| BSI C5 / DORA im Container-Umfeld | Praktiken vorhanden, Auditierung nicht | teilweise |
| Linux und Netzwerk | nftables, WireGuard, CA, TLS, Fehleranalyse | stark |
| Observability | Ledger alle 15 Minuten, PSI, cgroups, Alerting | stark |
| IaC-Denkweise | deklarierter Zustand, gepinnte Inputs, Rollback | stark, in Nix |
| Sovereign-Cloud-Haltung | lokale Inferenz auf eigener Hardware | vorhanden |
| Präsenz Baden-Württemberg | ~2 h, Präsenztage zugesagt | erfüllt |

## Warum Fit 2

Vier der sechs fachlichen Kernelemente — Kubernetes-Administration, Terraform/Ansible/helm, GitLab-Pipelines
und ServiceNow — stehen nicht im Profil. Was bleibt, ist Betriebs- und Automatisierungsdisziplin plus
Souveränitätsdenken. Das reicht für eine Bewerbung, die ehrlich ist, aber nicht für eine, die im Fachgespräch
besteht, wenn der Cluster-Betrieb den Kern der Stelle bildet. Deshalb steht die Absage an eine
Bewerbung-als-ob ausdrücklich im Brief.

## Korrekturhinweis

Der Auftrag nannte die Rolle "Infrastructure as Code / Terraform Platform Engineer". Die Anzeige in
`job-description.txt` ist **GT4627, DevOps / Cloud Engineer — Kubernetes & Infrastructure as Code**, mit
ServiceNow, GitLab, BSI C5 und DORA. Die erste Fassung dieses Pakets hat die falsche Rolle adressiert; Brief,
Lebenslauf und diese Seite sind auf die tatsächliche Anzeige umgeschrieben.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `packet`-Symlink | entfernt (zeigte auf `…-devops-cloud-engineer-kubernetes-iac`) |
| `chmod u+w *.pdf` | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `GT4627`, `Schlimgen`, `Kubernetes`, `BSI C5`, `ServiceNow` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 Lebenslauf | `8a1e31ba07caa26fe3af9973f193f148dd81fd863e5d6934b95887e0587020ec` |
| sha256 Anschreiben | `5b6d5a894d1694e346f8ccea039c6636d8420e57a7fc4aba9a59b8acf44c66e4` |

## Nächste Schritte

1. Über den Schwarz-Digits-Link mit **GT4627** bewerben (RocketApply auf SAP BTP).
2. Im Erstgespräch klären, ob der Cluster-Betrieb den Kern bildet oder ob Betrieb und Compliance den Schwerpunkt
   tragen — davon hängt ab, ob die Bewerbung realistisch ist.
3. Erst nach dieser Antwort Aufwand in ein Fachgespräch stecken.
