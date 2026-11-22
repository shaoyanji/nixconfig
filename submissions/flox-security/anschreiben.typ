// Flox — Member of Technical Staff, Security. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.32cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.32cm)
Flox

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Member of Technical Staff, Security]
#v(0.32cm)

Dear Flox team,

Flox sits where I have spent the last three years: on the build graph. My fleet is one flake over thirteen hosts, every input pinned, host
paths pinned to their submodules, builds running in the sandbox with the network closed and the output content-addressed — so an artefact is
identified by what produced it, and a rebuild either reproduces or becomes a finding.

The supply chain around that graph is the part I would own here. What enters is pinned; what arrives from outside is verified. Release
binaries carry an expected `sha256` that a second party confirms before install, the asset filter is written to exclude the `^sbom` and
signature sidecars so a release cannot redirect the fetch, and there is no `curl | sh` in any definition I ship. Credentials are sops
values encrypted to per-host age keys and decrypted at activation; host access is short-lived SSH certificates from an own certificate
authority rather than standing keys. Access itself is a reviewed diff: default-deny nftables, grants declared beside the systems they
protect.

On the two things your posting puts next to each other — what an artefact contains, and which of its parts is dangerous — I will separate
what I have from what I have not. The inventory I keep is the store closure: the set of paths an artefact depends on, which is what an SBOM
is for. I have not emitted CycloneDX or SPDX from it, and no grype, trivy or osv-scanner runs in my pipeline; that is the first thing I would
build, and it is mostly plumbing over a closure that already exists. The advisory side is real: the CISA KEV catalogue as a time series,
grouped into effort clusters with exposure per cluster, so patching follows what is being exploited against what it costs to close. I have
also audited bug-bounty programmes and threat-modelled systems before release, and a decade of risk analysis before that.

Gaps rather than surprises: I have not owned AWS hardening at the depth the posting describes — IAM and SCP review, GuardDuty, Security Hub,
CSPM — nor Cloudflare Zero Trust (my zero-trust access is Tailscale plus an SSH CA), nor EDR/MDM, nor SIEM/SOC operation. I have studied
SLSA and shipped none of it; I know where it would start, which is mapping the artefact path from upstream release to customer environment
and gating promotion on attestations worth their operational cost. Nix gives reproducibility as a foundation; SLSA is how that becomes
evidence a customer can check.

I am a US citizen with German permanent residence, so no sponsorship is needed, though I would want to confirm early that a Germany-based
arrangement fits your US-remote payroll. The repository is the argument: https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
