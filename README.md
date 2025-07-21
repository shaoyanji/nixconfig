# nixconfig - multi-device configurations

My Nix Configurations for darwin, nixos, home-manager, and WSL.

## TODO

-[ ] run `task update-sops`
-[x] add submodule for secrets
-[ ] make submodule tasks
-[ ] markdown to taskfile generator

## Installation

```bash
nixos-rebuild switch --flake github:/shaoyanji/nixconfig?submodules=1#$(hostname)
git clone thinsandy:/x/nixconfig
git clone https://$GITHUB_API_TOKEN@github.com/shaoyanji/nixconfig.git
git clone git@github.com:/shaoyanji/nixconfig.git
cd nixconfig
git submodule update --init --recursive
```

## Usage

### MACOS rebuild from scratch

```bash
Xcode install
m hostname '$(hostname)'
nix run nix-darwin -- switch --flake github:shaoyanji/nixconfig#$(hostname)
# use sops script below
ln -s .config/sops Library/Application\ Support/sops
```

### SOPS Configuration for NixOS

To add a new NixOS machine to the fleet:

```bash
mkdir -p ~/.config/sops/age
nix-shell -p ssh-to-age --run "ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt"
export AGE=$(nix-shell -p ssh-to-age --run "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age")
export HOST=$(hostname)
yq -i '.keys += (env(AGE) | . anchor = env(HOST)) | .creation_rules[0].key_groups[0].age += ((.keys[-1] | anchor) | . alias |= .)' .sops.yaml
export AGE=$(nix-shell -p ssh-to-age --run "cat ~/.ssh/id_ed25519.pub | ssh-to-age")
export USER=$(whoami)
yq -i '.keys += (env(AGE) | . anchor = env(HOST)+env(USER)) | .creation_rules[0].key_groups[0].age += ((.keys[-1] | anchor) | . alias |= .)' .sops.yaml
```

### Setting Up Home-Manager

```bash
nix run home-manager/master -- switch --flake .?submodules=1#$(whoami)
```
