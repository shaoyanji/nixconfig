# paperless-ngx on delphi, offloaded from frieren 2026-11-02: SQLite plus media,
# and four Python units that held ~520 MiB resident on the NAS.
# The three deliberate differences from frieren and the wandb overlay: docs/service-offload.md.
{
  pkgs,
  lib,
  ...
}: let
  dataDir = "/var/lib/paperless";
in {
  imports = [../../modules/services/paperless-fork.nix];

  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    port = 28981;
    dataDir = dataDir;
    # The fork is what makes this list usable: upstream's own module applies a
    # tesseract narrowing to `package` on every definition, which on aarch64
    # means compiling tesseract and re-wrapping paperless. The override below is
    # the only one needed, and it is passed through paperless' own
    # `extraPythonPackageOverrides` hook rather than mutating `python3` globally
    # (an overlay that redefines the interpreter recurses forever here).
    package = pkgs.paperless-ngx.override {
      extraPythonPackageOverrides = _final: prev: {
        wandb = prev.wandb.overridePythonAttrs (_: {
          doCheck = false;
          doInstallCheck = false;
        });
      };
    };
    settings = {
      PAPERLESS_URL = "http://docs.frieren.lan";
      PAPERLESS_ALLOWED_HOSTS = "docs.frieren.lan,127.0.0.1,localhost,100.123.145.53";
      PAPERLESS_CSRF_TRUSTED_ORIGINS = "http://docs.frieren.lan";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_CONSUMER_POLLING = 60;
      PAPERLESS_CONSUMER_RECURSIVE = true;
      PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;
      PAPERLESS_TIKA_ENABLED = true;
      PAPERLESS_TIKA_ENDPOINT = "http://127.0.0.1:9998";
      PAPERLESS_GOTENBERG_ENABLED = true;
      PAPERLESS_GOTENBERG_ENDPOINT = "http://127.0.0.1:3000";
    };
  };

  # --- Tika ---
  # Same shape as frieren's, for the same measured reason: the upstream module
  # calls `cfg.package.override { enableGui = false }`, which misses the binary
  # cache and starts a Maven build, so the stock cached package runs from an
  # inline unit instead.
  systemd.services.tika = {
    description = "Apache Tika Server";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    # The unit-level attrset escapes the value; the same string in
    # `serviceConfig.Environment` is written raw, systemd splits it on the space
    # and drops `-Xmx128m` as an invalid assignment — half the heap limit lost.
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
  # Paperless only uses Gotenberg for LibreOffice document → PDF, never HTML →
  # PDF, so chromium is a stub: the real browser is ~400 MiB of closure for a
  # route nothing calls.
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

  systemd.tmpfiles.rules = [
    "d ${dataDir}/consume 0750 paperless paperless -"
    "d ${dataDir}/media 0750 paperless paperless -"
  ];

  # A switch should not restart the celery chain under a running import: the
  # queue resumes on its own, and a mid-document restart is the one way this
  # service loses work on an unrelated deploy.
  systemd.services.paperless-scheduler.restartIfChanged = false;
  systemd.services.paperless-consumer.restartIfChanged = false;
  systemd.services.paperless-web.restartIfChanged = false;
  systemd.services.paperless-task-queue.restartIfChanged = false;
}
