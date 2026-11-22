# Adfinis AG — Senior System Engineer (Cloud Native, 80–100 %, remote in Deutschland)

Join.com **ID260710**. Deutsches Paket. Native Typst-Quellen; die alten `Adfinis_*`- und `Matt_Ji_*`-Dateien sowie
`selection.json` sind entfernt.
Status: kompiliert und geprüft, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `adfinis` |
| Arbeitgeber | Adfinis AG (Schweizer Open-Source-Beratung, rund 150 Mitarbeitende, deutsches Team mit fünf Personen) |
| Rolle | Senior System Engineer (Cloud Native), 80–100 % |
| Ort | Remote innerhalb Deutschlands, unbefristete Anstellung |
| Sprache | **de** |
| Bewerbung | https://join.com/companies/adfinis/16924002-senior-system-engineer-cloud-native-80-100-remote-within-germany-id260710 |
| Vergütung | veröffentlicht **64.000 – 83.000 €/Jahr** bei 80–100 %; im Sheet hinterlegter Wunsch 78.000 €, **nicht im Brief genannt** |
| Ansprechpartner | Felix Kronlage-Dammers, Country Manager Germany |
| Fit | 3 (DB-Eintrag 4) |

## Was die Stelle verlangt

Betrieb und Automatisierung von Linux-Systemen für Kunden: Kubernetes (EKS, AKS, OpenShift, SUSE Rancher, Helm, Argo CD),
Terraform/OpenTofu, Vault/OpenBao, GitLab CI, Infrastructure as Code, Monitoring. 5–8 Jahre Erfahrung im Cloud-System-
Engineering, Deutsch und Englisch auf C1. Die Ausschreibung fragt ausdrücklich „Arch, Fedora oder NixOS?" — **NixOS ist
also eine akzeptierte Distribution**, was für dieses Profil der entscheidende Satz ist.

## Fit-Map

| Anforderung | Nachweis | Bewertung |
| :--- | :--- | :--- |
| Linux-Systeme, Betrieb, Bereitschaft | Fünf Jahre eigene Flotte, Pager selbst gehalten | **stark** |
| Infrastructure as Code | Ein Flake, Module, gepinnte Eingänge, Generationen | stark, **nicht Terraform** |
| CI/CD | Ein Gate für CI und Host, inventarisierte Matrix | **stark** |
| Monitoring und Alarmierung | Fünfzehn-Minuten-Ledger, Alarm auf Zustand, Stille als Fehler | **stark** |
| Security, Secrets, Zugänge | sops/age pro Host, SSH-CA mit kurzlebigen Zertifikaten, Default-Deny | **stark** |
| Open Source als Arbeitsweise | Das Repository ist öffentlich und wird als Arbeitsprobe angeboten | **stark** |
| Kundenkommunikation | Zehn Jahre Kunden-, Banken- und Broker-Termine auf Deutsch und Englisch | stark |
| Kubernetes (EKS, AKS, OpenShift, Rancher, Helm, Argo CD) | **keine** | **Lücke, Kern der Stelle** |
| Terraform / OpenTofu | **keine**; Nix-Flake | **Lücke** |
| Vault / OpenBao, GitLab CI | **keine** (eigene CA, eigenes Gate) | Lücke |
| 5–8 Jahre Cloud-System-Engineering | Infrastruktur-Tiefe konzentriert 2023–2025, davor zehn Jahre Systeme und Modelle | teilweise |

Fit **3**: Betrieb, IaC-Denke, Monitoring und Security-Handwerk passen gut; der Kubernetes- und Terraform-Kern der Stelle
fehlt. Der DB-Eintrag behält die vorgegebene **4**.

## Das Argument des Briefes

Der erste Satz ist die These: Infrastruktur, die nur in der Hand ihres Erbauers funktioniert, ist keine Infrastruktur,
sondern eine persönliche Dienstleistung. Danach folgt der Nachweis in einem Absatz — Deklaration, Gate identisch in CI und
Host, Generationen mit Vorfahren, sops und CA, Sentinel mit Stille-Alarm — und der Satz, der für eine Beratung zählt:
Beratung heißt, die Lösung muss beim Kunden weiterleben, wenn das Projekt vorbei ist, deshalb Mechanismen statt
Anleitungen.

Die Lücke wird benannt, nicht umschrieben: kein Kubernetes-, Terraform- oder Vault-Betrieb im Kundengroßmaßstab — mit dem
Verweis auf die Ausschreibung, die NixOS ausdrücklich akzeptiert.

## Praktisches

- **Nicht beide Stellen bewerben:** eine Professional-Variante (ID260709, 53–64 k) ist ebenfalls offen; eine Bewerbung
  reicht, sonst wirkt es gestreut.
- Join.com-Formular: Name, E-Mail, Telefon, Lebenslauf und Anschreiben als Upload, frühester Eintritt sofort.
- Gehalt im Formular 78.000 € (innerhalb des Bandes), im Brief bewusst keine Zahl.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| Altdateien (`Adfinis_*.pdf/.txt`, `Matt_Ji_*.pdf`, `selection.json`) | entfernt |
| `chmod u+w *.pdf` | vor dem Kompilieren |
| `typst compile lebenslauf.typ` | Exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | Exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker CV | `NixOS`, `Kubernetes` (Lücke), `Terraform` (Lücke), `PSI`, `Open Source` |
| Marker Brief | `Adfinis`, `Kronlage`, `NixOS`, `Kubernetes`, `Open Source` |
| `task checks:prose` | 253 prose files, exit 0 |
| sha256 CV | `3bf9455ba01931b9819d6a65782fc126a17a57d67f19d145ef5c147ce8a7ae68` |
| sha256 Brief | `3b2fe2339f5267d31e2b8db55a200ab11614675000f7bafe02977c7ad2aa1fad` |
| DB-Rückleseprobe | nach dem Upsert geprüft |

## Nächste Schritte

1. Über Join.com bewerben, Anschreiben als PDF hochladen (nicht als Text einfügen).
2. Im Gespräch die NixOS-Stelle als Brücke nutzen und ehrlich sagen, wo Kubernetes Erfahrung fehlt.
3. Fragen, wie Adfinis Kunden nach Projektende befähigt — das ist die Frage, die zur Bewerbung passt.
