# Dossier — Obsidian Systems, Functional Software Engineer

Retrieved and reconstructed: 22 November 2026
Application sent: 21 November 2026, via Ashby
Location: remote, USA East Coast
Compensation stated in the application: USD 150–180k

## 1. What exists, and what does not

The application was submitted on 21 November 2026 through the Ashby form. The database row `obsidian-systems-functional-software-engineer` recorded `applied`, with no folder path.

The repository has no `submissions/obsidian/` directory until this packet created one, and never had one: `git log --all -- 'submissions/obsidian*'` is empty, and no `Matt_Ji_Resume_Obsidian.pdf` or any other `*Obsidian*` path appears in the history. The pre-Typst files this task was meant to retire do not exist and were never committed, so there is nothing to move into history and no hashes to record.

What this packet is, then: the archived record of an application that went out without one. The CV uploaded to Ashby was tailored and is not preserved (`resumeUrl` and `folderPath` were both empty), so this CV is rebuilt from the same canonical source the site renders from, `lib/matt/resume.json`. It documents the application; it cannot be byte-identical to what was uploaded.

## 2. The role

Obsidian Systems is a software engineering consultancy for capital markets and regulated industries: market infrastructure providers, national exchanges, global financial institutions. Much of the current work is on the **Canton Network**, a privacy-enabled blockchain, and Obsidian is one of the more experienced engineering firms in that ecosystem.

The posting asks for functional programming principles, strong typing and domain modelling, composable abstractions, automated tests, and the judgement to trade correctness against simplicity and performance. Preferred: Haskell, Scala, OCaml, F#, Clojure; type systems, algebraic data types, pattern matching, immutable data; distributed or concurrent systems; blockchain, financial infrastructure or capital markets; property-based testing; **Nix or reproducible development environments**; consultancy or direct client collaboration.

It is a Haskell shop. That sentence is the whole fit question, and the packet is built around saying so rather than around it.

## 3. Where the functional claim actually rests

The brief for this packet asked for grounding in "hands-on functional Nix flake architecture, piece table implementation, and declarative systems automation". Two of the three are supported by the record and are in the CV. The third is not, and was not used:

- **Piece table.** No piece table, gap buffer, rope or CRDT exists anywhere in this repository, in `lib/matt/resume.json`, or in any project description. Writing one into a CV for a role that reads code would be the one claim most likely to end a conversation. Omitted. What is real in the same territory is fibtransponder: a Fibonacci-radix state machine with bounded work per step, a corpus benchmark that falsified the first design, and the counter-example left in the repository.
- **Functional Nix flake architecture.** Supported, and described in the terms the role uses. A flake is a function from pinned inputs to a machine. Hosts are feature lists, services are modules, module options carry types, evaluation is lazy, and the expression CI evaluates is the expression the machine builds. Thirteen hosts, one repository, secrets encrypted per host, certificates from the fleet's own SSH certificate authority, rollback by generation.
- **Declarative systems automation across the fleet.** Supported: the module gate, the pinned inputs, the reproducible builds, the sentinel ledger of job status, generation age, disk and PSI pressure every fifteen minutes, and alerting that confirms delivery.

The immutable-data requirement is met in Go rather than in a functional language: bountystash turns a request into an immutable, content-addressed specification with an append-only event log, so a job replays a month later. Content addressing and event sourcing are the same ideas the role uses under different names.

## 4. Correctness where money moves

The role's domain is capital markets; the record's domain is energy. The overlap is the standard, not the market:

- Yield and valuation models for a solar portfolio above USD 100M at O3 Energy, which passed bank audits.
- Options and hedging models on weather derivatives, plus gas storage and swing-trading risk for EWE Trading, as a consultant at Bountystash.
- A portfolio of USD 4–5M projects handled with clients, banks and deal brokers.

That is financial infrastructure with a counterparty on the other end, and the letter says plainly that Canton is a different market.

## 5. Gaps, stated not implied

| Requirement | Status |
| :--- | :--- |
| 5+ years production software | Met: 2020–2025 building and running the service and the fleet |
| Functional programming, professional or substantial projects | Partly: the Nix module system and immutability in Go; no functional language |
| Haskell, Scala, OCaml, F#, Clojure | **Absent** |
| Type systems, algebraic data types, pattern matching | Partly: typed module options, Go and Rust-style modelling by hand; no ADT-native language |
| Distributed or concurrent systems | Partly: multi-host fleet, services, Tailscale; no consensus or cluster work |
| Blockchain, capital markets | **Absent**: Daml and Canton not used; energy trading instead |
| Property-based testing | **Absent**: benchmarks and corpus falsification, which is not the same technique |
| Nix or reproducible environments | Strong: this is the stack, and it is a preferred requirement |
| Consultancy, direct client work | Met: Bountystash was an advisory practice; O3 work involved banks and brokers |

## 6. Why Nix is a fair answer to "functional programming"

The posting allows functional experience "either professionally or through substantial projects". Nix is a lazy, pure functional language with a type system in its module layer, and thirteen hosts declared in it is a substantial project. The honest limit: writing Nix is not writing Haskell. Its evaluation model teaches the same discipline — no mutation, composition over inheritance, types as the contract, the value is the artifact — but the ecosystem, the compiler feedback and the debugging experience are different, and the letter says the language itself would be months.

## 7. Route and status

Already submitted through Ashby on 2026-11-21:
`https://jobs.ashbyhq.com/obsidiansystems/0a44c74d-4519-4cce-9596-dd75c5ecbdd5/application`

The posting was still live on 2026-11-22 (published 2026-10-20, HTTP 200). No cover letter was required by the form, so this one is material for a reply or an interview rather than a second submission.

## 8. Compensation

USD 150–180k, the range given in the Ashby form and repeated once in the letter. The posting publishes no band; Ashby lists no compensation for this role.

## 9. Risks

- **The language gap is the whole application.** A consultancy selling Haskell engineers will weight it heavily, whatever the "willingness to learn" line says.
- **Remote, USA East Coast.** The CET base gives a partial overlap; the letter states the overlap rather than pretending to a US timezone.
- **Reconstruction.** This packet cannot prove what was uploaded on 21 November. If a recruiter compares, the two CVs will differ in wording.
- **Duplication risk.** Nothing here should be submitted as a second application; it is a record and an interview document.

## 10. Next steps

1. Wait for the Ashby response; no follow-up before two weeks.
2. If an interview comes, lead with the Nix flake architecture and fibtransponder, and name the Haskell gap before it is asked about.
3. If it closes, move the row to `other` with the reason, so the same role is not re-entered next quarter.
4. Certificates are still missing across the whole set of packets, including this one.
