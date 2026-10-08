---
name: home-assistant
description: "Inspect, automate, and control Home Assistant, MQTT broker, and telemetry on frieren."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['home-assistant', 'hass', 'mqtt', 'iot', 'automation', 'frieren']
    related_skills: ['infra', 'checks']
---

# `home-assistant` — Home Assistant & IoT Device Stack Runbook

Operational runbook and guidance for interacting with the Home Assistant service, the local Mosquitto MQTT broker, server telemetry sensors, and IoT integrations on `frieren.lan`.

---

## 1. System Overview & Topology

* **Host:** `frieren.lan` (`192.168.3.25`, Tailscale `100.97.61.65`).
* **Service Definition:** Declaratively defined in `hosts/frieren/media-stack.nix` and `hosts/frieren/ha-stack.nix`.
* **State & Data Directory:** `/srv/private/home-assistant` (persistent dataset on NAS pool).
* **Configuration:** `/etc/home-assistant/configuration.yaml` (symlinked into the data directory by NixOS).
* **Endpoints:**
  * **Web Frontend:** `http://ha.frieren.lan/` (via Nginx reverse proxy port 80) and direct port `8123` (`http://127.0.0.1:8123`).
  * **MQTT Broker:** `127.0.0.1:1883` (Mosquitto, loopback-only, anonymous).
  * **Uptime Monitoring:** `http://status.frieren.lan/` and `http://127.0.0.1:3001/` (Uptime-Kuma dashboard).
* **Enabled Components:** `rest`, `command_line`, `todoist`, `jellyfin`, `plex`, `fritzbox`, `github`, `immich`, `met`, `ipp`, `mqtt`, plus Python package `androidtvremote2`.

---

## 2. Server Telemetry Sensors (Laptop-as-UPS)

Because `frieren` is an IdeaPad laptop serving as a headless NAS, its internal battery acts as an uninterruptible power supply (UPS). NixOS declares real-time power sensors under `command_line`:

| Entity ID | Source Command | Unit / Class | Description |
| :--- | :--- | :--- | :--- |
| `sensor.frieren_battery_level` | `cat /sys/class/power_supply/BAT0/capacity` | `%` (`battery`) | Current battery charge percentage |
| `sensor.frieren_battery_status` | `cat /sys/class/power_supply/BAT0/status` | String | `Charging`, `Discharging`, or `Full` |
| `binary_sensor.frieren_ac_connected` | `cat /sys/class/power_supply/ADP0/online` | Binary (`power`) | `on` (mains AC online) / `off` (mains disconnected) |

### Quick CLI Check of Host Power Sensors
```bash
# Check directly on frieren:
cat /sys/class/power_supply/BAT0/capacity
cat /sys/class/power_supply/BAT0/status
cat /sys/class/power_supply/ADP0/online
```

---

## 3. Querying & Controlling Home Assistant via REST API

Home Assistant provides a comprehensive REST API on port `8123`.

### A. Authentication
Generate a **Long-Lived Access Token** in Home Assistant UI (`Profile -> Long-Lived Access Tokens`), and store or export it:
```bash
export HASS_TOKEN="<your_long_lived_access_token>"
export HASS_URL="http://127.0.0.1:8123"  # or http://ha.frieren.lan
```

### B. Health & API Status
```bash
curl -s -H "Authorization: Bearer $HASS_TOKEN" \
     -H "Content-Type: application/json" \
     "$HASS_URL/api/"
```

### C. Reading All Entity States
```bash
curl -s -H "Authorization: Bearer $HASS_TOKEN" \
     "$HASS_URL/api/states" | jq '.[] | {entity_id: .entity_id, state: .state}'
```

### D. Reading a Specific Entity
```bash
# Query frieren battery status
curl -s -H "Authorization: Bearer $HASS_TOKEN" \
     "$HASS_URL/api/states/sensor.frieren_battery_level" | jq '.'

# Query AC power connectivity
curl -s -H "Authorization: Bearer $HASS_TOKEN" \
     "$HASS_URL/api/states/binary_sensor.frieren_ac_connected" | jq '.state'
```

### E. Triggering Services (Automations & Toggles)
```bash
# Example: Toggle a switch or trigger an automation
curl -X POST \
     -H "Authorization: Bearer $HASS_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"entity_id": "automation.nightly_shutdown"}' \
     "$HASS_URL/api/services/automation/trigger"
```

### F. Rendering Jinja2 Templates on the Server
```bash
curl -X POST \
     -H "Authorization: Bearer $HASS_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"template": "Battery is at {{ states(\"sensor.frieren_battery_level\") }}% and status is {{ states(\"sensor.frieren_battery_status\") }}."}' \
     "$HASS_URL/api/template"
```

---

## 4. Mosquitto MQTT Broker Integration

`ha-stack.nix` provides a local Mosquitto MQTT broker on `127.0.0.1:1883`. It is configured without authentication (`allow_anonymous = true`) for local processes on frieren.

### A. Publishing MQTT Messages
To publish telemetry or test sensors to Home Assistant:
```bash
nix shell nixpkgs#mosquitto --command mosquitto_pub \
  -h 127.0.0.1 -p 1883 \
  -t "homeassistant/sensor/frieren_custom/state" \
  -m "{\"temperature\": 41.5, \"load\": 0.82}"
```

### B. Subscribing / Monitoring All MQTT Traffic
```bash
nix shell nixpkgs#mosquitto --command mosquitto_sub \
  -h 127.0.0.1 -p 1883 \
  -t "#" -v
```

### C. Home Assistant MQTT Discovery
Home Assistant automatically discovers devices publishing discovery payloads under `homeassistant/<component>/<node_id>/<object_id>/config`:
```bash
nix shell nixpkgs#mosquitto --command mosquitto_pub \
  -h 127.0.0.1 -p 1883 \
  -t "homeassistant/sensor/frieren_disk/config" \
  -m '{"name": "frieren Data Pool Free", "state_topic": "homeassistant/sensor/frieren_disk/state", "unit_of_meas": "GB"}'
```

---

## 5. Declarative Extensions in Nixconfig

All permanent components and sensors should be added to `hosts/frieren/media-stack.nix`:

### Adding Python Packages & Integrations
```nix
services.home-assistant = {
  enable = true;
  extraComponents = [
    "rest"
    "command_line"
    "mqtt"
    # Add new native integrations:
    "sun"
    "wled"
  ];
  extraPackages = ps: [
    # Add external PyPI dependencies needed by custom integrations:
    ps.paho-mqtt
  ];
  config = {
    # Custom YAML configuration
  };
};
```

### Rebuilding & Switching
Always evaluate before deploying:
```bash
nix eval .#nixosConfigurations.frieren.config.services.home-assistant.enable
task infra:apply:host:frieren
```

---

## 6. Uptime-Kuma Status Monitoring

Uptime-Kuma runs alongside Home Assistant on port `3001` and is accessible at `http://status.frieren.lan`.

* Checks the availability of local NAS endpoints:
  * Nginx web server (`:80`)
  * Home Assistant (`:8123`)
  * Kiwix Wikipedia (`:8088`)
  * Paperless-ngx (`:28981`)
  * Jellyfin Media Server (`:8096`)
  * Vaultwarden (`:8222`)
* Can push webhook alerts to Home Assistant or Telegram via `hermes-gateway`.

---

## 7. Diagnostics & Service Recovery

```bash
# Check Home Assistant daemon status
systemctl status home-assistant

# Tail recent Home Assistant logs
journalctl -u home-assistant -n 50 --no-pager

# Inspect internal Python tracebacks
sudo tail -n 50 /srv/private/home-assistant/home-assistant.log

# Check Mosquitto broker
systemctl status mosquitto

# Restart Home Assistant service
sudo systemctl restart home-assistant
```
