# The fetch-oneshot unit shape, single-sourced: pull a file over the network
# once — resumable (curl -C -), refused while the file exists
# (ConditionPathExists). Used via `import`, same shape as
# nginx-static-cache.nix; was spelled verbatim in hosts/eisen/{llm-server,
# parakeet,qwen-image}.nix and forked in deepseek-v4.nix.
{
  pkgs,
  lib,
}: {
  file,
  url,
  # chmod +x after fetch — binaries (llama-server) arrive un-executable.
  exec ? false,
  # Unit ordering: a mount-backed destination adds its mount unit.
  requires ? ["network-online.target"],
}: {
  description = "Fetch ${file} if missing";
  after = requires;
  wants = requires;
  unitConfig.ConditionPathExists = "!${file}";
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = pkgs.writeShellScript "fetch-${baseNameOf file}" ''
      set -euo pipefail
      ${pkgs.coreutils}/bin/echo "Fetching ${url}"
      ${pkgs.curl}/bin/curl -fL --retry 5 --retry-delay 5 -C - \
        -o "${file}.part" "${url}"
      ${pkgs.coreutils}/bin/mv -f "${file}.part" "${file}"
      ${lib.optionalString exec "${pkgs.coreutils}/bin/chmod +x '${file}'"}
    '';
  };
}
