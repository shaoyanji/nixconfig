# nixconfig - multi-device configurations

My Nix Configurations for darwin, nixos, home-manager, and WSL.

## TODO

- [x] add submodule for secrets
- [x] integrated dotfiles as a submodule

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

### Installing Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Installing Nix

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
```

### Setting Up Home-Manager

```bash
nix run home-manager/master -- switch --flake
home-manager switch --flake github:/shaoyanji/nixconfig?submodules=1#$(hostname)
```

put this in `~/etc/nix/nix.conf`

```ini
experimental-features = nix-command flakes
substituters = https://cache.nixos.org/ https://nix-community.cachix.org https://cache.garnix.io https://shaoyanji.cachix.org https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g= shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0=
```

1. Generate SSH key
2. Make Age equivalents
3. Github credentials add SSH keys
4. Add Sops.yaml
5. sops updatekeys modules/secrets.yaml
