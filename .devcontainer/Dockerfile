# syntax=docker/dockerfile:1.7

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG USERNAME=vscode

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash-completion \
    ca-certificates \
    curl \
    direnv \
    fd-find \
    git \
    jq \
    openssh-client \
    ripgrep \
    sudo \
    xz-utils \
 && rm -rf /var/lib/apt/lists/*

USER ${USERNAME}

ENV USER=${USERNAME}
ENV PATH=/home/${USERNAME}/.nix-profile/bin:/home/${USERNAME}/.local/bin:${PATH}
ENV NIX_CONFIG=experimental-features\ =\ nix-command\ flakes\naccept-flake-config\ =\ true

RUN curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon \
 && . "/home/${USERNAME}/.nix-profile/etc/profile.d/nix.sh" \
 && nix --version \
 && mkdir -p "/home/${USERNAME}/.config/nix" \
 && printf '%s\n' \
    'experimental-features = nix-command flakes' \
    'accept-flake-config = true' \
    > "/home/${USERNAME}/.config/nix/nix.conf"
