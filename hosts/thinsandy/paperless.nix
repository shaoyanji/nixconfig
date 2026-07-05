{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  paperlessDataDir = "/srv/data/paperless";
in {
  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    port = 28981;
    settings = {
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_CONSUMER_POLLING = 60;
      PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;
      PAPERLESS_TIKA_ENABLED = true;
      PAPERLESS_TIKA_ENDPOINT = "http://127.0.0.1:9998";
      PAPERLESS_GOTENBERG_ENABLED = true;
      PAPERLESS_GOTENBERG_ENDPOINT = "http://127.0.0.1:3000";
    };
  };

  # --- Tika ---
  # Upstream services.tika module (nixos/modules/services/search/tika.nix) unconditionally
  # calls cfg.package.override { enableGui = false } at line 82, producing a hash that
  # misses the binary cache and triggers a full Maven build (~11 min).
  # Instead, run the stock cached pkgs.tika directly via inline unit.
  # Stock pkgs.tika builds with enableGui=true (app JAR included) but that build happened
  # on the NixOS build farm — we just download the cached 105 MiB result.
  systemd.services.tika = {
    description = "Apache Tika Server";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.tika} --host 127.0.0.1 --port 9998";
      DynamicUser = true;
      StateDirectory = "tika";
      CacheDirectory = "tika";
    };
  };

  # --- Gotenberg ---
  # Use upstream module with chromium stubbed out at runtime.
  # Paperless only uses Gotenberg for LibreOffice PDF conversion (office docs -> PDF),
  # never HTML->PDF, so real chromium is unnecessary in the closure.
  # Stock pkgs.gotenberg is cached on cache.nixos.org — no need for overrides.
  services.gotenberg = {
    enable = true;
    chromium = {
      package =
        pkgs.runCommand "chromium" {
          pname = "chromium";
          meta.mainProgram = "chromium";
        } ''
          mkdir -p $out/bin
          ln -s /dev/null $out/bin/chromium
        '';
      disableJavascript = true;
      disableRoutes = true;
    };
    extraArgs = ["--chromium-allow-list=file:///tmp/.*"];
  };

  # Bind-mount /var/lib/paperless to the data drive so paperless
  # state doesn't consume space on the root partition.
  fileSystems."/var/lib/paperless" = {
    device = paperlessDataDir;
    fsType = "none";
    options = ["bind" "x-systemd.requires=systemd-tmpfiles-setup.service"];
  };

  systemd.tmpfiles.rules = ["d ${paperlessDataDir} 0750 paperless paperless -"];
}
