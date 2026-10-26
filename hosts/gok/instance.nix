# The gok appliance, declared. `scripts/task/gok.sh` renders this module into the
# instance's config.json and then fills the credential slots from sops; nothing
# here is a secret, and no credential belongs in this file.
{
  ...
}: {
  services.gokrazy.instances.gok = {
    # DHCP name and the address `gok update` resolves.
    hostname = "gok.cloudforest-kardashev.ts.net";

    packages = [
      "github.com/gokrazy/fbstatus"
      "github.com/gokrazy/hello"
      "github.com/gokrazy/serial-busybox"
      "github.com/gokrazy/breakglass"
      "tailscale.com/cmd/tailscaled"
      "tailscale.com/cmd/tailscale"
      "github.com/gokrazy/mkfs"
      "github.com/gokrazy/wifi"
      "github.com/prometheus/node_exporter"
    ];

    # A Pi 3B: arm64 userspace, no serial header plugged in.
    environment = ["GOOS=linux" "GOARCH=arm64"];
    serialConsole = "disabled";

    packageConfig = {
      # randomd writes /etc/machine-id at first boot. A fixed value here keeps
      # the appliance's identity stable across reflashes, which is what makes
      # its tailscale node and metrics series the same node.
      "github.com/gokrazy/gokrazy/cmd/randomd".extraFileContents."/etc/machine-id" =
        "3e8de745bc7c4cf89cd363e11d9a7718\n";

      # node_exporter, reachable on the LAN/tailnet as :9100.
      "github.com/prometheus/node_exporter".commandLineFlags = ["--web.listen-address=:9100"];
    };

    breakglass.enable = true;

    # `gok update` password: sops only. The rendered config carries "".
    httpPasswordSecret = "gokrazy.gok.http_password";

    # Tailnet name is `gok` even though the DHCP name is the FQDN above.
    tailscale = {
      enable = true;
      hostname = "gok";
      # Set this key in sops for unattended auth; without it the appliance shows
      # a login URL in its own UI and keeps the session in /perm.
      authKeySecret = "gokrazy.gok.tailscale_auth_key";
    };

    # Both the SSID and the PSK live in sops: the network name is not published
    # in this repo either. Comment these two lines out for the wired default.
    wifi = {
      ssidSecret = "gokrazy.gok.wifi_ssid";
      pskSecret = "gokrazy.gok.wifi_psk";
    };
  };
}
