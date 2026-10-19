{
  pkgs,
  lib,
  ...
}:
with lib; let
  paperlessDataDir = "/srv/data/paperless";
in {
  imports = [
    # Use local fork without tesseract override.apply to avoid uncached builds
    ./paperless-fork.nix
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

    # Restore upstream's tesseract language narrowing, which this host's fork
    # of the paperless module drops to stay on a cached package. Stock
    # tesseract5 defaults to `languages.all` (every OCR language, one 1,015 MiB
    # FOD) while this instance only ever asks for deu+eng. Upstream derives the
    # list from PAPERLESS_OCR_LANGUAGE and always adds equ/osd/eng (tesseract
    # fails to build without eng).
    # Cost: paperless-ngx + ocrmypdf are re-wrapped against the narrowed
    # tesseract, so the first build is not substitutable — one build for ~1 GiB
    # of permanent closure.
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
    serviceConfig = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.tika} --host 127.0.0.1 --port 9998";
      Environment = "JAVA_TOOL_OPTIONS=-Xms32m -Xmx128m";
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
