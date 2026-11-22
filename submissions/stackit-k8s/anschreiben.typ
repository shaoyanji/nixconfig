// STACKIT / Schwarz Digits — Senior Kubernetes Engineer (m/f/d), GT4121.
// Deutsches Anschreiben, eine Seite.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "de")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(left)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.38cm)
#text(size: 9pt)[STACKIT / Schwarz Digits]
#linebreak()
#text(size: 9pt)[Am Campus 1 · 74177 Bad Friedrichshall]

#v(0.42cm)
#text(size: 8.6pt, fill: muted)[22. November 2026]

#v(0.42cm)
#text(weight: "bold", size: 10pt)[Bewerbung: Senior Kubernetes Engineer (m/f/d), GT4121]
#v(0.34cm)

Sehr geehrte Damen und Herren,

wer die Cloud für Lidl und Kaufland betreibt, kann sich keinen Cluster leisten, dessen Zustand niemand erklären kann. Genau an dieser Frage habe ich
sechs Jahre gearbeitet, wenn auch eine Ebene tiefer: eine Flotte von dreizehn NixOS-Hosts, deklariert in einem Flake mit gepinnten Inputs, ein
Auswertungslauf pro Host als Freigabe, jede Änderung eine Generation, die sich in einem Befehl zurückrollen lässt.

Container und microVMs kenne ich von der Grenze her, nicht von der Oberfläche. Ich habe Gäste deklarativ beschrieben und auf KVM mit
cloud-hypervisor gestartet, mit vsock für den Kanal zum Host, virtiofs für geteilte Verzeichnisse und einem TCG-Rückfall, wenn die
Hardwarevirtualisierung fehlt. Die Gäste hängen hinter einer isolierten Bridge mit NAT und udev-gebundenen Taps, Ressourcengrenzen setzen
systemd-Slices und cgroups. Wer so arbeitet, lernt, was ein Namespace trennt und wo die Grenze durchlässig wird.

Betrieb heißt bei mir messen statt vermuten. Ein Sentinel schreibt Job-Status, Generationsalter, Disk- und Inode-Auslastung sowie PSI-Werte für IO,
Speicher und CPU alle fünfzehn Minuten in ein Journal und alarmiert auf schlechten Zustand und auf Stille, weil ein ausgefallener Melder sonst wie ein
gesunder Host aussieht. Netzgrenzen ziehe ich von Hand: nftables-Freigaben je Dienst und Netz mit datierten Streichungen, WireGuard-Mesh, DNS-Failover
mit VRRP, Fehlersuche mit tcpdump bis zur MTU an der Grenze, die das Paket verwirft.

Wo ich hinter Ihrem Profil zurückbleibe, sage ich vorab: Kubernetes habe ich nicht in Produktion betrieben, weder als Cluster noch als
Multi-Cluster-Landschaft, und weder Gardener noch ClusterAPI eingesetzt. Operatoren, Controller und CRDs in Go habe ich nicht geschrieben; meine
Go-Arbeit sind Dienste und Kommandozeilenwerkzeuge. Kyverno, Falco, GitOps mit Argo oder Flux und der Betrieb von CNI und etcd fehlen ebenfalls. Was
ich mitbringe, ist die Basis, auf der ein Cluster trägt: Linux und Namespaces, Ressourcengrenzen, deklarative Plattformzustände mit geprüftem Rückweg,
Telemetrie, die auch Stille erkennt, und Go für die Werkzeuge drumherum. Diese Lücke würde ich in den ersten Monaten schließen, mit Zertifizierung und
mit dem Lesen Ihrer Operator-Codebasis als Einstieg.

Formal: US-amerikanischer Staatsbürger mit unbefristeter deutscher Niederlassungserlaubnis, also ohne Sponsoring arbeitsberechtigt. Englisch ist meine
Muttersprache, Deutsch spreche ich auf C1-Niveau. Für die Rolle ziehe ich nach Bad Friedrichshall; mein frühester Eintritt ist der 01.12.2026. Meine
Gehaltsvorstellung liegt bei 85.000 EUR brutto jährlich.

Mit freundlichen Grüßen,
#v(0.4cm)
Matt Ji
