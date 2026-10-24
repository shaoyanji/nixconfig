# The tool list, in nix, rendered into eget TOMLs at use time.
#
# One row per project: the repo it releases from, the asset filters that single
# out the wanted file, and which dirs it belongs in. The TOMLs are generated
# (`nix eval --raw --impure --expr '(import ./tools/eget.nix).aarch64'`), so
# there is no second copy to drift and adding a tool is one row.
#
# Why a table and not just `nixpkgs`: these binaries are for the NAS and for
# machines that cannot run nix, and eget fetches the artifact upstream publishes
# instead of building it. Tools with no prebuilt release are NOT here — those go
# through tools/bin-farm (pkgsStatic on delphi).
#
# Two facts that shape the rows, both measured:
#   * eget 1.3.4 follows the running system; `--system` does not cross-compile
#     (13/13 entries still came back arm64 on an x86 request), so the arch of a
#     generated file is the arch of the host that runs it.
#   * two matching assets make eget prompt, which is a hard failure with no TTY,
#     hence the `^sidecar` filters.
let
  # dir: which target the row lands in. A row may appear in several.
  # filters: ANDed substrings; a leading ^ excludes.
  tools = {
    age = {
      repo = "FiloSottile/age";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz" "^proof" "^sha256"];
      # The tarball also carries age-keygen; eget extracts one executable per
      # asset, so a fresh dir needs `eget FiloSottile/age --file age-keygen`.
    };
    fzf = {
      repo = "junegunn/fzf";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
    };
    gh = {
      repo = "cli/cli";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
    };
    duf = {
      repo = "muesli/duf";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
    };
    zoxide = {
      repo = "ajeetdsouza/zoxide";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
    };
    glow = {
      repo = "charmbracelet/glow";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz" "^sbom"];
    };
    gum = {
      repo = "charmbracelet/gum";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz" "^sbom"];
    };
    task = {
      repo = "go-task/task";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
    };
    lazygit = {
      repo = "jesseduffield/lazygit";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.gz"];
    };
    hugo = {
      repo = "gohugoio/hugo";
      dirs = ["aarch64" "amd64"];
      # plain / extended / extended_withdeploy exist for every platform.
      filters = ["hugo_extended_" "^withdeploy" ".tar.gz"];
    };
    sops = {
      repo = "getsops/sops";
      dirs = ["aarch64" "amd64"];
      filters = [".linux." "^sbom"];
    };
    pdfcpu = {
      repo = "pdfcpu/pdfcpu";
      dirs = ["aarch64" "amd64"];
      filters = [".tar.xz" "^sbom"];
    };
    starship = {
      repo = "starship/starship";
      dirs = ["aarch64" "amd64"];
      # gnu and musl tarballs both match the platform; two survivors make eget
      # ask, and asking with no TTY is a failure.
      filters = [".tar.gz" "^musl"];
    };
    yq = {
      repo = "mikefarah/yq";
      dirs = ["aarch64" "amd64"];
      filters = ["^tar.gz"]; # the bare binary, not the tarball of it
      file = "yq";
    };

    # GUI apps: one file, no archive, and the name carries the arch, so the
    # filter names the x86_64 asset — that is what /srv/data/appimages holds.
    # Every AppImage release also ships a .zsync beside it, and two matching
    # assets make eget prompt — which is death without a TTY. `target` is what
    # keeps the version out of the filename: eget would otherwise name the file
    # after the repo and drop the extension.
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

  renderDir = dir: let
    rows = builtins.filter (n: builtins.elem dir tools.${n}.dirs) (builtins.attrNames tools);
    row = name: let
      t = tools.${name};
      filters = "[" + builtins.concatStringsSep ", " (map (f: "\"${f}\"") t.filters) + "]";
      opt = k: if t ? ${k} then "\n${k} = \"${t.${k}}\"" else "";
    in ''
      # ${name}
      ["${t.repo}"]
      asset_filters = ${filters}${opt "file"}${opt "target"}
    '';
  in ''
    # GENERATED by tools/eget.nix — edit the table there, not this file.
    # No `target` here on purpose: the caller passes --to, so the same table
    # describes both the NAS copy and a host-local dir.
    # The arch of what lands here is the arch of the machine that runs it.
    [global]
    quiet = false

    ${builtins.concatStringsSep "\n" (map row rows)}
  '';
in {
  aarch64 = renderDir "aarch64";
  amd64 = renderDir "amd64";
  appimages = renderDir "appimages";
}
