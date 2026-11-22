# STACKIT / Schwarz Digits — Infrastructure as Code / Terraform Platform Engineer (m/w/d)

Bad Friedrichshall, Baden-Württemberg. Native Typst-Quellen, `packet`-Symlink entfernt. Stand: Paket gebaut und
geprüft, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `stackit-iac` |
| Arbeitgeber | STACKIT / Schwarz Digits |
| Rolle | Infrastructure as Code / Terraform Platform Engineer |
| Ort | Bad Friedrichshall (Baden-Württemberg) |
| Sprache | Deutsch |
| Gehalt | keine Zahl im Brief — Band nicht im Auftrag genannt |
| Fit | 3 |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Infrastructure as Code | Dreizehn Hosts deklarativ, gepinnte Inputs, Rebuild als Pfad | stark, in Nix statt Terraform |
| Terraform | **nicht produktiv verantwortet** | **Lücke** |
| Linux-Plattformbetrieb | systemd, journald, cgroups/PSI, nftables, tcpdump | stark |
| Automatisierung | Go, Python, Bash hinter einer Task-Oberfläche | stark |
| Review- und Gate-Disziplin | Prüfung identisch in CI und Host, kein Rollout ohne Check | stark |
| Drift-Kontrolle | Abweichung als Fehler, Behebung über die Deklaration | stark |
| Cloud (AWS/Azure/GCP) | **kein Eigentümer-Status** | **Lücke** |
| Regionale Präsenz | Baden-Württemberg, ~2 h, Präsenztage zugesagt | erfüllt |

## Die ehrliche Einordnung

Die Stelle trägt Terraform im Titel. Das Profil trägt deklarative Infrastruktur, aber in Nix — nicht in
Terraform, und ohne Provider-/Workspace-Betrieb. Das Anschreiben benennt das im vierten Absatz und stellt die
gemeinsame Denkweise daneben: wahrer Zustand, Drift, zweiter Lauf, Plan vor Apply, Review. Fit **3**: die
Arbeitsweise passt, das Werkzeug fehlt.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `packet`-Symlink | entfernt |
| `chmod u+w *.pdf` | ausgeführt |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker | `Infrastructure as Code`, `Terraform`, `Baden-Württemberg`, `Niederlassungserlaubnis` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 Lebenslauf | `9d9302b0fc9ec257274c784c29564a52bb98523ebfbcc12ca730af8f4e48fb3d` |
| sha256 Anschreiben | `373d6726509a110729295f6984e45b450875d7cca9a672155d48ccf80f78ce9d` |

## Nächste Schritte

1. Über das Schwarz-Digits-Portal bewerben.
2. Im Erstgespräch klären, ob der Bestand aus Terraform-Modulen besteht oder neu aufgebaut wird — davon hängt
   ab, wie viel Einarbeitung realistisch ist.
