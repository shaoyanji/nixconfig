# SOPS rekey & host identity guide

Two sops planes run on every NixOS host, and they read **different identities**.
Getting that wrong is what produces `0 successful groups` on activation.

| Plane | Module | Identity | Readable by |
| :--- | :--- | :--- | :--- |
| NixOS (root) | `modules/profiles/base-node.nix` → `sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]` | the host SSH key, live | root only |
| Home Manager (user) | `modules/sops.nix` → `sops.age.keyFile = ~/.config/sops/age/keys.txt` | an age identity **file** | the user |

The host key cannot serve the Home Manager plane: activation runs as the user and
`/etc/ssh/ssh_host_ed25519_key` is `0600 root:root`, which is why
`modules/sops.nix` has `sshKeyPaths` commented out.

`sops updatekeys` only re-wraps the **data key** for the new recipient set — values
are never re-encrypted and no secret is printed. It is cheap and safe; what it
needs is *any identity that is currently a recipient*.

## Files

| File | Decryptors | Holds |
| :--- | :--- | :--- |
| `modules/secrets.yaml` | every host (host SSH key ⇒ age) | app secrets, `hashedPassword`, API keys, TOTP (`cloak`) |
| `modules/ssh-ca-key.yaml` | the full fleet (all recipients in `.sops.yaml`) | the SSH User CA private key |

The real files live in the **`modules/secrets/` git submodule** (private
`shaoyanji/secrets`); `modules/secrets.yaml` is the tracked mirror the flake
reads, and it is a separate file from the submodule's — a `sops updatekeys` run
inside the submodule uses *that* copy. A recipient added only to one of them is
silently absent from the other: [[flake/policies.nix#secrets-submodule-declared]]

Both files are sops-encrypted in the tree — `sops:` metadata plus `ENC[AES256_GCM`
values — so a plaintext commit is a gate failure, not a review question:
[[flake/policies.nix#secrets-are-encrypted]]

## Private data that is not published

A static page publishes whatever its build reads, so there are exactly two homes
for a personal fact, and sops only serves one of them:

- **Published** — `lib/matt/*.json`, `lib/bountystash/*.json`: tracked plain JSON,
  read by `.#sites.*`. Keeping it in the repo hides nothing, because the deployed
  HTML already carries every value; and it keeps those builds free of the secrets
  submodule, which is what makes them buildable from a bare tree (CI, nixbuild, a
  clone without `--recurse-submodules`).
- **Private** — `modules/secrets/pii.yaml`, sops-encrypted in the submodule: a phone
  number, a street address, a referee. `task apps:pii:sync` decrypts it to
  `~/.config/appflow/pii.json` (mode 600, and it refuses a path inside the repo),
  `scripts/task/pii.sh get KEY` feeds one value into a document, and the value never
  reaches eval or a store path. Registering the file costs one line in `sopsFiles`
  ([[flake/policies.nix#secrets-files-are-registered]]), and the plaintext gate then
  scans it.

Never `import` or `readFile` a file under `modules/secrets/` from `lib/`: a bare tree
has no such file, so the read fails in the one environment nobody debugs. A
`pathExists` guard is not the fix either — it makes the artifact differ between a
machine that has the file and one that does not, invisibly.
[[flake/policies.nix#private-data-is-not-a-build-input]]

## Exposure gates

Every rule below is a predicate in `flake/policies.nix`, so breaking one fails
`checks.policies` instead of asking someone to remember a paragraph. Each answers
a distinct way a secret leaves the encrypted store, and each one replaces a
rotation rather than scheduling another:

| How it escapes | Gate | Instead of that |
| :--- | :--- | :--- |
| written to one copy of the pair | [[flake/policies.nix#secrets-mirror-is-a-copy]] | `task infra:secrets:sync`; never edit the mirror |
| a new encrypted file nobody scans | [[flake/policies.nix#secrets-files-are-registered]] | add its path to `sopsFiles` |
| committed into a tracked file | [[flake/policies.nix#credentials-never-land-in-a-tracked-file]] | keep the value in sops |
| baked into `/nix/store` at eval time | [[flake/policies.nix#secrets-are-not-decrypted-at-eval]] | `passwordCommand`, or activation |
| printed by a comparison | [[flake/policies.nix#decrypted-documents-are-compared-not-printed]] | `cmp -s <(sops -d a) <(sops -d b)` |
| a private fact made a build input | [[flake/policies.nix#private-data-is-not-a-build-input]] | publish only what the page renders; keep the rest in `pii.yaml` |

Two properties are deliberate, and both are about not leaking in the gate itself:
a failure names the file and line and never quotes the match, and the mirror gate
compares ciphertext, so it decrypts nothing.

### Moving a rule here

A rule earns a policy once the same mistake has cost a rotation twice. The order is
not negotiable, because each step is what makes the next one meaningful:

1. **Predicate first** — a `let` binding over the tree returning offenders as
   `file:line`: `hitsWhere`, `anyLine`, `read`, `nixUnder`. No probe, no network,
   no key.
2. **Then the entry** — `rule` (why, and what it replaces), `proof` (the files it
   reads), `holds`, `detail` (offenders, never values).
3. **Then a citation** in the page that states the procedure. An uncited policy is
   an invisible gate and `checks.policies` fails on it; a citation to a missing id
   fails too.
4. **Then delete the prose it replaced.** A rule kept in both homes drifts, and the
   doc is the copy nothing tests.

## OCI CLI credentials

`modules/sops.nix` renders `~/.oci/config` (0600) from `oci/{user,tenancy,fingerprint,region}`
and writes the private key to `~/.oci/oci_api_key.pem` (0600), so a host has a working `oci`
after activation — the same shape as `~/.aws/credentials`. Nothing in `~/.oci` is hand-made
any more, and a file left there by hand is replaced (home-manager keeps it as `.hm-bak`).

The five values are **one unit**. `fingerprint` names a specific keypair, and a fingerprint
from one pair against a key file from another authenticates as `NotAuthenticated` without
saying which half is wrong, so rotating the key replaces both — in both files:

```bash
SUB=modules/secrets/secrets.yaml        # the canonical file: edit this one
jq -Rn --rawfile k ~/.oci/oci_api_key.pem '$k | rtrimstr("\n")' \
  | sops set "$SUB" '["oci"]["api"]["key"]' --value-stdin
sops set "$SUB" '["oci"]["fingerprint"]' '"<fingerprint from the console>"'
task infra:secrets:sync     # the mirror is a copy, never a second edit
task checks:sops:drift
```

The fingerprint is the one *My profile → API keys* shows for the key, not one you compute.

## Reading & testing secrets safely (Agent recipes)

An agent reading or verifying credentials must never print plaintext into transcripts or write unencrypted files to tracked paths:
[[flake/policies.nix#credentials-never-land-in-a-tracked-file]]

### 1. Extract a single secret value
Never pipe `sops -d` to `grep`, `head`, or `diff`. Use `--extract` with JSON-path notation to read only the target key:

```bash
# Read key directly into a variable without logging plaintext
token=$(sops -d --extract '["alwaysdatatoken"]' modules/secrets.yaml 2>/dev/null)
```

### 2. In-memory validation pattern (Python)
When testing credentials (IMAP, SMTP, REST APIs) against remote endpoints, keep extraction inside process memory:

```python
import subprocess, imaplib

pw = subprocess.run(
    ["sops", "-d", "--extract", '["alwaysdataemail"]', "modules/secrets.yaml"],
    capture_output=True, text=True, check=True
).stdout.strip()

with imaplib.IMAP4_SSL("imap-dragoncourt.alwaysdata.net", 993) as M:
    M.login("dragoncourt@alwaysdata.net", pw)
    status, count = M.select("INBOX")
```

### 3. Setting a secret and updating the mirror
Always edit the submodule canonical source, then synchronize the mirror:

```bash
sops set modules/secrets/secrets.yaml '["key"]' '"value"'
task infra:secrets:sync
task checks:sops:drift
```

If an operator edited `modules/secrets.yaml` directly, adopt the mirror into the submodule before running checks or sync:

```bash
cp -f modules/secrets.yaml modules/secrets/secrets.yaml
```

## SSH CA

Servers trust one CA public key (`modules/ssh-ca.nix`); `ssh.ca.enable = true` is
inherited from `modules/profiles/base-node.nix`. Workstations sign 1-week user
certs with `rotate-ssh-cert`, which reads the CA key from sops-nix at
`~/.ssh/user_ca_key`. After the CA is in place there is no `authorized_keys`
management at all — and no other path should grow one:
[[flake/policies.nix#ssh-ca-declarative]]

Exactly one key list survives, because a CA does not help the first login:
`modules/config/authorized-keys.nix`, rendered into every flake-managed host as
`config.ssh.authorizedKeys.keys`. A host that pastes its own `ssh-ed25519`
literal is regrowing the thing the CA replaced:
[[flake/policies.nix#ca-only-user-access]]

**Bootstrap is outside the model.** The first connection to bare metal is a USB
ISO or a temporary password; only then can the host key be enrolled as a
recipient.

## Anchors in `.sops.yaml`

```yaml
keys:
  - &frieren    age1rt9…   # USER ssh key  (~/.ssh/id_ed25519)  → ssh-to-age
  - &frierenhost age1njr…  # HOST ssh key  (/etc/ssh/ssh_host_ed25519_key)
```

Convention: `&<host>` is the user's key, `&<host>host` is the host's key. **`delphi`
is the exception** — it has one anchor, `&delphi`, and it is the *host* key
(`age1fg8xy2g5nrxsah45upvzl8eq9u7vy36e6dsw6pg5j9rfmh5qhe7sn6j4jp`), because the
fleet logs in with SSH CA certificates and delphi has no `~/.ssh/id_ed25519`
at all.

Anchors are **cosmetic**: recipients are stored by value inside each encrypted
file, so renaming an anchor changes nothing until the next `sops updatekeys`.
Only the `key_groups` list decides who can decrypt.

## A host with no user keypair (ca-only hosts, cloud VMs)

Do not copy another host's `keys.txt` onto it — that hands the box every secret
for no reason. `ssh-to-age` is deterministic, so derive the user-plane identity
from the host key that already exists:

```nix
# hosts/<host>/configuration.nix
imports = [ ../../modules/profiles/sops-user-identity.nix ];
profiles.sopsUserIdentity.enable = true;
```

The activation writes `~/.config/sops/age/keys.txt` from
`/etc/ssh/ssh_host_ed25519_key`, so the identity is **exactly** the `&<host>`
recipient already listed — no new recipient, no rekey, and nothing to back up
(losing the disk loses the secrets anyway, and the host is reinstalled).

Do **not** enable it on `frieren`, `fern`, `scratch`, `poseidon` or `netbook`:
they use the TPM identity path and read `tpm-identity.txt` instead.

## TPM-sealed identity (`frieren`, `fern`, `scratch`, `poseidon`, `netbook`)

An `age-plugin-tpm` identity is a **key sealed by the chip**: the file is only
the handle, so it decrypts on that machine and nowhere else. Verified
2026-10-22 against the pinned toolchain (sops 3.13.3, age-plugin-tpm 1.0.1):
`sops encrypt --age age1tag1…`, `sops updatekeys`, and `sops decrypt` with
`SOPS_AGE_KEY_FILE=…/tpm-identity.txt` all succeed, so a plugin recipient is a
normal recipient to sops.

Order matters — the chip must be usable before the identity exists, and the
identity must be a recipient before either plane reads it. On `netbook` the
identity belongs to user **`alice`** (not `devji`), and no sops-nix plane is
wired there: step 4 is skipped, so the sealed key is used only by hand. It is
named `tpm-identity-netbook.txt` with `keys.txt` symlinked to it, so a bare
`sops -d` finds the chip with no env var and no `keyFile` to configure.

```bash
# 1. Capability first: deploy security.tpm2.enable, devji in `tss`, and
#    pkgs.age-plugin-tpm/tpm2-tools. Leave sops.age.keyFile on the default;
#    pointing it at a file that does not exist yet only breaks activation.

# 2. Generate ON the host, as the user — /dev/tpmrm0 is root:tss 0660, and a
#    fresh group membership needs a new session (`sg`, or re-login).
ssh <host> 'sg tss -c "age-plugin-tpm --generate -o \$HOME/.config/sops/age/tpm-identity.txt"'
ssh <host> 'chmod 400 ~/.config/sops/age/tpm-identity.txt'
ssh <host> 'age-plugin-tpm -y ~/.config/sops/age/tpm-identity.txt'   # → recipient
```

The default recipient type is **p256tag** (`age1tag1…`), which is what this
fleet uses; `--tpm-recipient` produces the older `age1tpm1…` form. Use the
default, and register the recipient as `&tpm<host>` (existing: `&tpmfrieren`,
`&tpmfern`, `&tpmscratch`, `&tpmposeidon`, `&tpmnetbook`).

```bash
# 3. Register + rekey exactly as below (anchor, key_groups, submodule copy,
#    sops updatekeys on every file, mirror back, drift check).

# 4. Only now point both planes at it:
#    modules/sops.nix   tpmHosts += the host AND
#                       age.plugins = lib.optional useTpm pkgs.age-plugin-tpm;
#    hosts/<host>       sops.age = {
#                         keyFile = "<home>/.config/sops/age/tpm-identity.txt";
#                         sshKeyPaths = lib.mkForce [];   # no SSH-derived recipient
#                         plugins = [pkgs.age-plugin-tpm]; # system activation PATH
#                       };
```

Both planes read the **same** file: root can read the user's `0400` handle. Each
plane needs the plugin for its own reason: on the system plane `sops.age.plugins`
builds the activation `PATH`, and on the user plane sops-nix sets the unit's
`Environment=PATH=` to *exactly* that list — so a TPM host that omits it starts
`sops-nix.service` with an empty PATH and dies with `0 successful groups
required, got 0`, while the identical command by hand succeeds. `home.packages`
is not a substitute: the unit does not inherit the login PATH.

`tss` is per **session**: the deploy that adds the user to the group does not
change the already-running `systemd --user` manager, so the first user-plane
activation still fails until that manager restarts (reboot). `id -nG` in a fresh
ssh session showing `tss` is not proof the manager has it.

A host whose only recipient is the TPM has no fallback — clearing or replacing the
chip loses the secrets, which is the accepted trade for keeping nothing
exportable on disk. `poseidon` deliberately keeps both doors: the TPM identity
covers the user plane, while its SSH host key (`&hposeidon`) stays a recipient
for the root plane and manual recovery.

## Add a recipient to an existing host (the normal rekey)

```bash
# 1. Derive the new recipient ON the host that owns the key
ssh <host> 'sudo cat /etc/ssh/ssh_host_ed25519_key.pub' \
  | nix run nixpkgs#ssh-to-age                       # → &<host>host
ssh <host> 'cat ~/.ssh/id_ed25519.pub' \
  | nix run nixpkgs#ssh-to-age                       # → &<host>

# 2. Register it: add the anchor under `keys:` AND `- *<anchor>` to
#    creation_rules[0].key_groups[0].age   (YAML edit, not sed)

# 3. Sync the copy the secrets submodule reads. `modules/secrets/.sops.yaml`
#    is a SEPARATE file: `sops updatekeys` run inside the submodule uses the
#    submodule's copy, and a stale copy silently re-wraps to the OLD set.
cp -f .sops.yaml modules/secrets/.sops.yaml

# 4. Re-wrap the data key in every file
sops updatekeys modules/secrets/*.yaml
sops updatekeys modules/ssh-ca-key.yaml

# 5. Mirror back into the repo (modules/secrets.yaml is a tracked copy)
task infra:secrets:sync

# 6. Prove it, do not assume it
scripts/task/sops-drift-check.sh        # recipients == .sops.yaml, all decrypt
sops -d modules/secrets.yaml > /dev/null
```

`task infra:sops:update-keys` runs steps 3–5 **and commits + pushes the private
`modules/secrets` submodule**. Use it when that is intended; otherwise the
explicit commands above are the same work without the push.

## A brand-new host

Order matters: sops recipients must exist **before the first activation**, or
`sops-install-secrets` fails and the install aborts (`nixos-anywhere` then leaves
you on a wiped, formatted disk).

1. Derive the recipient from the host key the image already has:
   `ssh … 'sudo cat /etc/ssh/ssh_host_ed25519_key.pub' | nix run nixpkgs#ssh-to-age`
2. Add it to `.sops.yaml` (anchor + `key_groups`), sync the submodule copy, rekey.
3. Add any host-specific secrets (e.g. a `TELEGRAM_BOT_TOKEN` **per host** — two
   pollers on one token fight).
4. `nixos-anywhere` with `--extra-files` carrying `/etc/ssh/ssh_host_*` across the
   wipe, so the post-install host key is the one you registered.
5. If the host has no user keypair, enable `profiles.sopsUserIdentity` (above).

## Verify on the host

**Decrypt the store copy, not the checkout.** `sops -d modules/secrets.yaml` proves
that *some* identity can read *some* file in a working tree that may be stale, on a
host whose task plane may be a different checkout entirely. What activation reads is
`/nix/store/<hash>-secrets.yaml`, named by the manifest the unit executes:

```bash
# The user unit's ExecStart is a sops-nix-generated SCRIPT; the manifest is inside it.
# `--value` prints a struct (`{ path=/nix/store/… ; argv[]=… }`), so parse `path=`.
SCRIPT=$(systemctl --user show sops-nix -p ExecStart --value \
  | sed -n 's/.*path=\([^ ;]*\).*/\1/p')
MANIFEST=$(grep -o '/nix/store/[a-z0-9]*-manifest[a-z-]*\.json' "$SCRIPT")
echo "script=$SCRIPT manifest=$MANIFEST"
grep -o '/nix/store/[a-z0-9]*-secrets\.yaml' "$MANIFEST" | sort -u   # ← activation reads this

# both planes, against that store path (identical digests = both read the same file)
STORE=/nix/store/<hash>-secrets.yaml
SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/tpm-identity.txt sops -d "$STORE" | sha256sum
sudo env SOPS_AGE_KEY_FILE=/home/<user>/.config/sops/age/tpm-identity.txt \
  PATH=<age-plugin-tpm>/bin:$PATH sops -d "$STORE" | sha256sum

# negative control — with no identity it MUST fail, or a stale keys.txt is doing
# the work and the chip is untested. Pointing SOPS_AGE_KEY_FILE at a nonexistent
# path is NOT a control: sops then falls back to ~/.config/sops/age/keys.txt and
# still succeeds (measured on netbook). Hide the handles instead.
D=$HOME/.config/sops/age; mkdir -p /tmp/hidden
mv "$D"/keys.txt "$D"/tpm-identity*.txt /tmp/hidden/ && sops -d "$STORE" >/dev/null; echo $?  # 128
mv /tmp/hidden/* "$D"/
```

Then the units and the material they were supposed to install:

```bash
systemctl --user show sops-nix -p Result -p ExecMainStatus   # success / 0
sudo ls -l /run/secrets-for-users/                           # hashedPassword present
journalctl -u home-manager-<user> -n 20                      # no "0 successful groups"
SOPS_AGE_KEY_FILE=… sops -d "$STORE" | sha256sum             # == the pulled checkout's
```

## Traps

- **`0 successful groups`** — the identity is not a recipient. Derive the pubkey
  and compare it against `.sops.yaml`; do not add a file at random.
- **A detached checkout eats commits.** `git submodule update` checks out the
  pinned commit, never a branch, so a commit made in `modules/secrets` after it
  belongs to no branch and the next update drops it. `.gitmodules` names
  `branch = master`, `task dev:git:quick-pull` re-attaches the checkout after
  every update, and `git -C modules/secrets branch --show-current` printing
  nothing means it is detached again.
- **A recursive fetch aborts the pull.** `submodule.recurse` is off fleet-wide;
  `git pull --recurse-submodules` on a host without the private ssh key fails the
  whole pull, superproject included.
- **The submodule `.sops.yaml`** — `modules/secrets/.sops.yaml` is a copy. Forgetting
  step 3 re-wraps to the old set and the file still decrypts for you, so it looks fine
  until a host that was just added cannot decrypt.
- **New recipients do not propagate backwards.** Adding a recipient does nothing to
  existing files until `sops updatekeys` runs on each one.
- **Mirrors drift.** `modules/secrets.yaml` is a tracked mirror of
  `modules/secrets/secrets.yaml`, and the copy is a gate rather than a habit:
  [[flake/policies.nix#secrets-mirror-is-a-copy]].
- **A store copy is not a checkout.** On a host where `~/Documents/nixconfig` is a
  home-manager store symlink, `git rev-parse` there reports the *generation's* commit,
  not what you pulled — and it cannot be pulled at all. The clone is elsewhere
  (`~/nixconfig` on scratch); see `.agents/deploy/hosts/scratch.md`.
