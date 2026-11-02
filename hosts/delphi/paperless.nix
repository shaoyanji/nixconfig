# paperless-ngx on delphi — offloaded from frieren 2026-11-02.
#
# Why this moves and stirling did not need to: the archive is 722 MB of SQLite
# plus media and never touches the NAS's disks, while four Python units plus
# tika plus gotenberg hold ~520 MiB resident. Memory is the thing delphi has
# (8 GiB idle of 11) and frieren rents from a laptop.
#
# Three deliberate differences from `hosts/frieren/paperless.nix`:
#
#  - **Stock `paperless-ngx`, not the narrowed-tesseract override.** That
#    override exists on frieren to keep one 1 GiB tessdata FOD out of the
#    closure. Here it would turn a substitutable Python package into a local
#    build on a 2-core ARM VM, and `AGENTS.md`'s rule is that delphi substitutes
#    rather than compiles. OCR still gets deu+eng; it just also ships the
#    languages nobody asks for.
#  - **It binds every interface, reachable only on the tailnet.** delphi has no
#    LAN to serve: `docs.frieren.lan` stays the name and frieren's nginx is
#    the front, so the only client is one tailnet hop away. 28981 is absent from
#    the global `allowedTCPPorts` and present only on `tailscale0` — the same
#    posture `services.fleetMonitors` already uses here.
#  - **`PAPERLESS_URL` is declared.** The Host header arrives from frieren's
#    proxy, so Django needs the name it will be addressed by; a fresh install
#    defaults to its own listen address and mints links nobody can open.
#
# One overlay, measured. `paperless-ngx` pulls `wandb` in through its optional
# AI/classifier extras, and no substituter carries an aarch64 build of it: the
# local build ran its own suite and died 7 minutes in on
# `test_agent_basic` ("worker 'gw0' crashed") with 3485 tests passing — a
# failure in the test harness, not in the wheel paperless imports. Building a
# runtime dependency with its checks off is the smaller lie than shipping no
# paperless; the package contents are unchanged by `doCheck`.
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
    serviceConfig = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.tika} -noFork --host 127.0.0.1 --port 9998";
      Environment = "JAVA_TOOL_OPTIONS=-Xms32m -Xmx128m";
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
