// Flix — Cloud Engineer (Identity and Access Management). English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
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

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Flix\\
IT Infrastructure Services

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Cloud Engineer, Identity and Access Management]
#v(0.4cm)

Dear Flix team,

identity is the one part of infrastructure where the policy and the mechanism have to be the same artifact, because when they
disagree the mechanism wins. I learned that on a thirteen-host fleet I built and then had to defend: access is issued rather
than stored, a certificate authority mints short-lived SSH credentials so a permission exists for a purpose and expires,
secrets are encrypted per host with sops and age and decrypted only at activation with that machine's own key, and every
grant sits in the same repository as the system it applies to. Reviewing access is reviewing a diff with a history, not
chasing a spreadsheet.

The integration side is where I have the most direct experience of the work you describe. I have built OAuth consent and token
refresh flows against third-party APIs, including the part nobody enjoys: what happens when a token expires at the wrong
moment, and how the failure surfaces before a user reports it. Automating the recurring part came with it — Python and Go
behind one task surface with named arguments, validation and dry-run plans, so a routine request becomes a command and a wrong
argument fails before it touches anything.

Your posting says you do not need an identity specialist today and will grow someone into it. That is the offer I am
answering, so I will be precise about where I stand. I have run identity as Linux credentials, certificates and encrypted
secrets at depth; I have not administered Microsoft Entra ID or any SSO platform, built SAML federation, or worked in an M365
tenant. Nor have I used AWS or Terraform — my infrastructure is declared NixOS on rented metal, which is the same discipline
of describing state and reconciling it, with different syntax. What I bring instead is the judgement about what a grant
actually means, which is harder to teach than a console.

Consulting other teams is the half of this job that decides whether the platform is used or routed around. My version of that
was making the safe path the short one: one entry point with help text and a dry run, documentation generated from the same
source as the configuration, and defaults that are correct without a conversation. When a team had to ask me how to get
access, I treated it as a defect in the tooling rather than a gap in their knowledge.

I am a US citizen with German permanent residence, so Berlin needs no sponsorship, and German is C1 with English native.

One question I would ask in a first call: when someone leaves or changes role, what actually removes their access today — a
sync from the HR system, a scheduled review, or a person remembering? The third answer is common and it is the one that turns
into an audit finding.

Kind regards,
#v(0.45cm)
Matt Ji
