# lumi — Debian 12 NAT VPS in Dallas (x86_64, 961 MiB RAM, 35 GiB ext4):
# standalone Home Manager profile (`roles.lean` + `sops`) over Debian 12 + Nix + Tailscale.
#
# Imperative Debian edge, deliberately outside this HM closure:
#   unit:  /etc/systemd/system/cloudflared-lumi.service
#   drop-in: /etc/systemd/system/cloudflared-lumi.service.d/hardening.conf
#   token: /etc/cloudflared/lumi.env (environment only, never argv)
# cloudflared answers Cloudflare's tunnel and forwards lumi.bountystash.com to
# Traefik on 127.0.0.1:8080. The proxy and its backend are user services here.
{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.home-manager.enable = true;

  home.packages = [
    pkgs.traefik
    pkgs.darkhttpd
    pkgs.bubblewrap
  ];

  home.activation.lumiSshDirectory = lib.hm.dag.entryBefore ["linkGeneration"] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
    $DRY_RUN_CMD chmod 700 "$HOME/.ssh"
  '';

  home.file.".ssh/authorized_keys" = {
    text = (lib.concatStringsSep "\n" config.ssh.authorizedKeys.keys) + "\n";
    force = true;
  };

  # No lumi-specific Telegram bot exists in the secrets plane. Reuse the
  # otherwise unused Morrow bot for the first incarnation; rotate this secret name
  # when a purpose-built @lumi bot is created.
  sops.secrets."ai-services-shared-env" = {};
  sops.secrets."morrow-telegram" = {};
  sops.templates."zeroclaw-lumi.env" = {
    mode = "0400";
    content = ''
      ${config.sops.placeholder."ai-services-shared-env"}
      ZEROCLAW_TELEGRAM_BOT_TOKEN=${config.sops.placeholder."morrow-telegram"}
    '';
  };

  programs.zeroclaw-user = {
    enable = true;
    envFile = toString config.sops.templates."zeroclaw-lumi.env".path;
    telegramAllowedUsers = ["8679391100" "8207284912"];
  };

  home.file.".local/bin/devin".source = pkgs.writeShellScript "devin" ''
    exe="$HOME/.local/share/devin/cli/_versions/current/bin/devin"
    if [ ! -x "$exe" ]; then
      echo "devin: install missing at $exe" >&2
      exit 1
    fi
    export DEVIN_PERMISSION_MODE="''${DEVIN_PERMISSION_MODE:-smart}"
    exec "$exe" "$@"
  '';

  home.file.".local/bin/lumi-agent".source = pkgs.writeShellScript "lumi-agent" ''
    tmux=${pkgs.tmux}/bin/tmux
    session=agent-lumi

    pane_is_devin() {
      [ "$1" = "devin" ] && return 0
      [ -n "$2" ] && pgrep -x -P "$2" devin >/dev/null 2>&1
    }

    target=$session
    if ! "$tmux" has-session -t "$session" 2>/dev/null; then
      existing_session=
      while read -r pane_session pane_pid pane_cmd; do
        if pane_is_devin "$pane_cmd" "$pane_pid"; then
          existing_session=$pane_session
          break
        fi
      done < <("$tmux" list-panes -a -F '#{session_name} #{pane_pid} #{pane_current_command}' 2>/dev/null)
      if [ -n "$existing_session" ]; then
        target=$existing_session
      fi
    fi

    devin_pane=
    if ! "$tmux" has-session -t "$target" 2>/dev/null; then
      devin_pane=$("$tmux" new-session -d -P -F '#{pane_id}' -s "$session" -n agent -c "$HOME" "$HOME/.local/bin/devin")
      target=$session
    fi

    devin_count=0
    shell_count=0
    while read -r pane_id pane_cmd pane_pid; do
      if pane_is_devin "$pane_cmd" "$pane_pid"; then
        devin_count=$((devin_count + 1))
        if [ -z "$devin_pane" ]; then
          devin_pane=$pane_id
        fi
      else
        shell_count=$((shell_count + 1))
      fi
    done < <("$tmux" list-panes -s -t "$target" -F '#{pane_id} #{pane_current_command} #{pane_pid}' 2>/dev/null)

    if [ "$devin_count" -eq 0 ] && [ -z "$devin_pane" ]; then
      devin_pane=$("$tmux" new-window -d -P -F '#{pane_id}' -t "$target" -n agent -c "$HOME" "$HOME/.local/bin/devin")
    fi

    if [ "$shell_count" -eq 0 ] && [ -n "$devin_pane" ]; then
      "$tmux" split-window -h -t "$devin_pane" -c "$HOME"
      "$tmux" select-pane -t "$devin_pane"
    fi

    if [ -n "''${TMUX:-}" ]; then
      current_session=$("$tmux" display-message -p '#S')
      if [ "$current_session" != "$target" ]; then
        exec "$tmux" switch-client -t "$target"
      fi
      echo "lumi-agent: already in tmux session $target"
    elif [ -t 0 ] && [ -t 1 ]; then
      exec "$tmux" attach-session -t "$target"
    else
      echo "lumi-agent: tmux session $target is ready; attach with: tmux attach -t $target"
    fi
  '';

  home.file."public/lumi/index.html".text = ''
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="description" content="lumi edge node">
      <title>lumi · edge node</title>
      <style>
        :root { color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #08111f; color: #e6edf7; }
        main { width: min(42rem, calc(100vw - 2rem)); padding: 3rem; border: 1px solid #29415f; border-radius: 1.25rem; background: linear-gradient(145deg, #101d31, #0a1424); box-shadow: 0 1.5rem 4rem #0008; }
        h1 { margin: 0 0 .5rem; font-size: clamp(2.5rem, 8vw, 4.5rem); letter-spacing: -.06em; }
        p { color: #9fb2cc; line-height: 1.65; }
        .status { display: inline-flex; gap: .5rem; align-items: center; margin: .5rem 0 1.5rem; padding: .45rem .75rem; border-radius: 999px; background: #0d2b1d; color: #7ee2a8; font-weight: 650; }
        .status::before { content: ""; width: .55rem; height: .55rem; border-radius: 50%; background: #37d67a; box-shadow: 0 0 1rem #37d67a; }
        nav { display: flex; flex-wrap: wrap; gap: .75rem; margin-top: 1.5rem; }
        a { color: #9ecbff; text-decoration: none; padding: .65rem .9rem; border: 1px solid #29415f; border-radius: .7rem; background: #ffffff08; }
        a:hover { border-color: #5f85b7; background: #ffffff12; }
      </style>
    </head>
    <body>
      <main>
        <h1>lumi</h1>
        <div class="status">edge online</div>
        <p>Production ingress for lightweight fleet services, served through Cloudflare Tunnel and Traefik on a small Debian VPS.</p>
        <nav aria-label="Links">
          <a href="https://bountystash.com/">Bountystash</a>
          <a href="https://matt.bountystash.com/">Matt Ji</a>
          <a href="https://github.com/shaoyanji">GitHub</a>
        </nav>
      </main>
    </body>
    </html>
  '';

  xdg.configFile."traefik/traefik.yml".text = ''
    global:
      checkNewVersion: false
      sendAnonymousUsage: false
    log:
      level: WARN
    entryPoints:
      web:
        address: "127.0.0.1:8080"
    api:
      dashboard: false
    providers:
      file:
        filename: "${config.xdg.configHome}/traefik/dynamic.yml"
        watch: true
  '';

  xdg.configFile."traefik/dynamic.yml".text = ''
    http:
      routers:
        lumi-site:
          rule: "Host(`lumi.bountystash.com`)"
          entryPoints:
            - web
          middlewares:
            - security-headers
          service: lumi-site
      middlewares:
        security-headers:
          headers:
            frameDeny: true
            contentTypeNosniff: true
            referrerPolicy: "strict-origin-when-cross-origin"
      services:
        lumi-site:
          loadBalancer:
            servers:
              - url: "http://127.0.0.1:8081"
  '';

  systemd.user.services.traefik = {
    Unit = {
      Description = "Traefik edge proxy for lumi.bountystash.com";
      Wants = ["lumi-web.service"];
      After = ["lumi-web.service"];
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      ExecStart = "${pkgs.traefik}/bin/traefik --configFile=${config.xdg.configHome}/traefik/traefik.yml";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "GOMEMLIMIT=64MiB"
        "GOGC=50"
      ];
      MemoryMax = "96M";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
    Install.WantedBy = ["default.target"];
  };

  systemd.user.services.lumi-web = {
    Unit = {
      Description = "lumi static site backend";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${config.home.homeDirectory}/public/lumi --addr 127.0.0.1 --port 8081 --no-listing";
      Restart = "always";
      RestartSec = 2;
      MemoryMax = "32M";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
    Install.WantedBy = ["default.target"];
  };
}
