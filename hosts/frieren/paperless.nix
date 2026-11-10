{
  self,
  pkgs,
  lib,
  ...
}:
with lib; let
  paperlessDataDir = "/srv/data/paperless";
in {
  imports = [
    # Upstream's module re-applies a tesseract narrowing to `package`; this fork
    # drops that so the package stays cached. Shared with delphi since 2026-11-02,
    # which is why it lives under modules/ instead of beside this host.
    self.modules."services.paperless-fork"
  ];

  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    port = 28981;
    settings = {
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_CONSUMER_POLLING = 60;
      PAPERLESS_CONSUMER_RECURSIVE = true;
      PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;
      PAPERLESS_TIKA_ENABLED = true;
      PAPERLESS_TIKA_ENDPOINT = "http://127.0.0.1:9998";
      PAPERLESS_GOTENBERG_ENABLED = true;
      PAPERLESS_GOTENBERG_ENDPOINT = "http://127.0.0.1:3000";
    };

    # tesseract is narrowed to deu+eng, because `languages.all` is a 1,015 MiB FOD
    # and this instance never asks for more. Why:
    # .agents/deploy/hosts/frieren.md §"Paperless OCR languages".
    package = pkgs.paperless-ngx.override {
      tesseract5 = pkgs.tesseract5.override {
        enableLanguages = ["eng" "deu" "osd" "equ"];
      };
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
    # The unit-level attrset escapes the value; inside `serviceConfig.Environment`
    # the same string is written raw, systemd splits it on the space and drops
    # `-Xmx128m` as an invalid assignment.
    environment = {
      JAVA_TOOL_OPTIONS = "-Xms32m -Xmx128m";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.tika} -noFork --host 127.0.0.1 --port 9998";
      MemoryHigh = "192M";
      MemoryMax = "256M";
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
        pkgs.runCommand "chromium"
        {
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
    options = ["bind"];
    depends = ["/srv/data"];
  };

  systemd.tmpfiles.rules = let
    d = mode: user: group: path: "d ${path} ${mode} ${user} ${group} -";
  in [
    (d "0750" "paperless" "paperless" paperlessDataDir)
    (d "0750" "paperless" "paperless" "${paperlessDataDir}/consume")
    (d "0750" "paperless" "paperless" "${paperlessDataDir}/media")
  ];

  # Prevent NixOS rebuilds from restarting Paperless services on routine switch,
  # saving CPU and disk I/O from unneeded Celery/Granian/Tantivy churn.
  systemd.services.paperless-scheduler.restartIfChanged = false;
  systemd.services.paperless-consumer.restartIfChanged = false;
  systemd.services.paperless-web.restartIfChanged = false;
  systemd.services.paperless-task-queue.restartIfChanged = false;
}
