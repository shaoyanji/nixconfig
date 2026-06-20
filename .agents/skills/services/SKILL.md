---
name: services
description: Legacy compatibility wrappers routing to canonical infra:* and checks:* tasks. Includes validation, rollback, and host deploy aliases. Derived from taskfiles/services-core.yml and taskfiles/services-legacy.yml.
---

# services — Legacy Compatibility

These wrappers route to canonical `infra:*`, `checks:*`, and `dev:*` tasks. Prefer canonical namespaces for new workflows.

## Validation

| Task | Description |
|------|-------------|
| `services:validate:host:<host>` | Run nullclaw smoke check (routes to `checks:nullclaw:smoke:<host>`) |

## Deploy

| Task | Description |
|------|-------------|
| `services:deploy:host:<host>` | Plan + apply + validate (routes to `infra:deploy:host:<host>`) |
| `services:deploy:rpi` | Deploy minyx (PI) host |
| `services:deploy:thinsandy` | Deploy thinsandy host |
| `services:deploy:mtfuji` | Deploy mtfuji host |
| `services:deploy:menu` | Compatibility alias for `infra:deploy:menu` |

## Rollback

| Task | Description |
|------|-------------|
| `services:rollback:host:<host>` | Rollback + validate (routes to `infra:rollback:host:<host>` + evidence) |
| `services:rollback:apply:host:<host>` | Rollback apply (routes to `infra:rollback:apply:host:<host>`) |
| `services:evidence:rollback:host:<host>` | Validate after rollback |

## Logs

| Task | Description |
|------|-------------|
| `services:logs:host:<host>` | Tail logs (routes to `infra:logs:host:<host>`) |
| `services:logs:menu` | Compatibility alias for `infra:logs:menu` |

## Record

| Task | Description |
|------|-------------|
| `services:record:host:<host>` | Commit deployment outcome in git |

## Deprecated aliases (services-legacy.yml)

| Task | Description |
|------|-------------|
| `switch:<os>` | Alias for `infra:switch:<os>` |
| `boot:<os>` | Alias for `infra:boot:<os>` |
| `nixos-rebuild` | Alias for `infra:rebuild:nixos` |
| `darwin-rebuild` | Alias for `infra:rebuild:darwin` |
| `home-manager-switch` | Alias for `infra:rebuild:home-manager` |
| `wsl-rebuild` | Alias for `infra:rebuild:wsl` |
| `orb-rebuild` | Alias for `infra:rebuild:orb` |
| `push-rpi-rebuild` | Alias for `infra:deploy:host:{{.PI}}` |
| `push-thin-rebuild` | Alias for `infra:deploy:host:thinsandy` |
| `push-fuji-rebuild` | Alias for `infra:deploy:host:mtfuji` |
| `rebuild` | Deprecated rebuild menu |
