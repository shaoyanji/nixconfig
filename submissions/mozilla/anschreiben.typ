// Mozilla — Staff Software Engineer, Tools & Systems. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · github.com/shaoyanji]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Mozilla\\
Firefox Engineering, Tools & Systems

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Staff Software Engineer, Tools & Systems]
#v(0.45cm)

Dear Tools & Systems team,

the role you describe is the one I have been doing alone for five years: the systems other engineers depend on, built so
that they keep working when the person who built them is asleep. A repository that declares thirteen Linux hosts, a task
plane that replaced a drawer of shell scripts, documentation generated from the same source as the configuration, and CI
running the identical per-host check the machine runs.

Three properties matter more than the tooling, and they are what I would bring. First, *reproducibility is a property of
the repository, not a discipline of the person*: inputs pinned in a lock file, outputs addressable by content, so a
rebuild months later yields the same artefact instead of something that merely compiles today. Second, *the gate is the
same everywhere*: CI and the host run one check, so a green build cannot mean something different from a healthy machine,
and a failing check leaves the previous generation serving. Third, *the documentation is a build artefact*: hosts,
modules, tasks and decisions are generated from the source, so a stale page is a build failure rather than a slow drift
somebody discovers during an incident. That last one is the part I would most want to argue with your teams about, because
it changes what "keeping docs up to date" costs.

On the operational side I have held the pager for the same system I built: a ledger over job status, generation age, disk
pressure and PSI every fifteen minutes that pages on any state short of ok and times out on silence, because the failure
that hurts is the one that stopped reporting. That data is what I use to make arguments about capacity and cache pressure
rather than opinions, which is the closest thing I have to the telemetry-driven decisions your posting describes.

Where I am honestly short, since a staff role should be entered with clear eyes: I have not worked in a browser-scale C++
or Rust codebase, I have not run Terraform or a managed cloud platform, and JavaScript and TypeScript are not languages I
write. My build system is Nix and my deployment target is bare metal, which answers the same questions with different
machinery. Those gaps are real, and the reason I am writing is that the rest of the work — internal tooling, workflow
automation, making unfamiliar systems sustainable — is what I have chosen to do repeatedly.

I also build in the open because it is the only way the work can be checked: the repository is public, the documentation
ships with it, and a reviewer can read the decisions instead of taking my word for them. That seems close to how Mozilla
works, which is why this posting stood out.

I am based in Germany with permanent residence as a US citizen, so the remote-German location needs no sponsorship, and
German is C1 with English native. I would enjoy hearing which internal system costs Firefox engineers the most time today
— the build, the test infrastructure, or the path from a change to a running environment.

Yours sincerely,
#v(0.5cm)
Matt Ji
