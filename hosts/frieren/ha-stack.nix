# Home Assistant device-layer stack: MQTT broker + Zigbee + ESPHome,
# plus Uptime-Kuma service monitoring.
#
# Topology: mosquitto listens on 127.0.0.1:1883 ANONYMOUS (same-host
# broker for HA / zigbee2mqtt / esphome). No credentials are needed
# because every client is local — the listener is NOT exposed on the
# LAN or tailnet. When real devices arrive (ESP nodes publishing over
# WiFi, remote publishers), add an authenticated LAN listener with
# passwordFile wired through sops and open 1883 in the firewall —
# not before. (frieren self-upgrades from the public repo, so config
# must never reference a sops secret that is not in the encrypted
# file yet.)
#
# zigbee2mqtt: enabled but parked until a coordinator dongle is
#   attached — set settings.serial.port (see block comment), then
#   optionally open 8081 for the pairing frontend.
# esphome: device dashboard + flashing UI on 6052, LAN-exposed.
# uptime-kuma: status dashboards on 3001, LAN-exposed (the module
#   has no openFirewall option — the port is opened explicitly).
{ lib, ... }:
{
  # --- Mosquitto MQTT broker (loopback-only, anonymous) ---
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = 1883;
        address = "127.0.0.1";
        settings.allow_anonymous = true;
      }
    ];
  };

  # --- Zigbee2MQTT ---
  # Parked until a coordinator is attached: plug in a SLZB-06 /
  # Sonoff ZBDongle-E, then set:
  #   services.zigbee2mqtt.settings.serial.port =
  #     "/dev/serial/by-id/usb-<dongle-id>";
  # (find it with: ls -l /dev/serial/by-id/). The restart throttling
  # below keeps the not-yet-configured unit from fail-looping and
  # spamming the journal every 10 s.
  services.zigbee2mqtt = {
    enable = true;
    dataDir = "/srv/private/zigbee2mqtt";
    settings = {
      homeassistant.enabled = true; # discovery attrset, not a bare bool
      permit_join = false;
      mqtt = {
        server = "mqtt://127.0.0.1:1883";
        base_topic = "zigbee2mqtt";
      };
      serial = {
        # ← set to the coordinator's /dev/serial/by-id path
        port = "";
      };
      frontend = {
        enabled = true;
        port = 8081;
      };
    };
  };

  systemd.services.zigbee2mqtt = {
    unitConfig.RequiresMountsFor = "/srv/private/zigbee2mqtt";
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.Restart = lib.mkForce "on-failure";
    serviceConfig.RestartSec = lib.mkForce 300;
  };

  # --- ESPHome (device dashboard + flashing) ---
  services.esphome = {
    enable = true;
    address = "0.0.0.0";
    port = 6052;
    openFirewall = true;
  };
  users.users.esphome.extraGroups = [ "dialout" ];

  # --- Uptime-Kuma (service status dashboards) ---
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "3001";
    };
  };
  # The module has no openFirewall option.
  networking.firewall.allowedTCPPorts = [ 3001 ];
}
