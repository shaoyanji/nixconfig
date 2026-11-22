#set document(title: "Bewerbung 1&1 — Senior Linux Operations Engineer, Kennziffer 5836", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "de")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  1&1 / United Internet \
  Corporate IT Services — Linux Application Operations \
  Kennziffer 5836, Karlsruhe
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22. November 2026]]

#v(6pt)
#text(weight: "bold")[Bewerbung als Senior Linux Operations Engineer (w/m/d) — Kennziffer 5836]

#v(4pt)
Sehr geehrte Damen und Herren,

#v(2pt)
Ihr Team Linux Application Operations betreibt für über 11.000 Mitarbeitende das konzernweite LDAP, das Identity- und Access-Management und weitere zentrale Dienste. Die Anzeige beschreibt den Kern der Aufgabe in einem Satz, der selten so klar dasteht: teilweise manuell betriebene Systeme in weitgehend automatisierte, standardisierte Plattformen überführen. Genau diese Arbeit habe ich fünf Jahre lang allein gemacht.

#v(2pt)
Dreizehn Hosts, ein Repository. Was ein Host ist — Kernelpaket, Initrd-Module, Firmware, systemd-Dienste, Firewall, Zugriffsrechte — steht im Bestand und nicht in einer Übergabenotiz. Eine Änderung geht durch eine Prüfung, die dasselbe Modul-Gate ausführt wie die Maschine, ein Rebuild ist der Commit plus ein Befehl, und die Rückkehr zur vorigen Generation ist Routine statt Ausnahme. Dazu läuft ein Sentinel, der Jobstatus, Generation-Alter, Disk- und PSI-Druck alle fünfzehn Minuten protokolliert und erst alarmiert, wenn die Zustellung bestätigt ist. Für eine Störung heißt das: messen, eingrenzen, und einen Runbook-Eintrag hinterlassen, der beim nächsten Mal die ersten zwanzig Minuten spart.

#v(2pt)
Was ich nicht mitbringe, sage ich vorher: Ansible habe ich nicht als Produktionswerkzeug geführt — meine Automatisierung liegt in Nix, Python, Go und Bash. Checkmk und ElasticSearch sind nicht im Einsatz, sondern eigene Telemetrie, und eine Plattform für 11.000 Nutzende habe ich nicht betrieben. Das sind Einarbeitungen, keine Ausreden: Die Fragen dahinter — was automatisiere ich zuerst, wie prüfe ich es, wie komme ich zurück — sind auf jeder Flotte dieselben, und ich habe sie auf meiner beantwortet.

#v(2pt)
Deutsch ist bei mir C1, Englisch Muttersprache; ich bin US-Amerikaner mit deutscher Niederlassungserlaubnis, Visumsunterstützung ist nicht nötig. Karlsruhe ist von Gutach im Breisgau aus gut erreichbar, die zwei mobilen Tage pro Woche passen, und an der Rufbereitschaft im Rotationsmodell nehme ich teil. Wenn Sie den Betrieb lieber an einem Nachmittag sehen als beschrieben: Mein Repository ist die ungeschminkte Version davon — github.com/shaoyanji/nixconfig

#v(4pt)
Mit freundlichen Grüßen

#v(18pt)
Matt Ji
