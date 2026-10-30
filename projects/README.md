# projects/ — one repository per project, mounted as a submodule

Every directory in this tree is a git submodule of its own repository under
`github.com/shaoyanji`. Nixconfig owns the fleet; a project owns its code, its CI and its
own history, and nixconfig only pins which commit it expects to find here.

`.gitmodules` is the registry — read it (`git submodule status`) rather than trusting a
list in prose.

## Adding a project

```bash
# in the project directory
git init -b main
git add -A && git commit
gh repo create shaoyanji/<name> --public --source=. --remote=origin --push

# in nixconfig
git submodule add https://github.com/shaoyanji/<name>.git projects/<name>
```

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
