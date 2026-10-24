# The release-built half of the tool library as one table: `plan` renders it into
# `library-fetch.sh` calls, so the static gate, the provenance record and the NAS
# mirror are the existing pipeline rather than a second fetcher.
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
      pick.aarch64 = "linux_arm64";
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
      pick = {
        aarch64 = "linux_arm64";
        amd64 = "linux_amd64";
      };
    };

    # GUI apps: one file, no archive, arch in the asset name, stable local name.
    zen-browser = {
      repo = "zen-browser/desktop";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "x86_64" "^aarch64"];
      name = "zen-x86_64.AppImage";
    };
    sourcegit = {
      repo = "sourcegit-scm/sourcegit";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "amd64" "^arm64"];
      name = "sourcegit-x86_64.AppImage";
    };
    imhex = {
      repo = "WerWolv/ImHex";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "x86_64"];
      name = "imhex-x86_64.AppImage";
    };
    simplex-desktop = {
      repo = "simplex-chat/simplex-chat";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "x86_64" "^arm64"];
      name = "simplex-desktop-x86_64.AppImage";
    };
    vieb = {
      repo = "Jelmerro/Vieb";
      dirs = ["appimages"];
      filters = [".AppImage" "^zsync" "^arm64"];
      name = "Vieb-x86_64.AppImage";
    };
  };

  # dir -> its library directory on the mounted root.
  dest = {
    aarch64 = "bin-aarch64";
    amd64 = "bin-x86";
    appimages = "appimages";
  };

  rows = dir: builtins.filter (n: builtins.elem dir tools.${n}.dirs) (builtins.attrNames tools);

  # eget does not filter by architecture (an aarch64 host fetched
  # `starship-x86_64` once the arm token was missing), so `pick` names the
  # substring that pins the build; `filters` keep a sidecar from matching too,
  # since two matches make eget prompt and a prompt hangs a schedule.
  argsOf = dir: n: let
    t = tools.${n};
    filters = t.filters ++ (if t ? pick then [t.pick.${dir}] else []);
  in
    builtins.concatStringsSep " " (map (a: "--asset '${a}'") filters);

  line = dir: n: let
    t = tools.${n};
    name = if t ? name then " --name '${t.name}'" else "";
  in
    "bash scripts/task/library-fetch.sh --repo ${t.repo} ${argsOf dir n} --dest ${dest.${dir}}${name} || failed=$((failed + 1))";

  plan = dir: ''
    set -u
    failed=0
    ${builtins.concatStringsSep "\n" (map (line dir) (rows dir))}
    if [ "$failed" -gt 0 ]; then
      echo "library update: $failed row(s) in ${dest.${dir}} failed" >&2
      exit 1
    fi
  '';
in {
  inherit tools plan;
}
