---
name: tpm-sops
description: "Pick me when a host's sops planes should unseal through its TPM 2.0 chip (age-plugin-tpm) instead of an SSH-derived key: the two-rebuild order, identity generation, recipient rekey, and the checks that prove both planes decrypt."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['sops', 'tpm', 'secrets', 'age', 'rekey', 'nixos']
    related_skills: ['infra', 'checks', 'nixos-deploy']
---

# tpm-sops — the chip is the identity, and the order is the whole job

A TPM-backed age identity is a **sealed handle**, not a key you can copy: the file
is 531 bytes of plugin metadata and only that machine's chip can use it. That is
why the sequence cannot be reordered — the chip must be usable before the identity
exists, and the identity must already be a recipient before any plane reads it.

The failure this skill prevents: pointing `sops.age.keyFile` at
`tpm-identity.txt` in the *same* switch that installs `age-plugin-tpm`. The file
does not exist yet, `sops-install-secrets` fails, `switch-to-configuration` exits
non-zero (4 when home-manager's unit fails too), and the deploy reports FAILED
while the system partly activated — which reads like a config bug and is not one.

## The two planes, one identity

| Plane | Where | Identity |
| :--- | :--- | :--- |
| NixOS (root) | `hosts/<host>/configuration.nix` → `sops.age` | `…/tpm-identity.txt` + `sops.age.plugins` |
| Home Manager | `modules/sops.nix` → `tpmHosts` | same file (root can read the user's `0400` handle) |

`base-node.nix` gives every host `age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]`.
A TPM host that should have **no** SSH-derived recipient must force that empty in
the host module; leaving it produces a `0 successful groups` on the root plane and
an SSH-key recipient nobody registered. See `docs/sops-rekey.md` § *TPM-sealed
identity* for the incident this came from.

## Rebuild A — capability only

Nothing in this rebuild may reference the identity. It installs the chip plumbing:

```nix
# hosts/<host>/configuration.nix
security.tpm2 = { enable = true; tctiEnvironment.enable = true; };
users.users.<user>.extraGroups = ["tss"];   # /dev/tpmrm0 is root:tss 0660
environment.systemPackages = with pkgs; [age-plugin-tpm tpm2-tools];
```

Build, deploy, then prove the chip answers before touching anything secret:

```bash
task infra:deploy:host:<host>                 # or the warm + activate pair
ssh <host> sudo tpm2_getcap properties-fixed | head -5
ssh <host> 'sudo systemd-cryptenroll --tpm2-device=list'   # optional sanity
```

`tss` membership applies to **new** sessions; the generation step below uses
`sg tss` (or re-login) rather than assuming the current session picked it up.

## Generate the identity on the host

```bash
ssh <host> 'mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age'
ssh <host> 'sg tss -c "age-plugin-tpm --generate -o \$HOME/.config/sops/age/tpm-identity.txt"'
ssh <host> 'chmod 400 ~/.config/sops/age/tpm-identity.txt'
ssh <host> 'age-plugin-tpm -y ~/.config/sops/age/tpm-identity.txt'   # → age1tag1…
```

- The default recipient type is **p256tag** (`age1tag1…`) and it is what the fleet
  uses. `--tpm-recipient` produces the older `age1tpm1…` form — do not mix them.
- A PIN is not used: activation cannot type one. `AGE_TPM_PIN` exists but leaks
  through `/proc/$PID/environ`, so it is not a declarative option.
- Never copy another host's `tpm-identity.txt` onto the box: the sealed blob is
  chip-bound, so it fails, and it hands over nothing but confusion.

## Register the recipient and rekey

Anchor convention is `&tpm<host>` (`tpmfrieren`, `tpmfern`). Edit `.sops.yaml`
(anchor under `keys:`, `- *tpm<host>` under `creation_rules[0].key_groups[0].age`),
then let the task do the copy-and-rekey — `modules/secrets/.sops.yaml` is a
**separate file** and a stale copy silently re-wraps to the old set:

```bash
task infra:sops:update-keys        # copies .sops.yaml → submodule, updatekeys all
                                   # files, mirrors modules/secrets.yaml back,
                                   # commits+pushes the private submodule
scripts/task/sops-drift-check.sh   # recipients == .sops.yaml, every file decrypts
```

`sops updatekeys` only re-wraps the data key; it needs **any** identity that is
currently a recipient (the workstation's own), not the new one.

## Rebuild B — point both planes at the identity

```nix
# modules/sops.nix
age.plugins = lib.optional useTpm pkgs.age-plugin-tpm;   # user plane

# hosts/<host>/configuration.nix
sops = {
  age.keyFile = "<home>/.config/sops/age/tpm-identity.txt";
  age.sshKeyPaths = lib.mkForce [];             # no SSH-derived recipient
  age.plugins = [pkgs.age-plugin-tpm];          # system plane
};
```

`sops.age.plugins` is **not** cosmetic on either plane. sops-nix sets the user
unit's `Environment=PATH=` to *exactly* the plugin list, so without it the unit
starts with an empty PATH and the unseal fails as `0 successful groups required,
got 0` — while the same command run by hand succeeds. `home.packages` does not
reach the unit: the unit does not inherit the login PATH. On the system plane the
activation `PATH` is likewise built from this list.

## Prove it — do not infer it from a green switch

**Decrypt the store copy.** The unit reads a `/nix/store/<hash>-secrets.yaml` named by
its manifest; a `sops -d` against a working-tree copy proves that *some* identity can
read *some* file, which is not the question and can be a different checkout entirely.

The system plane's activation script names its manifest directly, so ask it:

```bash
# ExecStart is a sops-nix-generated script holding the manifest path; --value emits a
# struct, so parse `path=` rather than awk-ing the first field.
ssh <host> 'S=$(systemctl --user show sops-nix -p ExecStart --value \
  | sed -n "s/.*path=\([^ ;]*\).*/\1/p"); \
  M=$(grep -o "/nix/store/[a-z0-9]*-manifest[a-z-]*\.json" "$S"); \
  grep -o "/nix/store/[a-z0-9]*-secrets\.yaml" "$M" | sort -u'
```

Then decrypt that path on both planes and require the **same digest**:

```bash
STORE=/nix/store/<hash>-secrets.yaml
# user plane
SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/tpm-identity.txt sops -d "$STORE" | sha256sum
# root plane, plugin-only PATH (what `sops.age.plugins` builds)
sudo env SOPS_AGE_KEY_FILE=/home/<user>/.config/sops/age/tpm-identity.txt \
  PATH=/nix/store/<hash>-age-plugin-tpm-<ver>/bin:$PATH sops -d "$STORE" | sha256sum
# negative control: no identity must FAIL (128 "get the data key"), or something
# else is decrypting and the chip is untested
SOPS_AGE_KEY_FILE=/nonexistent sops -d "$STORE" >/dev/null; echo $?
```

A stale `~/.config/sops/age/keys.txt` is why the negative control is not optional: it
survives a TPM migration, is not a recipient any more, and still makes a careless
check look green. Compare its public half (`age-keygen -y`) against the recipient list
and delete it if it is not one.

```bash
# the units and the material they were supposed to install
ssh <host> 'systemctl --user show sops-nix -p Result -p ExecMainStatus'   # success / 0
ssh <host> 'systemctl --user show sops-nix -p Environment'   # PATH must be the plugin
ssh <host> 'sudo ls -l /run/secrets-for-users/'              # hashedPassword present
ssh <host> 'systemctl is-failed home-manager-<user>'

A clean `switch-to-configuration` is not the proof — the system can switch with a
failing `sops-nix` and exit 4. The proof is the secret material existing and the
previously-failed units being active.

## Traps, each one paid for

- **One rebuild cannot both install the plugin and reference the identity.** Two
  rebuilds, in this order, or activation fails in a way that looks like a bug.
- **The user unit's PATH is the plugin list, not the login PATH.**
  `systemctl --user show sops-nix -p Environment` printing `PATH=` is the whole
  diagnosis; add the plugin to `sops.age.plugins` at the module that builds the
  unit (Home Manager), not to `home.packages`. Measured on frieren: TPM identity
  only with an empty PATH → exit 128, same identity with the plugin on PATH → exit 0.
- **A leftover software `keys.txt` hides the fault.** sops falls back to it, so a
  host with a stale recipient in `~/.config/sops/age/keys.txt` reports success while
  the chip is never used. Judge the unit by `Environment=` + `Result=`, not by a
  successful `sops -d` in the shell.
- **`tss` is per session, not per host.** The first deploy adds the user to the
  group; the *already-running* `systemd --user` manager keeps the old groups, so
  the user plane stays failed until that manager restarts (reboot or
  `systemctl restart user@<uid>`). Verify with `id -nG` inside a new ssh session,
  and expect the first user-plane failure after the group change.
- **`0400` owned by the user, not root.** Root reads it anyway; the user plane
  cannot read a root-owned file. `sops-install-secrets` copies it to
  `/run/secrets-for-users.d/*/age-keys.txt` for the user unit, which is why root can
  unseal a file the user owns.
- **Verify against the store path, not a checkout.** On scratch `~/Documents/nixconfig`
  is a home-manager store symlink: `git rev-parse` there reports the generation's
  commit and cannot be pulled, while the real clone sits at `~/nixconfig`. Both were
  read in one run and produced two different answers to "what commit is deployed".
- **The submodule `.sops.yaml`** — copy it first (`update-keys` does) or the rekey
  targets the old recipient set and only the new host notices, later.
- **`modules/secrets.yaml` is a mirror.** Rekey inside `modules/secrets/`, then
  mirror back; `checks:quick`'s drift check is the gate.
- **A TPM-only host has no fallback.** Clearing the chip loses the secrets. That is
  the accepted trade; say so in the host card instead of quietly adding an SSH
  recipient.
- **Upstream noise:** the sops issue claiming `p256tag` recipients are unsupported
  is stale for the pinned versions. Verified 2026-10-22 — sops 3.13.3 (age 1.3.2)
  encrypts, `updatekeys` and decrypts with `age1tag1…` recipients:

  ```bash
  echo 'a: 1' > /tmp/t.yaml
  sops encrypt --age age1tag1… /tmp/t.yaml        # exit 0
  SOPS_AGE_KEY_FILE=~/.config/sops/age/tpm-identity.txt sops decrypt modules/secrets.yaml
  ```

## Ledger

- `frieren` — first TPM host (`&tpmfrieren`), 2026-10.
- `fern` — second (`&tpmfern`), AMD fTPM.
- `scratch` — third (`&tpmscratch`), 2026-10-22; also the first host where the
  system plane (not just Home Manager) was moved to the chip. The run cost two
  faults worth keeping: the user unit's empty `PATH` (see above) and the stale
  `systemd --user` group list, both of which look like "the identity is not a
  recipient" and are neither.

## Related

`infra` (deploy flow), `checks` (drift gate), `nixos-deploy` (build-vs-switch
tiers). Contract and full procedure: `docs/sops-rekey.md`.
