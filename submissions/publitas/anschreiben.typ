// Publitas — Senior IT Operations Engineer. English letter, one page.
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
Publitas\\
Operations

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior IT Operations Engineer]
#v(0.45cm)

Dear Publitas team,

most internal IT problems are the same problem twice: something was granted once, nobody knows to whom, and the only way
to find out is to ask. I built the opposite arrangement for a thirteen-host fleet and would build it again for a company
of people working apart. Access is issued rather than stored: a fleet certificate authority mints short-lived SSH
credentials, secrets are encrypted per host, and the network defaults to deny. A permission exists for a purpose and
expires, which is a stronger control than a review nobody reads.

The rest of the estate follows the same idea. Every host is declared in one repository, every input is pinned, and the
check that runs in CI is the check that runs on the machine, so a green build cannot disagree with a healthy host. Each
change keeps its parent, which makes a bad rollout a pointer rather than an incident at the wrong hour. A sentinel writes
job status, generation age, disk pressure and PSI every fifteen minutes and pages on any state short of ok and on silence
itself, because the machine that stopped reporting is the one that costs you a weekend. Routine work sits behind one task
surface with validation and dry-run plans, so the answer to a request is a command, not a ticket.

Two things you will want to hear plainly, since a senior role in internal IT is judged on honesty about scope. I have not
run a Mac estate, an MDM such as Jamf or Kandji, or an identity provider such as Okta or Google Workspace, and I have not
carried a SOC 2 or ISO 27001 audit. Those are the corporate-IT surface, and it is where I would be learning rather than
teaching. What I bring instead is the discipline that surface needs: identity as configuration rather than habit, access
that expires, changes that are reviewable, and documentation written next to the thing it describes.

On the async point, which your posting treats as a filter: the way I work is already written down. Decisions live as
records, runbooks ship with the change, and ownership is defined as something finished rather than handed over. That is
also why your line about AI being a lever rather than a curiosity reads to me as a description of my week: agents work
against isolated worktrees with claims, tiered tool access per host, approval before anything destructive, and a written
gate that decides whether the output counts. The model proposes; the check decides.

On location and paperwork: I live in Germany on permanent residence as a US citizen, so working remotely from Germany
needs no Dutch permit at all. If Publitas ever wants the role based in Amsterdam, the highly skilled migrant route is
open to me with employer support, and I am willing to discuss it. German is C1, English native, and I work CET.

One question I would ask in a first conversation: which internal process currently generates the most repeat requests,
and what would have to be true for it to become self-service? In my experience that answer names the next six months of
work better than any roadmap.

Kind regards,
#v(0.5cm)
Matt Ji
