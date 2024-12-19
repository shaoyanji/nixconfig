# nixconfig - multi-device configurations

My Nix Configurations for darwin, nixos, home-manager, and WSL (not yet).

## Installation

```bash
git clone https://github.com/shaoyanji/nixconfig.git
```

## Usage

```bash
sops -d modules/nixconfig/secrets/secrets.yaml > Taskfile.yml
task
```

### SOPS Configuration

```bash
mkdir -p ~/.config/sops/age
nix-shell -p ssh-to-age --run "ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt"
cat ~/.ssh/ssh_host_ed25519_key.pub | ssh-to-age
```
example sops.yaml from [sops-nix](https://github.com/Mic92/sops-nix):
```yaml
keys:
  - &admin_alice 2504791468b153b8a3963cc97ba53d1919c5dfd4
  - &admin_bob age12zlz6lvcdk6eqaewfylg35w0syh58sm7gh53q5vvn7hd7c6nngyseftjxl
  - &server_azmidi 0fd60c8c3b664aceb1796ce02b318df330331003
  - &server_nosaxa age1rgffpespcyjn0d8jglk7km9kfrfhdyev6camd3rck6pn8y47ze4sug23v3
creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    key_groups:
    - pgp:
      - *admin_alice
      - *server_azmidi
      age:
      - *admin_bob
      - *server_nosaxa
  - path_regex: secrets/azmidi/[^/]+\.(yaml|json|env|ini)$
    key_groups:
    - pgp:
      - *admin_alice
      - *server_azmidi
      age:
      - *admin_bob
```

## Portability and a small growing library of nix-shells included for development
