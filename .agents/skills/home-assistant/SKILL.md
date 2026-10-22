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

# home-assistant — HA and MQTT on frieren

Declarative in `modules/services/home-assistant.nix` (`services.ha-stack.*`),
enabled in `hosts/frieren/configuration.nix`. Editing any other file does nothing.

| | |
| :--- | :--- |
| Web | `http://ha.frieren.lan/` (nginx vhost) or `127.0.0.1:8123` |
| MQTT | `127.0.0.1:1883`, Mosquitto, loopback, `allow_anonymous = true` |
| Status | `http://status.frieren.lan/` (Uptime-Kuma, port 3001) |
| State | `configDir` → `/srv/private/home-assistant` |

The port is declared once (`services.ha-stack.port`) and the nginx vhost and
firewall read it, so do not hardcode 8123 in a new module.

## The laptop-as-UPS sensors

frieren's battery is the NAS's UPS, so `command_line` sensors read it directly
when `services.ha-stack.telemetry.enable` is on:

| Entity | Reads |
| :--- | :--- |
| `sensor.frieren_battery_level` | `/sys/class/power_supply/BAT0/capacity` |
| `sensor.frieren_battery_status` | `/sys/class/power_supply/BAT0/status` |
| `binary_sensor.frieren_ac_connected` | `/sys/class/power_supply/ADP0/online` (`1` = mains) |

Check the underlying values over ssh before believing a stale sensor; the
`command_line` integration caches and HA logs the failure, not the sensor.

## REST API

Token: HA UI → Profile → Long-Lived Access Tokens. Export it, never commit it.

```bash
export HASS_URL=http://127.0.0.1:8123
export HASS_TOKEN='<token>'
h() { curl -fsS -H "Authorization: Bearer $HASS_TOKEN" -H 'Content-Type: application/json' "$@"; }

h "$HASS_URL/api/"                                   # 200 + "API running."
h "$HASS_URL/api/states" | jq -r '.[] | "\(.entity_id) \(.state)"'
h "$HASS_URL/api/states/sensor.frieren_battery_level" | jq .state
h -X POST -d '{"entity_id":"automation.nightly_shutdown"}' \
  "$HASS_URL/api/services/automation/trigger"
h -X POST "$HASS_URL/api/template" \
  -d '{"template":"{{ states(\"sensor.frieren_battery_level\") }}%"}'
```

`-fsS` matters: without `-f` a 401 prints as a JSON error body and an agent reads
it as an empty state list.

## MQTT

```bash
nix shell nixpkgs#mosquitto --command mosquitto_sub -h 127.0.0.1 -v -t '#'
nix shell nixpkgs#mosquitto --command mosquitto_pub -h 127.0.0.1 \
  -t homeassistant/sensor/frieren_extra/state -m '{"load": 0.82}'
```

Discovery (`homeassistant/<component>/<node>/<object>/config`) is enabled for
the components in `extraComponents`, but a name there only makes an integration
*available*: 4 of the 11 defaults are actually configured (`command_line`,
`github`, `met`, `ipp`), the rest are dependency-only. To turn one on, add its
config entry or YAML in the module, and say which in the commit.

Adding a native integration is an `extraComponents` entry; a PyPI dependency an
`extraPackages` entry. Both live in that same module.

## Rebuild

```bash
nix eval .#nixosConfigurations.frieren.config.services.ha-stack.enable
task infra:deploy:host:frieren        # build happens on the builder, not here
```

frieren is 15 W: never `nixos-rebuild switch` on it for a config this small.
`infra:deploy` gates, plans, warms and validates.

## When it is down

```bash
systemctl status home-assistant mosquitto
journalctl -u home-assistant -n 50 --no-pager
sudo tail -n 50 /srv/private/home-assistant/home-assistant.log   # Python tracebacks
```

A `400 Bad Request` on every proxied request is the `trusted_proxies` /
`use_x_forwarded_for` block, not auth. A sensor stuck at a value is a failed
`command_line` command in that log.

Truth: `modules/services/home-assistant.nix` — the option tree; this page is the procedure.
