# NixOS Build Tracker

A private record of the NixOS configuration hashes and Git commits you want to be
able to check on later — "did this exact build still reproduce?" — kept entirely on
AWS services that stay free, so it can sit idle for months without billing.

It stores a hash and the note you attach to it, scoped to one Cognito account. It is
not a general todo app: there is no cross-account view, no sharing, and no field
other than the hash, the description and a timestamp.

## How it fits together

| Surface | Implementation | Why |
| --- | --- | --- |
| Page | `index.html` in S3, served by CloudFront with Origin Access Control | private bucket, no server |
| Sign-in | Cognito user pool, email sign-in, Hosted UI | the browser never sees a secret |
| API | one Lambda behind a public Function URL | Function URLs cost nothing; API Gateway does not |
| Trust | the Lambda verifies the ID token itself against the pool's JWKS | a public URL with auth checked in code |
| Rows | DynamoDB `NixBuildTracker`, PROVISIONED 5/5, keyed on `userId` + `buildHash` | 5/5 sits inside the perpetual 25/25 allowance |
| Artifact | static `linux/amd64` Go binary, built and zipped by Nix | same zip, same hash, from any machine |

The Lambda has no VPC and no NAT gateway, which is what keeps the whole thing at
zero: a VPC-attached Lambda with NAT costs about $32/month on its own.

## Run it

```bash
cd projects/nix-build-tracker
nix develop                     # awscli2, go, jq, zip, curl, alejandra
ALERT_EMAIL=you@example.com ./deploy.sh
```

`ALERT_EMAIL` is required because the first resource created is the `$0.01` budget.
Every step describes before it creates, so re-running converges rather than
duplicating: the same bucket, distribution, pool, role and function are reused, and
the page is re-uploaded with the current endpoints and labelled with a fresh
invalidation.

`nix build .#lambda-zip` builds the Lambda artifact alone. It is reproducible: a
forced rebuild produces the same store path.

## Use it

Open the CloudFront URL printed at the end of the run, choose **Sign in with
email**, create an account and confirm Cognito's verification email. Submit a
config hash or commit and a note; the row appears in the table below the form,
newest first, readable only by that account.

## API

Both routes take `Authorization: Bearer <Cognito ID token>`.

| Request | Result |
| --- | --- |
| `GET /builds` | `{"userId": "...", "count": n, "builds": [{buildHash, description, createdAt}]}`, newest first |
| `POST /builds` | body `{"buildHash": "...", "description": "..."}` → `201` with the stored row |
| wrong path / method | `404` / `405` |
| no, forged or expired token | `401` |

`buildHash` takes 3–128 characters from `A-Za-z0-9._:+/=@-`; `description` is
optional, 500 characters at most. Re-submitting a hash rewrites its description
instead of failing.

```bash
curl -s "$(aws lambda get-function-url-config --function-name nix-build-tracker-api \
  --query FunctionUrl --output text)builds" -H "authorization: Bearer $ID_TOKEN"
```

## What it costs

Measured on 2026-10-30, eight days into its life: **$0.00** — Lambda, DynamoDB,
Cognito, CloudFront and S3 all reported zero (`aws ce get-cost-and-usage`).

Everything here is on a perpetual allowance, not a 12-month trial: Lambda 1M
requests + 400K GB-seconds, DynamoDB 25 RCU/25 WCU/25 GB, CloudFront 1 TB + 10M
requests, Cognito thousands of MAU, and Function URLs at no charge. Two AWS budgets
are free, and both slots are now used.

Two lines can drift, neither meaningfully:

- **S3 storage** is a 12-month allowance this legacy account no longer has. The page
  is ~12 KB, which is $0.023/GB-month — around four ten-thousandths of a cent a year.
- **CloudWatch Logs** retains forever unless a retention period is set. Volume from a
  128 MB function is trivial, but it is worth capping if the app ever gets noisy.

The free-tier limits are account-wide, so a second table or Lambda spends from the
same allowance.

## Known account limitation

`deploy.sh` asks for `ReservedConcurrentExecutions=5` as a runaway-loop guard, and
this AWS account cannot grant it: its Lambda concurrency ceiling is **10** in every
region (AWS's default is 1000), and AWS refuses a reservation that leaves fewer
than 10 unreserved. Service Quotas rejects any value at or below the 1000 default,
so only an AWS support case can lift it. The script reports the guard as unapplied
and exits non-zero after finishing everything else; re-running it once the ceiling
is raised applies the limit automatically. Until then the account-wide cap of 10 is
the only concurrency limit.

One implementation note, since it costs an afternoon to rediscover: a Function URL
with `AuthType=NONE` still returns `403` unless the function policy carries **both**
`lambda:InvokeFunctionUrl` (keyed on `lambda:FunctionUrlAuthType`) and
`lambda:InvokeFunction` (keyed on `InvokedViaFunctionUrl`). The CLI adds neither.
