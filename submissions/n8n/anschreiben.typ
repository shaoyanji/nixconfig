// n8n — infrastructure letter (live req: Staff Platform Engineer, Agentic Engineering).
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
n8n\\
Platform Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Staff Platform Engineer, Agentic Engineering]
#v(0.45cm)

Dear Platform team,

n8n ships software that runs on other people's machines. Community edition operators install it, upgrade it, and discover
your release notes with their own workflows in production — which makes the deployment path part of the product, not
documentation hanging off it. That is the side of infrastructure I have spent five years on.

My fleet is thirteen Linux hosts declared in one repository: services as modules, every input pinned, deployment a rebuild
rather than an edit on a running machine, and rollback a pointer to the previous generation. A gate runs identically in CI
and on the target host, so a green build cannot mean something different from a healthy machine. Operations sit behind one
entry surface with validation and help text, because the alternative is an operator improvising a half-step at the worst
moment. On top of that a ledger records job status, generation age, disk pressure and PSI every fifteen minutes and pages
on any state short of ok, timing out on silence itself; a fleet that stops reporting is the failure nobody gets told about.

The isolated-execution problem in your posting is one I have built against at a small scale and care about. Runs get a
window, a memory cap and a named owner, teardown is owned by the same declaration that created the job, and the work that
must not touch anything else boots a declared microVM with its own kernel boundary. A run that leaks state is not a bug you
notice at the time; it is a capacity bill four weeks later, which is why I instrument the cleanup rather than trusting it.

What I am short of, plainly: I have not run Docker or Kubernetes in production, since my hosts are NixOS and my
orchestration is systemd; I have not worked in a TypeScript codebase; and my scale is thirteen machines rather than the
fleet behind n8n Cloud. The judgement about what to gate, what to isolate and what to leave alone transfers. The tooling
and the language would be new.

One practical note worth reading before anything else: your form allows one application per fifteen days and no re-apply to
the same role for ninety days, and I have prepared this packet rather than sent it. I also have not used n8n in anger yet —
I would rather build a workflow and answer that question honestly than claim a year of experience I do not have.

I am based in Germany with permanent residence as a US citizen, so there is no sponsorship question, German is C1 and
English native, and Berlin hybrid suits me. I would enjoy talking about how you decide what an agent-run job is allowed to
touch, since that is the design question under most of the interesting work here.

Yours sincerely,
#v(0.5cm)
Matt Ji
