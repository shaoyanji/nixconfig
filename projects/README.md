# projects/ — one repository per project, mounted as a submodule

Every directory in this tree is a git submodule of its own repository under
`github.com/shaoyanji`. Nixconfig owns the fleet; a project owns its code, its CI and its
own history, and nixconfig only pins which commit it expects to find here.

`.gitmodules` is the registry — read it (`git submodule status`) rather than trusting a
list in prose.

## A gitlink earns its place only when something here opens the path

A submodule costs a clone step, a detached checkout and a revision nobody is watching.
That is worth paying for exactly when something in this tree reads the directory: Nix at
eval (`modules/secrets` — every host's `sopsFile` resolves into it), or a task and script
(`projects/neocities-dragoncourt` — `task neocities:*` deploys `site/` from this path and
the push runs the project's own `scripts/lint.py`).

A project that nothing here opens is not a submodule. It is a URL: register it in
`inventory.toml` under `[repos.*]` (`nix eval .#inventory.repos`) and keep its checkout
outside this tree, at `/Volumes/data/projects/<name>`. Two were withdrawn that way on
2026-11-04 — `nix-build-tracker` and `oci-always-free-demo` — because no Nix file,
workflow or task referred to either, so the pin recorded a revision nothing acted on.

The strictness is not tidiness. A submodule's contents are a **second source tree**:
`?submodules=1` and the bare git tree resolve to different source paths, and CI measured
what that split costs — frieren recompiled 34 derivations on an upgrade of a commit CI
had already built from the other one. Keep the set of paths evaluation can see small, and
never let a project directory into a closure.

## Adding a project

```bash
# in the project directory
git init -b main
git add -A && git commit
gh repo create shaoyanji/<name> --public --source=. --remote=origin --push

# in nixconfig
git submodule add https://github.com/shaoyanji/<name>.git projects/<name>
```

Before that last line, answer one question: what here opens `projects/<name>`? If the
answer is "a task, when I happen to run it from this checkout", the project belongs in
`[repos.*]` instead — a pin that only a convenience path depends on is drift waiting to
happen.

Rules that keep this honest:

- **The project's own repository is the source of truth.** A change goes there first; the
  submodule bump in nixconfig is a separate commit that says which revision the fleet is
  pinned to.
- **CI moves with the code.** A workflow whose `working-directory` points into
  `projects/<name>` belongs in that repository, not here — here it can only run against a
  checkout it does not own.
- **Tooling that needs fleet state stays in the task plane.** `projects/neocities-dragoncourt`
  is the site; `task neocities:*` and the sops-held API key live in nixconfig. The split is
  content versus credential, not convenience.
- **A fresh clone needs the submodules**: `git clone --recurse-submodules`, or
  `git submodule update --init --recursive` after the fact.
- **The pin is checked, not remembered.** `task checks:submodules` fails when any pin is
  behind the branch it tracks upstream.
