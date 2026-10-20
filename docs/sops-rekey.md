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

## A host with no user keypair (CA-only hosts, cloud VMs)

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

Do **not** enable it on `frieren` or `fern`: they use the TPM identity path
(`modules/sops.nix` `tpmHosts`) and read `tpm-identity.txt` instead.

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

```bash
sudo systemctl status sops-nix                     # NixOS plane
ls -l ~/.config/sops/age/keys.txt                  # 0600, owned by the user
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt   # pubkey
sops -d modules/secrets.yaml > /dev/null && echo "user plane OK"
journalctl -u home-manager-<user> -n 20            # no "0 successful groups"
```

## Traps

- **`0 successful groups`** — the identity is not a recipient. Derive the pubkey
  and compare it against `.sops.yaml`; do not add a file at random.
- **The submodule `.sops.yaml`** — `modules/secrets/.sops.yaml` is a copy. Forgetting
  step 3 re-wraps to the old set and the file still decrypts for you, so it looks fine
  until a host that was just added cannot decrypt.
- **New recipients do not propagate backwards.** Adding a recipient does nothing to
  existing files until `sops updatekeys` runs on each one.
- **Mirrors drift.** `modules/secrets.yaml` is a tracked mirror of
  `modules/secrets/secrets.yaml`. `task infra:secrets:sync` is the only correct way
  to refresh it; `checks:quick` includes the drift check for exactly this.
