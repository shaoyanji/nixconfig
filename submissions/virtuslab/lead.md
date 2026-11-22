# Lead: VirtusLab — Linux Hacker & Nix Wizard (Senior / Expert)

Fit: 4
Stand: 22.11.2026
Ort: Polen (Board-Eintrag); Vertragsform B2B, laut Auftrag 175 PLN/h
Quelle: join.vl.team, HTTP 200 am 22.11.2026
Sprache: Englisch

## Quellenlage

Verzeichnis und Datensatz waren nicht vorhanden; das Paket ist neu. Die Anzeige liegt vollständig im Paket. Gefordert: Linux-Core- oder Kernel-Interna (advanced), Nix (advanced), Python (expert), Englisch C1, Systemarchitektur und Automatisierung. Erwünscht: Kernel-Diagnose mit eBPF, perf, strace, valgrind; Python-Performance, Async und C/Rust-Interop.

## Warum interessant

Die Rollenbezeichnung beschreibt das Repository: eine Flake, die dreizehn Hosts beschreibt, ein Modul je Dienst, eine Feature-Liste je Host, gepinnte Inputs, ein Gate vor dem Rollout. Das ist keine Nix-Erfahrung am Rand, sondern fünf Jahre Betrieb auf dieser Grundlage.

## Was passt

- Flake-Architektur mit Modulkomposition, Feature-Listen je Host und klarer Zuordnung, was ein Gate prüfen muss.
- Reproduzierbare Builds aus gepinnten Inputs, Rückrollung über Generationen.
- Linux im Betrieb: systemd, cgroups, Namespaces, PSI- und Disk-Druck, nftables, WireGuard, eigene CA.
- Werkzeuge in Python und Go: Rollout, Alarm-Bridge mit Zustellbestätigung, Auswertungen.
- Automatisierung als Aufgabe, nicht als Skriptsammlung: Tasks, Gates, Docs-Pipeline.
- Öffentliches Repository mit nachvollziehbarer Historie; Englisch Muttersprache.

## Was fehlt

- **Kernel-Interna** — Linux wird betrieben, nicht gepatcht; keine Speicherverwaltungs- oder IPC-Arbeit.
- **eBPF, perf, strace, valgrind** — keine Profiling- oder Diagnosewerkzeuge in eigener Anwendung belegt.
- **Python auf Expert-Niveau** — Werkzeuge ja, Performance-Optimierung, Async und C/Rust-Interop nein.
- **Rust und C-Interop** — nicht vorhanden.
- **B2B-Vertragsform und Stundensatz** — organisatorisch zu klären.

## Weg

Bewerbung über das VirtusLab-Portal, englischsprachiger Antrag. Keine Frist genannt.

## Gehalt

Laut Auftrag 175 PLN/h auf B2B; im Anschreiben steht keine Zahl.

## Fit-Begründung: 4 von 5, nicht 5

Der Auftrag nennt 5. Vier ist die belastbare Zahl: die Nix-Hälfte ist der stärkste Nachweis im ganzen Bestand — eine Flake über dreizehn Hosts, drei Hardware-Generationen, mit Gate und Rückrollung. Aber die Anzeige führt Linux-Core- und Kernel-Interna als erste Anforderung, und dazu kommen eBPF, perf und Python auf Expert-Niveau. Keines davon ist belegt.

Vier heißt: das Gespräch über Nix und Betrieb wird gut, das über Kernel-Interna ehrlich kurz.
