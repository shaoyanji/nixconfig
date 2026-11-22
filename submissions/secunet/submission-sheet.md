# secunet Security Networks — Senior Software Engineer Infrastructure / Linux Security (ID 3550/F)

Rexx Systems, `jobs.secunet.com/…-j3550.html`. Quellen sind jetzt **native Typst-Dateien**; die alten
PDF-Namen (`Matt_Ji_Resume_Secunet.pdf`, `Secunet_Anschreiben.pdf`), `selection.json` und das
`.txt`-Sheet sind entfernt. Stand: Paket fertig, **nichts eingereicht**.

| Feld | Wert |
| :--- | :--- |
| Role ID | `secunet` |
| Arbeitgeber | secunet Security Networks AG, Kurfürstenstraße 58, 45138 Essen |
| Rolle | Senior Software Engineer – Infrastructure / Linux Security |
| ID | 3550/F |
| Ansprechpartnerin | **Frau Nicole Schulz** |
| ATS | Rexx Systems |
| Sprache | Deutsch C1 |
| Gehalt | keine Bandbreite im Inserat; keine Zahl im Brief |
| Fit | 3 |

## Fit-Map

| Anforderung | Nachweis | Urteil |
| :--- | :--- | :--- |
| Linux-Infrastruktur betreiben | Dreizehn Hosts deklarativ, Gates, Rollback, Rebuild | stark |
| IT-Sicherheit / Härtung | Default-Deny, Minimallauf, Rechteprüfung, Abhängigkeitsprüfung | stark |
| nftables / Firewalls | nftables Default-Deny mit expliziten Freigaben, WireGuard | stark |
| NixOS / deklarative Systeme | Flake mit gepinnten Inputs, Rebuild als Pfad | stark |
| CA-Hygiene / PKI | Eigene TLS-CA, SSH-CA mit kurzlebigen Zertifikaten | stark |
| Secrets-Verwaltung | SOPS/age pro Host, kein Klartext im Repo | stark |
| Kubernetes / OpenShift | **nicht produktiv administriert** | **Lücke** |
| SÜG Stufe 2 | Bereitschaft erklärt, Entscheidung bei der zuständigen Stelle | offen |
| Deutsch C1 | Unterlagen auf Deutsch, Brief in C1 | erfüllt |

## SÜG 2 — was der Brief sagt und was nicht

Der Auftrag verlangt die ausdrückliche Bereitschaft. Der Brief erklärt sie und nennt zugleich die Grenze:
US-Staatsbürgerschaft mit deutscher Niederlassungserlaubnis ist ein unbefristetes Aufenthaltsrecht, **keine
Staatsbürgerschaft**; § 9 SÜG lässt verbündete Staatsangehörige nur als Ausnahme zu, über die die zuständige
Stelle entscheidet. Deshalb steht im Brief kein Satz, der die Freigabe als Formsache darstellt — sondern die
Bereitschaft, der Hinweis auf die Entscheidung anderer und die Bitte, früh zu sprechen, falls eine erteilte
Freigabe Voraussetzung ist.

## Gehalt

Keine Angabe im Inserat, keine Zahl im Brief. secunet vergütet nach eigener Darstellung übertariflich; eine
Forderung ohne Bandbreite wäre geraten, deshalb bleibt es beim Gespräch.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `chmod u+w *.pdf` vor dem Bau | ausgeführt (Altlasten waren `-r--r--r--`) |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** |
| `pdfinfo anschreiben.pdf` | **1 Seite** |
| Marker im PDF | `SÜG Stufe 2` (CV), `Schulz`, `3550`, `Niederlassungserlaubnis`, `SÜG` (Brief) |
| `task checks:prose` | 236 prose files, exit 0 |
| sha256 Lebenslauf | `e675d8c78bb1899be18089e16445ea2bf53931c0a3ea628da99fe3a331bad186` |
| sha256 Anschreiben | `dfab6a5734f6ceeccecc2f7b3efbfef564a9bd1520bd03814e56562b4cfc72c5` |
| Altlasten | alte PDF-Namen, `selection.json`, `Secunet_Submission_Sheet.txt` entfernt |

## Nächste Schritte

1. Über das Rexx-Systems-Formular mit ID **3550/F** bewerben, Anschreiben an Frau Schulz.
2. Im Erstkontakt die SÜG-2-Frage klären, bevor Unterlagen für eine Prüfung entstehen.
3. Kubernetes-Anteil der Rolle erfragen — davon hängt ab, ob die Bewerbung fachlich trägt.
