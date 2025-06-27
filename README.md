# nixconfig - multi-device configurations

My Nix Configurations for darwin, nixos, home-manager, and WSL (not yet).

## Installation

```bash
git clone github:shaoyanji/nixconfig.git
git clone thinsandy:/x/nixconfig
```

## Usage

### MACOS rebuild from scratch

```bash
Xcode install
m hostname cassini
nix run nix-darwin -- switch --flake github:shaoyanji/nixconfig#cassini
# use sops script below
ln -s .config/sops Library/Application\ Support/sops
```

### SOPS Configuration

To add a new NixOS machine to the fleet:

```bash
mkdir -p ~/.config/sops/age
nix-shell -p ssh-to-age --run "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"
export AGE=$(nix-shell -p ssh-to-age --run "cat ~/.ssh/id_ed25519.pub | ssh-to-age")
export HOST=$(hostname)
yq -i '.keys += (env(AGE) | . anchor = env(HOST)) | .creation_rules[0].key_groups[0].age += ((.keys[-1] | anchor) | . alias |= .)' .sops.yaml
export AGE=$(export AGE=$(nix-shell -p ssh-to-age --run "cat ~/.ssh/id_ed25519.pub | ssh-to-age")
export USER=$(whoami)
yq -i '.keys += (env(AGE) | . anchor = env(HOST)+env(USER)) | .creation_rules[0].key_groups[0].age += ((.keys[-1] | anchor) | . alias |= .)' .sops.yaml
git add .sops.yaml
git commit -m "added $(hostname)"
git push
```
