# The release-binary table, in nix. `toml` renders it for eget and `fetcher`
# wraps that TOML in the command that downloads it — no TOML or download line is
# kept by hand anywhere.
#
# Two measured facts:
#   * eget 1.3.4 does not filter by arch (an aarch64 host happily fetched
#     starship-x86_64 when nothing else matched), so each row names the token
#     that pins its asset per dir. That is also why a dir's contents are only
#     right on the arch the tokens name, not the arch of the host.
#   * two matching assets make eget prompt, and prompting without a TTY fails.
let
  tools = {
    age = {
      repo = "FiloSottile/age";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz" "^proof"];
      pick = {
        aarch64 = "linux-arm64";
        amd64 = "linux-amd64";
      };
    };
    fzf = {
      repo = "junegunn/fzf";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
      pick = {
        aarch64 = "linux_arm64";
        amd64 = "linux_amd64";
      };
    };
    gh = {
      repo = "cli/cli";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
      pick = {
        aarch64 = "linux_arm64";
        amd64 = "linux_amd64";
      };
    };
    duf = {
      repo = "muesli/duf";
      # arm only: upstream ships no x86_64 tarball (just .deb/.rpm/.apk).
      dirs = ["aarch64"];
      filters = [".tar.gz"];
      pick = {
        aarch64 = "linux_arm64";
        amd64 = "linux_amd64";
      };
    };
    zoxide = {
      repo = "ajeetdsouza/zoxide";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
      pick = {
        aarch64 = "aarch64-unknown-linux-musl";
        amd64 = "x86_64-unknown-linux-musl";
      };
    };
    glow = {
      repo = "charmbracelet/glow";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz" "^sbom"];
      pick = {
        aarch64 = "Linux_arm64";
        amd64 = "Linux_x86_64";
      };
    };
    gum = {
      repo = "charmbracelet/gum";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz" "^sbom"];
      pick = {
        aarch64 = "Linux_arm64";
        amd64 = "Linux_x86_64";
      };
    };
    task = {
      repo = "go-task/task";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
      pick = {
        aarch64 = "linux_arm64";
        amd64 = "linux_amd64";
      };
    };
    lazygit = {
      repo = "jesseduffield/lazygit";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
      pick = {
        aarch64 = "linux_arm64";
        amd64 = "linux_x86_64";
      };
    };
    hugo = {
      repo = "gohugoio/hugo";
      dirs = ["aarch64" "amd64"];
      filters = ["hugo_extended_" "^withdeploy" ".tar.gz"];
      pick = {
        aarch64 = "linux-arm64";
        amd64 = "linux-amd64";
      };
    };
    sops = {
      repo = "getsops/sops";
      dirs = ["aarch64" "amd64"];
      filters = ["^sbom"];
      pick = {
        aarch64 = "linux.arm64";
        amd64 = "linux.amd64";
      };
    };
    pdfcpu = {
      repo = "pdfcpu/pdfcpu";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.xz" "^sbom"];
      pick = {
        aarch64 = "Linux_arm64";
        amd64 = "Linux_x86_64";
      };
    };
    starship = {
      repo = "starship/starship";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
      # arm ships musl only; x86 ships both, so pin gnu there.
      pick = {
        aarch64 = "aarch64-unknown-linux-musl";
        amd64 = "x86_64-unknown-linux-gnu";
      };
    };
    yq = {
      repo = "mikefarah/yq";
      dirs = ["aarch64" "amd64"];
      filters = ["^tar.gz"]; # the bare binary, not the tarball of it
      file = "yq";
      pick = {
        aarch64 = "linux_arm64";
        amd64 = "linux_amd64";
      };
    };

    # GUI apps: no archive, and the arch sits in the asset name. `target` keeps
    # the version out of the filename; every AppImage release also ships a
    # .zsync beside it.
    zen-browser = {
      repo = "zen-browser/desktop";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "x86_64" "^aarch64"];
      target = "zen-x86_64.AppImage";
    };
    sourcegit = {
      repo = "sourcegit-scm/sourcegit";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "amd64" "^arm64"];
      target = "sourcegit-x86_64.AppImage";
    };
    imhex = {
      repo = "WerWolv/ImHex";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "x86_64"];
      target = "imhex-x86_64.AppImage";
    };
    simplex-desktop = {
      repo = "simplex-chat/simplex-chat";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "x86_64" "^arm64"];
      target = "simplex-desktop-x86_64.AppImage";
    };
    vieb = {
      repo = "Jelmerro/Vieb";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "^arm64"];
      target = "Vieb-x86_64.AppImage";
    };
  };

  # EGET_CONFIG is a file, so the TOML goes through a heredoc rather than a flag.
  toml = dir: let
    row = name: let
      t = tools.${name};
      filters = t.filters ++ (if t ? pick then [t.pick.${dir}] else []);
      opt = k: if t ? ${k} then "\n${k} = \"${t.${k}}\"" else "";
    in ''
      ["${t.repo}"]
      asset_filters = [${builtins.concatStringsSep ", " (map (f: "\"${f}\"") filters)}]${opt "file"}${opt "target"}'';

    rows = builtins.filter (n: builtins.elem dir tools.${n}.dirs) (builtins.attrNames tools);
  in ''
    [global]
    quiet = false

    ${builtins.concatStringsSep "\n\n" (map row rows)}
  '';

  # cd, not just `--to`: eget extracts archives into `--to` but writes a bare
  # asset (yq, every AppImage) into the working directory.
  fetcher = dir: dest: ''
    set -eu
    mkdir -p '${dest}'
    cd '${dest}'
    cfg=$(mktemp)
    trap 'rm -f "$cfg"' EXIT
    cat > "$cfg" <<'TOML'
    ${toml dir}
    TOML
    EGET_CONFIG=$cfg EGET_GITHUB_TOKEN=''${EGET_GITHUB_TOKEN:-$(gh auth token 2>/dev/null || true)} \
      nix run nixpkgs#eget -- --download-all --to "$PWD"
  '';
in {
  inherit toml fetcher;
}
