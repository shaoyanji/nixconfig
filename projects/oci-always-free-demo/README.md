# OCI Always Free demo: Terraform + Autonomous Database + APEX to-do

Self-contained Terraform project that builds an Oracle Always Free stack and runs
a working to-do application on it: a Flask app behind a load balancer, and APEX on
the database, both over one `TODOS` table. Every resource is either free by nature
(VCN, subnets, gateways, IAM, bastion, DNS) or pinned to the Always Free limit in
code and guarded by variable validations.

## State of this build

Written and reviewed, not yet applied to a tenancy.

| Gate | Result |
| :--- | :--- |
| `terraform fmt -check -recursive` | clean (Terraform 1.16.5) |
| `terraform validate` | valid, no warnings (oci 9.11.0, tls 4.4.2, acme 2.48.3) |
| `shellcheck -S warning scripts/*.sh` | clean |
| ACME DNS hook | exercised against a stubbed `oci` CLI: merge, exclusive cleanup, RRSet delete on the last value |
| Flask app | routes, HTML escaping, redirects and `/healthz` degradation tested with a stubbed pool |
| `cloud-init.yaml.tftpl` | rendered through `templatefile`, parsed as YAML, embedded bootstrap compiles |
| Live `plan` / `apply` | **not run** — needs a tenancy plus `operator_cidr` and `notification_email` |

The three API contracts that only a live run can confirm are called out where they
matter: the ACME hook against a real zone, SQLcl's `apex export` inside a script,
and the bastion `create-port-forwarding` flags.

## What gets created

| Resource | Always Free limit | How it is enforced here |
| :--- | :--- | :--- |
| Autonomous Database (ATP) | 1 OCPU / 20 GB, `is_free_tier` | `is_free_tier = true`, `compute_model = ECPU`, `compute_count = 2`; validation rejects any other count |
| Load balancer | 1 flexible, 10 Mbps | `shape = flexible`, min = max = 10; validation rejects other bandwidth |
| Compute instance | 2 AMD micro or 4 OCPU / 24 GB ARM | `instance_shape` restricted to `VM.Standard.E2.1.Micro` or `VM.Standard.A1.Flex` (1 OCPU / 6 GB) |
| Block storage | 200 GB total | `boot_volume_gb` validated to 50–200 |
| Object Storage | 20 GB, Standard tier | one Standard-tier private bucket, versioned |
| Vault | software-protected keys | `vault_type = DEFAULT`, `protection_mode = SOFTWARE` (no HSM key) |
| Bastion | free service | one standard bastion, 60-minute sessions, operator CIDR only |
| Monitoring | free ingestion allowance | one topic, two alarms, email subscription |
| OCI DNS A record | service is free | optional, only when `acme_domain` is set; TTL 300, rewritten to follow the load balancer IP |
| Certificates Management | not on the documented Always Free list | imports the certificate you configure; no CA is created (the CA is the billable part). Check Cost Analysis if that matters |

`certificate_mode` chooses where the 443 certificate comes from — `self-signed`
(default, works with no domain), `acme` (DNS-01 through OCI DNS, trusted by
browsers) or `imported` (PEMs you supply). All three end up as one
`oci_certificates_management_certificate`, and `force_https = true` puts a 301
rule set on the HTTP listener whichever mode you pick.

## Architecture

```
internet
   |
   | :80  and  :443  (flexible LB, 10 Mbps, OCI Certificates object on 443)
   v
public subnet 10.0.1.0/24 ── load balancer (security list: 80/443 from anywhere)
   |
   | :8080 (security list: only the LB subnet)
   v
private subnet 10.0.2.0/24
   ├── Oracle Linux 9 micro instance (no public IP)
   │     ├─ Flask + python-oracledb, systemd unit "todo"
   │     ├─ wallet in /opt/todo/wallet (pulled from Object Storage at boot)
   │     └─ password read from OCI Vault at runtime (instance principal)
   ├── Autonomous Database private endpoint  ── no public SQL*Net, no public ORDS
   └── OCI Bastion endpoint ── managed SSH, port forwarding and SOCKS5 sessions
```

The instance has no public IP and egresses through a NAT gateway. The database has
no public listener at all: its VNIC lives in the app subnet, and the only rule that
reaches port 1522 comes from inside that subnet.

## Prerequisites

- An OCI tenancy with Always Free enabled, and an API key in `~/.oci/config`
  (`oci setup config`).
- Terraform >= 1.6 (OpenTofu works too; validated with OpenTofu 1.13 and
  provider `oracle/oci` 9.11).
- `oci` CLI, authenticated with the same API key (used by the helper scripts).
- SQLcl (`sql`, 23.1+) for the database bootstrap and the APEX export/import.
- `unzip`, `curl`, `jq` (the ACME DNS hook), and an SSH key pair registered with
  the bastion.
- For `certificate_mode = acme`: a public DNS zone in OCI DNS and an API key with
  permission to manage records in it.

## File tree

```
├── .gitignore                   state, plans and the wallet stay out of git
├── versions.tf                  provider and Terraform pins
├── providers.tf                 oracle/oci and acme providers, object storage namespace
├── backend.tf                   OCI Object Storage remote state (partial config)
├── backend.hcl.example          bucket/namespace/region for init
├── variables.tf                 inputs, Always Free validations, certificate mode
├── terraform.tfvars.example     the inputs you must set, with Always Free defaults
├── locals.tf                    prefix, TNS alias, object names, public IP
├── network.tf                   VCN, IGW, NAT, route tables, security lists, subnets
├── dns.tf                       A record that tracks the load balancer's public IP
├── database.tf                  Always Free ATP, private endpoint, mTLS wallet
├── vault.tf                     vault, AES master key, generated passwords, two secrets
├── storage.tf                   private Standard-tier artifacts bucket + objects
├── compute.tf                   Oracle Linux image lookup and the micro instance
├── edge.tf                      LB, backend set, 80/443 listeners, optional redirect
├── certificate.tf               self-signed / ACME / imported material + OCI certificate
├── bastion.tf                   standard bastion on the private subnet
├── observability.tf             notification topic, email subscription, two alarms
├── iam.tf                       dynamic group + least-privilege policy (instance principal)
├── outputs.tf                   endpoints, OCIDs, tunnel and session commands
├── cloud-init.yaml.tftpl        package install, env file, systemd unit, bootstrap
├── app/app.py                   Flask to-do app (thin-mode oracledb, Vault password)
├── sql/01_schema.sql            create TODO_APP (run as ADMIN)
├── sql/02_table.sql             create TODOS + seed row (run as TODO_APP)
├── sql/03_apex_workspace.sql    create the APEX workspace (run as ADMIN)
├── sql/apex/                    checked-in APEX app export (f100.sql after export)
├── scripts/adb-sql.sh           SQL + APEX bootstrap and export drift check
├── scripts/acme-dns-oci.sh      lego exec hook that writes the DNS-01 TXT record
├── scripts/preflight.sh         tools, OCI auth, state and tunnel before you start
├── scripts/verify.sh            the checklist as executable checks
└── bootstrap/main.tf            creates the state bucket (local state)
```

CI lives outside this directory, at `.github/workflows/oci-demo.yml`.

## Deploy

1. **State bucket** (once per tenancy). Bootstrapping the backend with the backend
   is circular, so this one uses local state:

   ```bash
   cd bootstrap
   terraform init
   terraform apply -var tenancy_ocid=ocid1.tenancy.oc1..xxxx -var region=us-ashburn-1
   ```

2. **Inputs**, then check the machine before spending an apply:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   cp backend.hcl.example backend.hcl      # fill in bucket/namespace/region
   # set tenancy_ocid, region, operator_cidr, ssh_public_key, notification_email
   scripts/preflight.sh
   ```

3. **Init, plan, apply**:

   ```bash
   terraform init -backend-config=backend.hcl
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

   `terraform init -backend=false` works for a local-state run. The Autonomous
   Database takes several minutes; the instance waits for the wallet object and
   then boots, installs dependencies, pulls the wallet and app source, and starts
   `todo.service`. Expect 5–10 minutes after apply for a healthy backend;
   cloud-init retries while IAM policy propagation catches up.

4. **Open a tunnel to the database.** The database is unreachable without one:

   ```bash
   oci bastion session create-port-forwarding \
     --bastion-id "$(terraform output -raw bastion_id)" \
     --target-private-ip "$(terraform output -raw adb_private_ip)" \
     --target-port 1522 \
     --ssh-public-key-file ~/.ssh/id_ed25519.pub --session-ttl 3600 \
     --wait-for-state SUCCEEDED
   ```

   Run the `ssh` command the CLI prints (it maps a local port, normally 1522, to
   the database listener) and leave it open. The same shape with
   `--target-port 443` is the APEX tunnel.

5. **Bootstrap the database and the APEX workspace**:

   ```bash
   ADB_LOCAL_PORT=1522 scripts/adb-sql.sh --bootstrap
   ```

   That runs `01_schema.sql` as ADMIN, `02_table.sql` as `TODO_APP`,
   `03_apex_workspace.sql` as ADMIN, and then imports `sql/apex/f100.sql` as
   `TODO_ADMIN` if that file exists.

6. **Build the APEX app once, then let the repo own it.** APEX page metadata has no
   SQL DDL equivalent, so the first version comes from Page Designer:

   1. Open the 443 tunnel (`--target-port 443`), browse
      `https://localhost:8443/ords/apex` (accept the hostname warning), and sign in
      as `TODO_ADMIN`. The workspace password is the `todo-app-password` secret:
      `oci secrets secret-bundle get --secret-id "$(terraform output -raw app_password_secret_ocid)" --query 'data."secret-bundle-content".content' --raw-output | base64 -d`
      — that prints a secret to your terminal, so treat the session as recorded.
   2. App Builder → Create → **From a Table**, table `TODOS` (the workspace parsing
      schema is already `TODO_APP`). Name it `To-Do`, keep the default APEX Accounts
      authentication, and include the form page so rows can be edited — that is the
      "Mark as Done" behaviour, since the form toggles `IS_DONE`.
   3. Create Application and run it once.
   4. Export, commit, and from then on the repo is the source:

      ```bash
      ADB_LOCAL_PORT=1522 scripts/adb-sql.sh --as WORKSPACE --apex export
      git add sql/apex/f100.sql
      ```

   To catch a forgotten export: `ADB_LOCAL_PORT=1522 scripts/adb-sql.sh --apex-check`
   re-exports to a temporary directory and diffs against `sql/apex/f100.sql`,
   exiting 1 when the checked-in file is behind the database. The comparison is
   content-based, not timestamp-based, because importing an app bumps its
   `last_updated_on` — a clock comparison would report drift right after every
   legitimate import.

## Access

There is no public database endpoint, and `curl` is not an SQL client. Every path
in is either the load balancer or the bastion.

| Endpoint | Port | Reachable from | Needs |
| :--- | :--- | :--- | :--- |
| Flask to-do app | 80 / 443 on `<lb-ip>` | internet | nothing (demo) |
| Flask to-do app by name | 443 on `acme_domain` | internet, when `manage_dns` | a matching certificate |
| SSH to the instance | 22 | bastion session only | SSH key |
| SQL\*Net | 1522 on `adb_private_ip` | app subnet; you, through the tunnel | mTLS wallet + password from Vault |
| APEX / ORDS | 443 on `adb_private_ip` | app subnet; you, through the tunnel | APEX account |
| Vault secret bundle | OCI API | your API key | IAM |

```bash
terraform output app_url                     # http://<lb-ip>/
terraform output app_url_https               # https://<lb-ip>/  (self-signed by default)
terraform output app_url_dns                 # https://<acme_domain>/, with manage_dns
terraform output adb_private_ip              # private endpoint address
terraform output apex_url                    # private ORDS URL; tunnel only
terraform output bastion_session_command     # managed SSH to the instance
terraform output adb_sql_tunnel_command      # port-forward to the database
terraform output -raw adb_wallet_password    # wallet keystore password
```

**SQL** goes through the 1522 tunnel. `scripts/adb-sql.sh` rewrites the descriptor's
host to `127.0.0.1:<port>` and keeps the wallet's `ssl_server_cert_dn`, so TLS
identity is still pinned:

```bash
ADB_LOCAL_PORT=1522 scripts/adb-sql.sh --as ADMIN sql/01_schema.sql
ADB_LOCAL_PORT=1522 scripts/adb-sql.sh --as WORKSPACE --apex-check
```

**APEX** goes through the 443 tunnel: `https://localhost:8443/ords/apex`, or
`curl -k https://localhost:8443/ords/apex` if all you want is to see that it
answers. Nothing serves the database over HTTP outside that tunnel — there is no
ORDS REST module on `TODOS`, so the only HTTP views of the data are the Flask app
on the load balancer and APEX.

**Wallet**, for SQL Developer or a local client:

```bash
oci os object get \
  --namespace "$(terraform output -raw artifacts_bucket_namespace)" \
  --bucket-name "$(terraform output -raw artifacts_bucket_name)" \
  --name "$(terraform output -raw wallet_object)" \
  --file wallet.b64
base64 -d wallet.b64 > wallet.zip
```

**Bastion SSH**: run `terraform output -raw bastion_session_command`, then read the
proxy command from the session:

```bash
oci bastion session get --session-id <ocid1.bastionsession...> \
  --query 'data."ssh-metadata".command' --raw-output
```

Paste that `ProxyCommand` into:

```bash
ssh -i ~/.ssh/id_ed25519 \
  -o ProxyCommand='ssh -i ~/.ssh/id_ed25519 -W %h:%p -p 22 <session-ocid>@host.bastion.<region>.oci.oraclecloud.com' \
  opc@<instance-private-ip>
```

Managed SSH sessions need the Bastion plugin on the instance, which `agent_config`
enables.

## Certificates

**`self-signed`** (default): generates an RSA key and certificate for the load
balancer's public IP, so 443 works with no domain. Browsers warn; `curl` needs `-k`.

**`acme`** (trusted, no purchase):

```hcl
certificate_mode = "acme"
acme_domain      = "todo.example.com"   # or *.example.com
acme_email       = "you@example.com"
acme_dns_zone    = "example.com"        # public zone in OCI DNS
# acme_server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
```

DNS-01 is the only workable challenge: the name resolves to a load balancer, so no
host can answer an HTTP-01 request. The `acme` provider shells out to
`scripts/acme-dns-oci.sh`, which merges the challenge value into the
`_acme-challenge` TXT RRSet (OCI replaces a whole RRSet per update and stores TXT
values quoted) and removes only its own value on cleanup.

`dns.tf` writes the A record for `acme_domain` and rewrites it when the load
balancer IP changes, so the name follows the stack. Two caveats from OCI's
replace-the-whole-RRSet model:

- An RRSet that already exists at that name is **replaced**, not appended to. Set
  `manage_dns = false` if the record is managed elsewhere.
- An RRSet created outside Terraform must be adopted first:
  `terraform import 'oci_dns_rrset.app[0]' example.com/todo.example.com/A`.

Renewal is an apply: the certificate renews once fewer than 30 days remain, so a
monthly `terraform apply` is enough. Use the staging URL on the first run so a
broken DNS hook does not burn rate limit, then flip to production.

This hook is the one piece exercised only against a stubbed `oci` CLI. If a
challenge times out, run it by hand with `present`/`cleanup` and check the TXT
record in the console.

**`imported`**: set `tls_certificate_pem`, `tls_private_key_pem` and
`tls_chain_pem` in `terraform.tfvars` (sensitive).

## Verify

```bash
scripts/preflight.sh        # tools, auth, state, tunnel — run this first
scripts/verify.sh           # the deployment itself
```

`verify.sh` checks: ADB `AVAILABLE`, `isFreeTier=true`, 2 ECPU and a populated
`privateEndpointIp`; both Vault secrets populated; load balancer `ACTIVE` with a
healthy backend and a 200 from `/healthz` over **both** HTTP and HTTPS; both alarms
in `OK`; and when an A record is managed, that `acme_domain` resolves to the load
balancer and answers on HTTPS. It prints the APEX URL with a reminder that it is
tunnel-only. With `ADB_LOCAL_PORT` set it also runs `adb-sql.sh --apex-check`, so a
stale APEX export fails the checklist; without a tunnel that check reports SKIP
rather than passing silently.

CI runs the same gates from `.github/workflows/oci-demo.yml`: `static` on every
push and PR touching this directory (format, validate, `bash -n`, shellcheck), plus
two dispatch jobs — `live` for `verify.sh` on a hosted runner with the OCI secrets,
and `drift` for `--apex-check` on a self-hosted runner, because a hosted runner
cannot open a bastion session.

Manual console equivalents:

- [ ] Autonomous Database shows the **Always Free** badge and a private endpoint in
      the app subnet, with no public endpoint.
- [ ] Load balancer backend set reports the instance healthy on `/healthz`.
- [ ] 443 serves the app from the OCI Certificates object.
- [ ] Vault holds `adb-admin-password` and `todo-app-password`.
- [ ] Both alarms are in `OK`, the email subscription is confirmed.
- [ ] `http://<lb-ip>/` and `https://<lb-ip>/` list and mutate tasks.
- [ ] `ADB_LOCAL_PORT=1522 scripts/adb-sql.sh --as APP sql/02_table.sql` works
      through the tunnel, and does **not** work without it.
- [ ] `<apex_url>` signs in to `TODO_WORKSPACE` through the 443 tunnel.
- [ ] `sql/apex/f100.sql` matches the database (`--apex-check` exits 0).
- [ ] `acme_domain` resolves to the load balancer IP and serves HTTPS.

## Teardown

```bash
terraform destroy
```

The artifacts bucket is versioned, so a destroy can stop at "bucket not empty":
delete the object versions (console: empty bucket including versions, or
`oci os object bulk-delete --namespace <ns> --bucket-name <bucket> --all-versions --force`)
and re-run. The managed A record goes with the stack; if the name is shared with
something else, set `manage_dns = false` before destroying. The state bucket from
`bootstrap/` is separate; delete it last, or keep it for the next environment.

## What is deliberately not automated

- **First APEX page build.** The workspace, schema and table are scripted and the
  app is imported from `sql/apex/f100.sql`; producing that file for the first time
  needs Page Designer and `--apex export`. There is no offline generator for APEX
  page metadata, and hand-writing an export file is version-fragile.
- **Certificate authority.** No CA is created in any mode: `acme` uses a public CA
  over DNS-01, the other modes bring their own material. An OCI private CA is a
  separate service and is deliberately out of scope.
- **Secret rotation.** The ADMIN and schema passwords are generated once, stored in
  Vault, and also present in Terraform state (the state bucket is private and
  versioned). Rotate through Vault and `admin_password` together.

## Notes on the pieces that bite

- `cpu_core_count` and `data_storage_size_in_tbs` are **ignored** by OCI for Always
  Free databases; `is_free_tier = true` is the switch, and ECPU is the current way
  to express the shape (2 ECPU == 1 OCPU).
- Setting `subnet_id` on the database is what removes the public listener. It is an
  in-place update on an existing deployment, not a replacement.
- The database VNIC sits in the app subnet, so SQL\*Net is opened by the app
  security list (1522 from `private_subnet_cidr`), and the bastion endpoint — which
  also lives in that subnet — is what makes operator tunnels possible.
- Imported certificate content needs provider 9.x: `certificate_config` has no
  `certificate_pem` in 7.32, which is why the floor is `>= 9.0.0`.
- `oci_load_balancer_load_balancer.ip_addresses` is deprecated; `locals.tf` reads
  the public address from `ip_address_details` instead.
- The instance principal needs the policy from `iam.tf` to read the wallet object
  and the secret; cloud-init retries for five minutes while that propagates.
