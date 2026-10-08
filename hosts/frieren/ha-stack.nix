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
# zigbee2mqtt: REMOVED 2026-10 — no coordinator dongle was ever attached
#   and the parked unit fail-looped ("No valid USB adapter found") for
#   weeks. The old data lives on in /srv/private/zigbee2mqtt. Re-add via
#   services.zigbee2mqtt (set settings.serial.port) if a dongle arrives.
# esphome: REMOVED 2026-10 — no ESP devices; esphome >= 2026.8 also removed
#   its built-in dashboard upstream, so the unit fail-looped for a week.
#   Re-add via services.esphome (or esphome-device-builder) if needed.
# uptime-kuma: status dashboards on 3001, LAN-exposed (the module
#   has no openFirewall option — the port is opened explicitly).
_: {
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

  # --- Uptime-Kuma (service status dashboards) ---
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "3001";
    };
  };
  # The module has no openFirewall option.
  networking.firewall.allowedTCPPorts = [3001];
}
