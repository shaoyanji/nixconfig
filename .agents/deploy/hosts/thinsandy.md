# thinsandy Exceptions

## Scope
Operational differences for `thinsandy` relative to wrapper-style AI hosts.

## Key Differences
- Host class is `direct` (not wrapper).
- Service mix includes `nullclaw`, `openclaw-gateway`, `hermes-agent`, and `paperless-ngx`.
- Deployment style is direct AI services + nullclaw.

## Paperless / Tika / Gotenberg
Paperless runs on thinsandy with Tika (text extraction) and Gotenberg (PDF conversion).

**Known upstream module traps:**

- `services.tika` unconditionally overrides the package (`enableGui = false`, line 82 of `search/tika.nix`), producing an uncached hash that triggers a full Maven build (~11 min). `paperless.nix` sidesteps this by inlining the systemd unit with the stock cached `pkgs.tika`.

- `services.gotenberg` unconditionally sets `CHROMIUM_BIN_PATH` (line 297 of `misc/gotenberg.nix`), pulling real chromium (~300 MiB) into every closure. `paperless.nix` overrides `chromium.package` with a stub since paperless only needs LibreOffice conversion, never HTML->PDF.

**Deploy notes:**
- Paperless state lives on the data drive at `/srv/data/paperless` (bind-mounted to `/var/lib/paperless`).
- First deploy takes longer because tika-server JAR downloads (105 MiB) and gotenberg Go binary downloads.

## Operational Interpretation
- Prefer canonical host deploy flow (`infra:deploy:host:thinsandy`) for apply/validate (`services:deploy:host:thinsandy` remains a compatibility alias).
- Validation mapping is manifest-driven (`checks:nullclaw:smoke:thinsandy`).

## Source References
- `taskfiles/services-core.yml`

## Manifest helper
