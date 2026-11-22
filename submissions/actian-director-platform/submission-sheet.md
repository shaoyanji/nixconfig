# Actian — Director of Platform Engineering [gn] — Data Intelligence Platform

Arbeitnow-Inserat, gefunden im Scouting-Lauf 2026-11-22. Paket am selben Tag gebaut, **nichts eingereicht**.
Eigenständige Typst-Quellen neben den PDFs.

| Feld | Wert |
| :--- | :--- |
| Role ID | `actian-director-platform` |
| Arbeitgeber | Actian (Data Intelligence Platform: Datenkatalog, Knowledge Graph, Integrations-APIs) |
| Rolle | Director of Platform Engineering [gn] |
| Ort | **100 % remote**; cloud-agnostisch, On-Prem und air-gapped beim Kunden |
| Sprache | Englisch |
| Gehalt | keine Bandbreite veröffentlicht; im Gespräch erfragen |
| Fit | **2** (DB-Eintrag 4, wie beauftragt — die Begründung steht unten) |

## Wissen-Graph und Plattformarchitektur — die eigentliche Übereinstimmung

Der Graph ist kein Etikett. `nixconfig` kompiliert zu einem Modell, das per Cypher abgefragt wird:

| Kennzahl | Wert |
| :--- | :--- |
| Kanten | **1.772** |
| Host-Knoten | 38 |
| Modul-Knoten | 330 |
| Tags | 250 |
| Docs | 79 |
| Skills | 63 |

Dazu `.#epistemics.table`: welche Quelle welche Aussage entscheidet — Modulkonfiguration schlägt Prosa,
kompilierte Inventur schlägt handgepflegte Listen. Das ist dieselbe Aufgabe wie Actians Produkt: Metadaten
nicht speichern, sondern so weit belastbar machen, dass eine Entscheidung darauf gebaut werden kann. Die
Lineage eines Claims ist damit explizit, nicht implizit.

### Abgleich mit den fünf Verantwortungsbereichen

| Actian-Bereich | Nachweis im Paket | Urteil |
| :--- | :--- | :--- |
| Platform Engineering & Architektur aufbauen, Standards setzen | Architektur, Modulgrenzen, Register-Check, Docs-Budget — aber allein gebaut | Technik ja, Organisation nein |
| Cloud-agnostisches Deployment, Kubernetes in Produktion | **kein Kubernetes**, kein Terraform/Terragrunt, kein Argo CD; NixOS-Module, Oracle-Hosts | **Lücke** |
| AI-Agenten in Infrastruktur-Betrieb, Guardrails, Auditierbarkeit | Skill-Index kompiliert, Turn-Ledger, Gates statt Zusagen, Prüfpflicht | stark im Muster, klein im Maßstab |
| SOC 2 / ISO 27001 / GDPR, Evidenz automatisiert | SOPS/age, Kurzzeit-Zertifikate, KEV-Berichte als Daten; keine Auditführung | teilweise |
| Team aufbauen, führen, Struktur und Kultur definieren | **keine Führungserfahrung** in einer Software-Organisation | **Lücke** |

## Director-Scope, ehrlich bewertet

Die Anzeige beschreibt einen Aufbau-Job: Organisation gründen, Team rekrutieren, 12-Monats-Plan liefern,
neben dem SVP of Engineering strategisch arbeiten. Das Profil hat Architektur, Betrieb und
Verifikationsdisziplin — aber niemanden geführt, niemanden eingestellt und keine Plattformabteilung
aufgebaut. Fit **2** statt 4: Der Graph passt zum Produkt, der Titel passt nicht zur Biografie.

Das Anschreiben ist deshalb so gebaut, dass es die Absage selbst ausspricht ("If the role is strictly a
director with an existing leadership record, I am not that candidate") und stattdessen eine
founding-engineer-Position anbietet. Wer eine Director-Stelle besetzt, liest das als Klarheit, nicht als
Schwäche — und falls Actian die Rolle kleiner zuschneidet, ist das Gespräch schon eröffnet.

## Was für eine Bewerbung spricht

- Der Graph ist **nachprüfbar**: Repository, Kennzahlen, Query-Oberfläche, Gates.
- Die Verifikationsschicht (Gates in CI und Host, Docs-Budget, Prosa-Gate, Agenten mit Prüfpflicht) ist
  genau die Evidenz, die SOC-2-Auditoren sehen wollen — auch wenn sie nicht als Audit geführt wurde.
- Remote ist ohne Einschränkung zugesagt; kein Standortkonflikt wie bei den Berliner Rollen.

## Prüfungen

| Prüfung | Ergebnis |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, keine Warnungen |
| `typst compile anschreiben.typ` | exit 0, keine Warnungen |
| `pdfinfo lebenslauf.pdf` | **2 Seiten** (Budget 2) |
| `pdfinfo anschreiben.pdf` | **1 Seite** (Budget 1) |
| `task checks:prose` | 230 prose files, exit 0 |
| sha256 Lebenslauf | `b0b4b33728efc790b7c60ee6068a621f04898bc89771b31a73153c8e4ff6e85b` |
| sha256 Anschreiben | `4176da67ce446026ce18f3533833126833b3806953ec2fb8436abfe33e4debdd` |

## Nächste Schritte

1. Bewerben über den Arbeitnow-Link, mit dem founding-engineer-Angebot im Anschreiben.
2. Vor dem Gespräch entscheiden, ob eine kleinere Rolle (Staff/Principal Platform Engineer) akzeptabel ist —
   das Anschreiben bietet sie an, also muss die Antwort parat sein.
3. Bandbreite und Remote-Policy (EU-Residency) erfragen; beides nennt die Anzeige nicht.
