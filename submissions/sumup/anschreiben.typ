// SumUp — Senior DevOps Engineer, Fleet / Cloud Infrastructure. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.85cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.35cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.35cm)
SumUp #linebreak() Platform Tribe — Cloud Infrastructure

#v(0.45cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior DevOps Engineer, Berlin]
#v(0.35cm)

Dear SumUp Cloud Infrastructure team,

Fleet is the layer every other team at SumUp builds on, and the work you describe — Terraform patterns other teams consume, Kubernetes
at scale, reliability metrics that mean something during an incident, compliance that does not slow people down — is work I have done
in a smaller, more opinionated form. I ran a thirteen-host NixOS fleet where infrastructure was code all the way down: pinned inputs,
hermetic builds, reproducible generations, and rollback as a single command rather than a sequence someone remembers at three in the
morning.

The discipline Terraform asks for is the discipline I already keep, in a different tool: a reviewable change, a plan before an apply,
and no hand-edited state. In my repository the plan is the evaluation, the gate CI runs is the gate the machine passes before it
switches, and the inventory file decides which hosts a change reaches. Secrets are sops-encrypted with per-host age keys, SSH is
short-lived certificates from the fleet's own authority rather than standing keys, and services are systemd units whose restart and
failure behaviour is written down instead of assumed.

On reliability I am deliberately unfashionable: a sentinel writes job status, generation age, disk and pressure into a ledger every
fifteen minutes, and it pages on silence as well as on failure, because a monitor that dies quietly looks exactly like a system with
nothing to report. Changes prove themselves on a canary — a KVM microVM built from the same code as its host — before they reach the
fleet. Go and Python carry the automation and the small services behind it, including a PostgreSQL archive that classifies its own
mail and a single validated task surface with dry runs and JSON output.

What I have not done, said plainly: I have not operated production EKS or implemented a service mesh, I have not owned Terraform
modules that other teams build on, my AWS work is not hands-on EC2, VPC and IAM ownership at your scale, and I have not led PCI DSS
or SOC2 work. Kubernetes is the gap I would close first, because the concepts transfer and the operational detail does not. What
transfers immediately is the layer underneath it — Linux, systemd, networking, secrets, rollback and telemetry — and the habit of
writing the reason down where the machine can check it.

I am a US citizen with German permanent residence, so no sponsorship is needed; German is C1 and English native. I am based near
Freiburg and prepared to relocate for an office-first setup in Berlin. My salary expectation is EUR 100,000 to 112,000, and I could
start on 01.12.2026.

I would like to talk about where Fleet's Terraform surface should stop growing, and how you decide which platform improvements are
worth the migration cost.

Kind regards,
#v(0.4cm)
Matt Ji
