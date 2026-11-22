# Bewerbung — MPCDF, Linux System Administrator (Kennziffer 04/2026)

Stand: 22. November 2026
Fit: 2
Sprache: Deutsch
Status: native Typst-Quellen, kompiliert und gemessen; Fit nach Lesen der Anzeige auf 2 korrigiert

## Stelle

| Feld | Wert |
| :--- | :--- |
| Arbeitgeber | Max Planck Computing and Data Facility (MPCDF), zentrale Einrichtung der MPG |
| Rolle | Linux System Administrator\*in (m/w/d), Kennziffer 04/2026 |
| Ort | Forschungszentrum Garching bei München |
| Kern der Stelle | Betrieb und Weiterentwicklung der Identity-Management-Basisdienste, genannt LDAP- und Kerberos-Server |
| Umfeld | Max-Planck-Supercomputer, Compute-Cluster, Cloud-Plattform, Datenrepositorien |
| Veröffentlicht | 16.07.2026 — über vier Monate alt, in der Stellenbörse nicht mehr gelistet |
| Weg | https://www.mpg.de/26871563/linux-system-administrator-in-m-w-d |

## Quellenhinweis

Der zuerst gespeicherte Abruf der mpg.de-Seite war das Jobboard-Gerüst ohne Anzeigentext; eine Suche über das Jobboard und der MPCDF-Auftritt lieferten den Stellentext. Die Seite selbst leitet inzwischen auf die Stellenbörse um, die MPCDF-Detailseite antwortet mit 404. Der Anzeigentext steht als Kopf von `job-description.txt`.

## Gemessene Artefakte

| Datei | Seiten | Bytes | Wörter | SHA-256 (gekürzt) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 38110 | 572 | `96d586265781fddd` |
| `anschreiben.pdf` | 1 | 24195 | 353 | `c3ae4edd3fc0aa13` |

## Fit-Map

| Anforderung | Nachweis im Paket | Bewertung |
| :--- | :--- | :--- |
| Linux im Produktivbetrieb | 13 Hosts, drei Hardware-Generationen, fünf Jahre allein | Stark |
| Basisdienste betreiben, von denen alles abhängt | DNS, Adressierung, Secrets pro Host, eigene Zertifizierungsstelle mit kurzlebigen Zertifikaten, WireGuard, nftables | **Stärkster Nachweis** |
| Dienste reproduzierbar ausliefern und rückrollen | Beschreibung als Quelle, PXE, Gate, Rückrollung in Minuten | Stark |
| Störungen erkennen, bevor sie ausfallen | Ledger alle 15 Minuten, Prüfungen von außen, Alarmbrücke mit Zustellbestätigung | Stark |
| Messdisziplin, nachvollziehbare Daten | Fraunhofer ISE 2012: Messaufbau, Auswertung in Python, Ablage | Stark |
| Werkzeuge selbst schreiben | Python, Go, Shell für Rollout, Auswertung, Berichte | Stark |
| LDAP (OpenLDAP, 389 DS) | nicht vorhanden | **Kernlücke** |
| Kerberos (MIT, Heimdal) | nicht vorhanden | **Kernlücke** |
| SSSD, PAM, FreeIPA, Zwei-Faktor | nicht vorhanden | **Lücke** |
| Abschluss in einem IT-nahen Bereich | M.Sc. Erneuerbare Energien, B.Sc. Ingenieurwesen | Teilweise |
| Drei Jahre Berufserfahrung | fünf Jahre Systembetrieb, davor Asset Management | Erfüllt (nicht im IDM) |
| HPC-Umfeld (Supercomputer, Cluster) | cgroups, Namespaces, PSI; Slurm, Lustre, InfiniBand nicht vorhanden | Kontext, nicht Anforderung |
| Deutsch, Englisch | C1, Muttersprache | Erfüllt |

## Fit-Begründung: 2

Die Anzeige benennt LDAP und Kerberos als die Dienste, um die es geht. Beides ist nicht vorhanden — damit fehlt der Kern der Stelle, nicht ein Nebensatz, und das Anschreiben sagt es im dritten Absatz. Was übrig bleibt, ist die Betriebsform: Basisdienste allein verantworten, Zertifikate und Secrets selbst verwalten, Änderungen prüfen und rückrollen, messen statt schätzen. Zwei heißt: ein Gespräch über Betriebsdisziplin ist möglich, ein Gespräch über Kerberos-Realms nicht.

## Offene Punkte

1. **LDAP und Kerberos** als Kernlücke im Anschreiben benannt, samt SSSD, PAM, FreeIPA und Zwei-Faktor.
2. **Studienfach** ist Erneuerbare Energien, nicht Informatik — im Anschreiben offen gesagt.
3. **Maßstab** — dreizehn Knoten sind kein Rechenzentrum.
4. **Anzeige ist alt**: veröffentlicht 16.07.2026, nicht mehr in der Stellenbörse. Vor dem Absenden nachfragen, ob Kennziffer 04/2026 offen ist.
5. **Zeugnisse** fehlen.
