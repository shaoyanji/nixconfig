# Lead: Adyen — Senior Platform Engineer - GenAI

Fit: 4
Stand: 22.11.2026
Ort: Amsterdam oder Madrid, office-first — Umzug aus Deutschland nötig
Greenhouse-Req: 8163866
Sprache: Englisch
Datenbank-Notiz (Bestand): K8s/GitOps/Python-Plattform; Nix statt Argo CD ist die Werkzeuglücke.

## Quellenlage

Verzeichnis war leer, aber ein Datensatz existierte bereits mit einer Notiz zur Stelle. Die Anzeige liegt vollständig über die Greenhouse-API vor (HTTP 200 am 22.11.2026): Senior Platform Engineer - GenAI, Amsterdam oder Madrid, mit Kubernetes, vLLM und GPU-Inferenz im Anforderungsprofil.

## Warum interessant

Adyen baut eine interne GenAI-Plattform für die eigenen Ingenieure: Modellinferenz als betreuter Dienst, GPU-Kapazität als Ressource, Werkzeuge, die Produktteams nicht selbst bauen sollen. Das ist Plattformarbeit mit einem klaren Nutzerkreis — und der Nutzerkreis ist der Grund, warum die Rolle Senior ist.

## Was passt

- Eigene Modellinferenz betrieben: Qwen3-TTS, Parakeet und Qwen-Image hinter OpenAI-kompatiblen Endpunkten, inklusive Router und On-Demand-Laden.
- GPU als knappe Ressource behandelt: ein Guard, der Inferenzarbeit zurückstellt, wenn andere Last Vorrang hat.
- Transportdetails verstanden: Rohbytes statt Multipart bei Audio, weil der Umweg über Formulardaten messbar kostet.
- Linux-Plattform: 13 Hosts, systemd, cgroups, nftables, Tailnet, eigene SSH-CA, sops/age.
- Hermetische Builds und Rollouts: gepinnte Inputs, Prüfung vor dem Ausrollen, Rollback über Generationen.
- Telemetrie: Ledger alle 15 Minuten, Gatus-Prüfungen, Auswertung in Python und Go.
- Python und Go als Plattformsprache, nicht als Skriptsprache.
- Englisch Muttersprache, Deutsch C1, US-Staatsangehörigkeit mit Niederlassungserlaubnis.

## Was fehlt

- **Kubernetes** — nicht betrieben; die Anzeige nennt es an zentraler Stelle.
- **vLLM oder gleichwertiges Serving in Flottengröße** — die eigene Inferenz ist Ein-Host-Betrieb.
- **GPU-Cluster-Scheduling** — keine MIG-, Device-Plugin- oder Node-Pool-Erfahrung.
- **Payments-Domäne** — keine Zahlungsverkehrserfahrung.
- **Präsenz** — Amsterdam oder Madrid, office-first; Wohnsitz ist Deutschland.

## Weg

Greenhouse-Bewerbung über Req 8163866, englischsprachig. Ohne Umzugsbereitschaft ist die Stelle nicht haltbar; das ist im Anschreiben nicht versteckt.

## Gehalt

Keine Zahl im Anschreiben; die Anzeige nennt keine.

## Fit-Begründung: 4 von 5

Vier, wie vorgegeben. Die Plattformhaltung ist belegt und der GenAI-Teil ist keine Behauptung: es gibt eine laufende Inferenzumgebung mit Router, On-Demand-Laden und Ressourcen-Guard, gebaut und betrieben von derselben Person, die die Plattform darunter verantwortet.

Nicht 5, weil Kubernetes und vLLM in Flottengröße fehlen und die Rolle office-first in Amsterdam oder Madrid ist, während der Wohnsitz in Deutschland liegt. Vier heißt: Gespräch plausibel, Umzug und k8s-Einarbeitung sind reale Bedingungen.
