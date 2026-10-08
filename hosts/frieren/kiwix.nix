# Offline wiki stack: kiwix-serve (native NixOS module) + declarative ZIM
# library (Wikipedia + ArchWiki), behind nginx at wiki.frieren.lan.
#
# History: both the server (kiwix-serve.service) and the downloader
# (wikipedia-download.service + download_full.sh) started as hand-rolled
# ~/.config/systemd/user units, declared nowhere. The downloader re-hashed the
# full ~52GB ZIM on every boot and switch-to-configuration restart, saturating
# disk IO for ~10-20 minutes per rebuild (seen 2026-10-08, starved
# hermes-gateway startup). Archives are now declarative store paths: adding a
# new wiki = add a fetchurl entry below (use `nurl <url>` for the hash).
#
# The 52GB Wikipedia ZIM was imported into the store locally (no re-download):
#   nix store add-file /var/lib/kiwix/wikipedia_en_all_nopic_2026-06.zim
#   → /nix/store/8n4nhjwy2bbk36j170vv3qxqdv06j0np-wikipedia_en_all_nopic_2026-06.zim
# It is kept alive by the library derivation below; do NOT drop it from the
# library attrset without also deleting the local copy at /var/lib/kiwix.
{pkgs, ...}: let
  user = import ../../modules/global/user.nix;
  # Per-archive ZIM sources. fetchurl for small archives; store path for the
  # huge ones (imported via `nix store add-file` to avoid re-downloads).
  zims = {
    # Nurl form for regeneration:
    #   nurl https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_nopic_2026-06.zim
    #   → sha256-RBpW2eBbLZj4rprLeYalE+1HkE1zhSyS3Gt9ULqhIuU
    # (quoted string: bare path literals are forbidden in pure eval)
    wikipedia = "/nix/store/8n4nhjwy2bbk36j170vv3qxqdv06j0np-wikipedia_en_all_nopic_2026-06.zim";

    # Nurl form:
    #   nurl https://download.kiwix.org/zim/other/archlinux_en_all_maxi_2026-07.zim
    #   → sha256-w99VEBCpU9LBc6+NZaWWp85DSn+gdxdBvIAP7sytGUI
    archwiki = pkgs.fetchurl {
      url = "https://download.kiwix.org/zim/other/archlinux_en_all_maxi_2026-07.zim";
      hash = "sha256-w99VEBCpU9LBc6+NZaWWp85DSn+gdxdBvIAP7sytGUI";
    };
  };

  # library.xml written directly (NOT via kiwix-manage): kiwix-manage reads
  # the ZIM headers, which drags the 52GB wikipedia path into the derivation's
  # sandbox/input closure and breaks pure eval + remote builds. Book metadata
  # (ids, counts) comes from the previously generated /var/lib/kiwix
  # /library.xml and the Kiwix catalog. tmpfiles installs it at the stable
  # path below — the same file `wikisearch --list` (hosts/frieren/tools.nix)
  # and kiwix-serve -M read.
  kiwixLibrary = pkgs.writeText "kiwix-library.xml" ''
    <library version="20110515">
      <book id="c22094d0-6ad1-6360-36b7-dab953595143" path="${zims.wikipedia}" title="Wikipedia" description="The free encyclopedia" language="eng" creator="Wikipedia" publisher="openZIM" name="wikipedia_en_all" flavour="nopic" tags="wikipedia;_category:wikipedia;_pictures:no;_videos:no;_details:yes;_ftindex:yes" date="2026-06-17" articleCount="19191219" mediaCount="515775" size="51455768" />
      <book id="431f20f7-58c7-87d4-8f68-eaa4462478bc" path="${zims.archwiki}" title="ArchWiki" description="Arch Linux documentation" language="eng" creator="Archlinux" publisher="openZIM" name="archlinux_en_all" flavour="maxi" tags="Linux distro;archlinux;_category:other;_pictures:yes;_videos:no;_details:yes;_ftindex:yes" date="2026-07-23" articleCount="14497" mediaCount="8" size="34767" />
    </library>
  '';
in {
  services.kiwix-serve = {
    enable = true;
    port = 8088;
    openFirewall = true;
    libraryPath = "/var/lib/kiwix/library.xml";
    # -M hot-reloads library.xml when it changes; 4 threads matches the old
    # hand-rolled unit. nginx reverse-proxy: hosts/frieren/reverse-proxy.nix
    # (wiki.frieren.lan → 127.0.0.1:8088).
    extraArgs = [
      "-M"
      "--threads"
      "4"
    ];
  };

  # Keep the stable on-disk library.xml in sync so wikisearch (KIWIX_LIBRARY
  # defaults to /var/lib/kiwix/library.xml) sees every declared archive.
  # NOT systemd-tmpfiles C+: copy rules never overwrite an existing
  # destination — that silently kept the stale hand-generated library (top_mini
  # only, no ArchWiki) after the declarative one landed (verified 2026-10-08).
  # Activation runs on every boot + switch before services start; the cmp
  # guard keeps the mtime stable so kiwix-serve -M doesn't hot-reload an
  # unchanged library.
  system.activationScripts.kiwix-library = {
    deps = ["users"];
    text = ''
      ${pkgs.coreutils}/bin/install -d -m 0755 -o ${user.name} -g users /var/lib/kiwix
      if ! ${pkgs.diffutils}/bin/cmp -s ${kiwixLibrary} /var/lib/kiwix/library.xml; then
        ${pkgs.coreutils}/bin/install -m 0644 -o ${user.name} -g users ${kiwixLibrary} /var/lib/kiwix/library.xml
      fi
    '';
  };
}
