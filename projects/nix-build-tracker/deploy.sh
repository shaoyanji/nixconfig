#!/usr/bin/env bash
#
# NixOS Build Tracker — idempotent Always-Free provisioning.
# Re-running converges to the same state; nothing is deleted.
#
set -euo pipefail

# ---------------------------------------------------------------- knobs ----
APP_NAME=${APP_NAME:-nix-build-tracker}
REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}
export AWS_REGION=$REGION
export AWS_PAGER= AWS_DEFAULT_OUTPUT=json

TABLE_NAME=${TABLE_NAME:-NixBuildTracker}
BUDGET_NAME=${BUDGET_NAME:-${APP_NAME}-zero-spend}
BUDGET_LIMIT=${BUDGET_LIMIT:-0.01}
LAMBDA_NAME=${APP_NAME}-api
ROLE_NAME=${APP_NAME}-lambda
POOL_NAME=${APP_NAME}-users
CLIENT_NAME=${APP_NAME}-web
RESERVED_CONCURRENCY=${RESERVED_CONCURRENCY:-5}
ALERT_EMAIL=${ALERT_EMAIL:-}

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE=$PROJECT_DIR/frontend/index.html.tmpl
STATE_FILE=$PROJECT_DIR/.deploy-state.env
ZIP=${ZIP:-}

# ----------------------------------------------------------------- util ----
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok() { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
die() {
	printf '\n\033[31merror:\033[0m %s\n\n' "$*" >&2
	exit 1
}

state_get() {
	[ -f "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | tail -1
}

state_set() {
	touch "$STATE_FILE"
	if grep -q "^$1=" "$STATE_FILE"; then
		# BSD and GNU sed disagree on -i, so rewrite through a temp file.
		awk -v k="$1" -v v="$2" -F= 'BEGIN{OFS="="} $1==k{$0=k OFS v} {print}' "$STATE_FILE" >"$STATE_FILE.tmp"
		mv "$STATE_FILE.tmp" "$STATE_FILE"
	else
		printf '%s=%s\n' "$1" "$2" >>"$STATE_FILE"
	fi
}

# ------------------------------------------------------------ preflight ----
log "preflight"
for tool in aws jq curl; do
	command -v "$tool" >/dev/null 2>&1 || die "missing '$tool' — run 'nix develop' in $PROJECT_DIR first"
done
command -v nix >/dev/null 2>&1 || [ -n "$ZIP" ] || die "missing 'nix' — needed to build the Lambda zip (or set ZIP=/path/to.zip)"
[ -f "$TEMPLATE" ] || die "frontend template not found: $TEMPLATE"
[ -n "$ALERT_EMAIL" ] || die "set ALERT_EMAIL=you@example.com so the \$0.01 budget has somewhere to send alerts"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
ok "account $ACCOUNT_ID as $CALLER_ARN in $REGION"

# ------------------------------------------------- 1. zero-spend budget ----
log "budget (\$$BUDGET_LIMIT/month, alerts to $ALERT_EMAIL)"
if aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" >/dev/null 2>&1; then
	ok "budget $BUDGET_NAME already exists"
else
	aws budgets create-budget \
		--account-id "$ACCOUNT_ID" \
		--budget "$(jq -n --arg n "$BUDGET_NAME" --arg amt "$BUDGET_LIMIT" \
			'{BudgetName: $n, BudgetLimit: {Amount: $amt, Unit: "USD"}, TimeUnit: "MONTHLY", BudgetType: "COST"}')" \
		--notifications-with-subscribers "$(jq -n --arg e "$ALERT_EMAIL" \
			'[{Notification: {NotificationType: "ACTUAL", ComparisonOperator: "GREATER_THAN", Threshold: 80, ThresholdType: "PERCENTAGE"},
			   Subscribers: [{SubscriptionType: "EMAIL", Address: $e}]},
			  {Notification: {NotificationType: "FORECASTED", ComparisonOperator: "GREATER_THAN", Threshold: 100, ThresholdType: "PERCENTAGE"},
			   Subscribers: [{SubscriptionType: "EMAIL", Address: $e}]}]')" >/dev/null
	ok "budget created (alerts to $ALERT_EMAIL; click the confirmation link if AWS sends one)"
fi

# ------------------------------------------------------ 2. dynamo table ----
log "dynamodb table $TABLE_NAME (PROVISIONED 5/5)"
if aws dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
	ok "table already exists"
else
	aws dynamodb create-table \
		--table-name "$TABLE_NAME" \
		--attribute-definitions AttributeName=userId,AttributeType=S AttributeName=buildHash,AttributeType=S \
		--key-schema AttributeName=userId,KeyType=HASH AttributeName=buildHash,KeyType=RANGE \
		--billing-mode PROVISIONED \
		--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 >/dev/null
	ok "table created"
fi
aws dynamodb wait table-exists --table-name "$TABLE_NAME"
ok "table ACTIVE"

# ------------------------------------------------------- 3. cognito pool ----
log "cognito user pool $POOL_NAME"
POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 \
	--query "UserPools[?Name=='$POOL_NAME'].Id | [0]" --output text)
if [ -z "$POOL_ID" ] || [ "$POOL_ID" = "None" ]; then
	POOL_ID=$(aws cognito-idp create-user-pool \
		--pool-name "$POOL_NAME" \
		--username-attributes email \
		--auto-verified-attributes email \
		--username-configuration CaseSensitive=false \
		--mfa-configuration OFF \
		--policies '{"PasswordPolicy":{"MinimumLength":12,"RequireLowercase":true,"RequireUppercase":true,"RequireNumbers":true,"RequireSymbols":false}}' \
		--query 'UserPool.Id' --output text)
	ok "user pool created"
else
	ok "user pool exists"
fi

# The callback URL is only known once CloudFront exists, and
# update-user-pool-client resets anything omitted — so every run re-applies
# the full client configuration with the current redirect URI.
sync_client() {
	local redirect=$1
	local base=(
		--user-pool-id "$POOL_ID"
		--client-name "$CLIENT_NAME"
		--explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_USER_SRP_AUTH ALLOW_REFRESH_TOKEN_AUTH
		--supported-identity-providers COGNITO
		--callback-urls "$redirect"
		--logout-urls "$redirect"
		--allowed-o-auth-flows implicit
		--allowed-o-auth-scopes openid email profile
		--allowed-o-auth-flows-user-pool-client
	)
	if [ -z "${CLIENT_ID:-}" ]; then
		CLIENT_ID=$(aws cognito-idp create-user-pool-client "${base[@]}" --no-generate-secret \
			--query 'UserPoolClient.ClientId' --output text)
		ok "app client created"
	else
		aws cognito-idp update-user-pool-client --client-id "$CLIENT_ID" "${base[@]}" >/dev/null
		ok "app client updated (callback $redirect)"
	fi
}

CLIENT_ID=$(aws cognito-idp list-user-pool-clients --user-pool-id "$POOL_ID" --max-results 60 \
	--query "UserPoolClients[?ClientName=='$CLIENT_NAME'].ClientId | [0]" --output text)
if [ "$CLIENT_ID" = "None" ]; then CLIENT_ID=""; fi
sync_client "http://localhost:8080/"

DOMAIN_PREFIX=${COGNITO_DOMAIN_PREFIX:-${APP_NAME}-${ACCOUNT_ID}}
DOMAIN_OWNER=$(aws cognito-idp describe-user-pool-domain --domain "$DOMAIN_PREFIX" \
	--query 'DomainDescription.UserPoolId' --output text 2>/dev/null || echo "None")
if [ "$DOMAIN_OWNER" = "$POOL_ID" ]; then
	ok "hosted UI domain exists"
elif [ "$DOMAIN_OWNER" = "None" ] || [ -z "$DOMAIN_OWNER" ]; then
	aws cognito-idp create-user-pool-domain --user-pool-id "$POOL_ID" --domain "$DOMAIN_PREFIX" >/dev/null ||
		die "could not claim cognito domain '$DOMAIN_PREFIX' — it is taken globally; set COGNITO_DOMAIN_PREFIX=<other>"
	ok "hosted UI domain created"
else
	die "cognito domain '$DOMAIN_PREFIX' belongs to another user pool ($DOMAIN_OWNER); set COGNITO_DOMAIN_PREFIX=<other>"
fi
COGNITO_HOSTED_UI="https://${DOMAIN_PREFIX}.auth.${REGION}.amazoncognito.com"

# ------------------------------------------------------------ 4. iam role ----
log "iam role $ROLE_NAME"
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || echo "")
if [ -z "$ROLE_ARN" ]; then
	ROLE_ARN=$(aws iam create-role --role-name "$ROLE_NAME" \
		--assume-role-policy-document "$(jq -n '{Version: "2012-10-17", Statement: [{Effect: "Allow", Principal: {Service: "lambda.amazonaws.com"}, Action: "sts:AssumeRole"}]}')" \
		--query 'Role.Arn' --output text)
	ok "role created"
	sleep 10 # IAM propagation; lambda rejects a role it cannot see yet
else
	ok "role exists"
fi

aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "${APP_NAME}-access" \
	--policy-document "$(jq -n \
		--arg region "$REGION" --arg account "$ACCOUNT_ID" \
		--arg table "$TABLE_NAME" --arg fn "$LAMBDA_NAME" \
		'{Version: "2012-10-17", Statement: [
			{Effect: "Allow", Action: ["dynamodb:PutItem", "dynamodb:Query"],
			 Resource: "arn:aws:dynamodb:\($region):\($account):table/\($table)"},
			{Effect: "Allow", Action: ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
			 Resource: ["arn:aws:logs:\($region):\($account):log-group:/aws/lambda/\($fn)",
			            "arn:aws:logs:\($region):\($account):log-group:/aws/lambda/\($fn):*"]}]}')" >/dev/null
ok "inline policy applied (dynamodb PutItem+Query, logs on /aws/lambda/$LAMBDA_NAME)"

# ------------------------------------------------------ 5. lambda function ----
log "lambda function $LAMBDA_NAME (nix build → provided.al2023)"
if [ -z "$ZIP" ]; then
	ZIP=$(nix build --no-link --print-out-paths "path:${PROJECT_DIR}#lambda-zip" | tail -1)
fi
[ -f "$ZIP" ] || die "lambda artifact not found: $ZIP"
ok "artifact $ZIP ($(du -h "$ZIP" | cut -f1))"

ENVIRONMENT=$(jq -n \
	--arg table "$TABLE_NAME" --arg pool "$POOL_ID" --arg client "$CLIENT_ID" --arg region "$REGION" \
	'{Variables: {TABLE_NAME: $table, USER_POOL_ID: $pool, COGNITO_CLIENT_ID: $client, COGNITO_REGION: $region}}')

if aws lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
	aws lambda update-function-code --function-name "$LAMBDA_NAME" --zip-file "fileb://$ZIP" >/dev/null
	aws lambda wait function-updated --function-name "$LAMBDA_NAME"
	# Architecture is fixed at creation; the CLI's update call has no such flag.
	aws lambda update-function-configuration \
		--function-name "$LAMBDA_NAME" \
		--runtime provided.al2023 \
		--handler bootstrap \
		--role "$ROLE_ARN" \
		--timeout 10 --memory-size 128 \
		--environment "$ENVIRONMENT" >/dev/null
	ok "code and configuration updated"
else
	aws lambda create-function \
		--function-name "$LAMBDA_NAME" \
		--runtime provided.al2023 \
		--architectures x86_64 \
		--handler bootstrap \
		--role "$ROLE_ARN" \
		--zip-file "fileb://$ZIP" \
		--timeout 10 --memory-size 128 \
		--environment "$ENVIRONMENT" \
		--description "NixOS Build Tracker API" >/dev/null
	ok "function created"
fi
aws lambda wait function-updated --function-name "$LAMBDA_NAME" 2>/dev/null || true
aws lambda wait function-active --function-name "$LAMBDA_NAME"

# Reserved concurrency is the runaway-loop guard. AWS only accepts it when the
# account keeps >= 10 unreserved executions, so a restricted account (ceiling 10)
# cannot reserve any at all — report that instead of hiding it.
CONCURRENCY_APPLIED=1
ACCOUNT_CONCURRENCY=$(aws lambda get-account-settings --query 'AccountLimit.ConcurrentExecutions' --output text)
if ! concurrency_err=$(aws lambda put-function-concurrency --function-name "$LAMBDA_NAME" \
	--reserved-concurrent-executions "$RESERVED_CONCURRENCY" 2>&1 >/dev/null); then
	if grep -q 'UnreservedConcurrentExecution' <<<"$concurrency_err"; then
		CONCURRENCY_APPLIED=0
		warn "reserved concurrency refused: this account's ceiling is $ACCOUNT_CONCURRENCY executions"
		warn "AWS needs > $((RESERVED_CONCURRENCY + 9)) to reserve $RESERVED_CONCURRENCY (> 10 must stay unreserved)"
		warn "the whole account is capped at $ACCOUNT_CONCURRENCY concurrent executions in the meantime"
	else
		die "could not set reserved concurrency: $concurrency_err"
	fi
else
	ok "reserved concurrency $RESERVED_CONCURRENCY (runaway-loop guard)"
fi

# OPTIONS is not accepted here: a function URL answers preflight itself.
CORS=$(jq -n '{AllowCredentials: false, AllowHeaders: ["authorization", "content-type"],
	AllowMethods: ["GET", "POST"], AllowOrigins: ["*"], MaxAge: 86400}')
if aws lambda get-function-url-config --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
	aws lambda update-function-url-config --function-name "$LAMBDA_NAME" \
		--auth-type NONE --cors "$CORS" >/dev/null
else
	aws lambda create-function-url-config --function-name "$LAMBDA_NAME" \
		--auth-type NONE --cors "$CORS" >/dev/null
fi
FUNCTION_URL=$(aws lambda get-function-url-config --function-name "$LAMBDA_NAME" --query FunctionUrl --output text)

# AuthType NONE is not enough on its own, and the CLI does not add the policy the
# console does. A public URL needs BOTH statements: InvokeFunctionUrl keyed on the
# URL auth type, and InvokeFunction keyed on InvokedViaFunctionUrl. With only the
# first, every request is a 403 that never reaches the function.
add_permission() {
	local statement=$1 action=$2
	shift 2
	if ! err=$(aws lambda add-permission --function-name "$LAMBDA_NAME" \
		--statement-id "$statement" --action "$action" --principal '*' "$@" 2>&1 >/dev/null); then
		grep -q 'ResourceConflictException' <<<"$err" || die "could not add $statement: $err"
		ok "$statement already present"
	else
		ok "$statement added"
	fi
}
add_permission FunctionURLAllowPublicAccess lambda:InvokeFunctionUrl --function-url-auth-type NONE
add_permission FunctionURLAllowInvokeViaUrl lambda:InvokeFunction --invoked-via-function-url
ok "function URL $FUNCTION_URL"

# ------------------------------------------------------- 6. frontend bucket ----
log "s3 frontend bucket"
SUFFIX=$(state_get FRONTEND_SUFFIX)
if [ -z "$SUFFIX" ]; then
	FOUND=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '${APP_NAME}-frontend-')].Name | [0]" --output text)
	if [ -n "$FOUND" ] && [ "$FOUND" != "None" ]; then
		SUFFIX=${FOUND#"${APP_NAME}-frontend-"}
	else
		SUFFIX=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
	fi
	state_set FRONTEND_SUFFIX "$SUFFIX"
	ok "suffix $SUFFIX (recorded in $STATE_FILE)"
fi
BUCKET="${APP_NAME}-frontend-${SUFFIX}"

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
	ok "bucket $BUCKET exists"
else
	if [ "$REGION" = "us-east-1" ]; then
		aws s3api create-bucket --bucket "$BUCKET" >/dev/null
	else
		aws s3api create-bucket --bucket "$BUCKET" \
			--create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
	fi
	ok "bucket $BUCKET created"
fi

aws s3api put-public-access-block --bucket "$BUCKET" \
	--public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true' >/dev/null
ok "public access blocked (CloudFront OAC is the only reader)"

# ----------------------------------------------------- 7. cloudfront + oac ----
log "cloudfront distribution"
OAC_NAME="${APP_NAME}-oac"
OAC_ID=$(aws cloudfront list-origin-access-controls \
	--query "OriginAccessControlList.Items[?Name=='$OAC_NAME'].Id | [0]" --output text)
if [ -z "$OAC_ID" ] || [ "$OAC_ID" = "None" ]; then
	OAC_ID=$(aws cloudfront create-origin-access-control \
		--origin-access-control-config "$(jq -n --arg n "$OAC_NAME" \
			'{Name: $n, Description: "OAC for the NixOS Build Tracker frontend", SigningProtocol: "sigv4",
			  SigningBehavior: "always", OriginAccessControlOriginType: "s3"}')" \
		--query 'OriginAccessControl.Id' --output text)
	ok "origin access control $OAC_ID created"
else
	ok "origin access control exists"
fi

DIST_ID=$(aws cloudfront list-distributions \
	--query "DistributionList.Items[?Comment=='${APP_NAME} frontend'].Id | [0]" --output text)
if [ -z "$DIST_ID" ] || [ "$DIST_ID" = "None" ]; then
	DIST_CONFIG=$(jq -n \
		--arg caller "${APP_NAME}-${ACCOUNT_ID}" \
		--arg comment "${APP_NAME} frontend" \
		--arg origin "${BUCKET}.s3.${REGION}.amazonaws.com" \
		--arg oac "$OAC_ID" \
		'{CallerReference: $caller, Comment: $comment, Enabled: true, DefaultRootObject: "index.html",
		  Origins: {Quantity: 1, Items: [{
		    Id: "s3-origin", DomainName: $origin,
		    S3OriginConfig: {OriginAccessIdentity: ""},
		    OriginAccessControlId: $oac}]},
		  DefaultCacheBehavior: {
		    TargetOriginId: "s3-origin",
		    ViewerProtocolPolicy: "redirect-to-https",
		    AllowedMethods: {Quantity: 2, Items: ["GET", "HEAD"], CachedMethods: {Quantity: 2, Items: ["GET", "HEAD"]}},
		    CachePolicyId: "658327ea-f89d-4fab-a63d-7e88639e58f6",
		    Compress: true},
		  PriceClass: "PriceClass_100", HttpVersion: "http2", IsIPV6Enabled: true}')
	DIST_ID=$(aws cloudfront create-distribution --distribution-config "$DIST_CONFIG" \
		--query 'Distribution.Id' --output text)
	ok "distribution $DIST_ID created"
else
	ok "distribution $DIST_ID exists"
fi

DIST_ARN=$(aws cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.ARN' --output text)
CF_DOMAIN=$(aws cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DomainName' --output text)
REDIRECT_URI="https://${CF_DOMAIN}/"

aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$(jq -n \
	--arg bucket "$BUCKET" --arg arn "$DIST_ARN" \
	'{Version: "2012-10-17", Statement: [{Sid: "AllowCloudFrontOAC", Effect: "Allow",
	   Principal: {Service: "cloudfront.amazonaws.com"}, Action: "s3:GetObject",
	   Resource: "arn:aws:s3:::\($bucket)/*", Condition: {StringEquals: {"AWS:SourceArn": $arn}}}]}')"
ok "bucket policy pinned to $DIST_ARN"

log "waiting for cloudfront to deploy (first run: a few minutes)"
aws cloudfront wait distribution-deployed --id "$DIST_ID"
ok "distribution deployed"

# --------------------------------------------------- 8. wire the frontend ----
log "frontend"
sync_client "$REDIRECT_URI"

render=$(mktemp)
sed -e "s|__API_URL__|${FUNCTION_URL%/}|g" \
	-e "s|__COGNITO_DOMAIN__|${COGNITO_HOSTED_UI}|g" \
	-e "s|__REGION__|${REGION}|g" \
	-e "s|__CLIENT_ID__|${CLIENT_ID}|g" \
	-e "s|__USER_POOL_ID__|${POOL_ID}|g" \
	-e "s|__REDIRECT_URI__|${REDIRECT_URI}|g" \
	"$TEMPLATE" >"$render"

if grep -q '__[A-Z_]*__' "$render"; then
	die "unreplaced placeholder in rendered index.html: $(grep -o '__[A-Z_]*__' "$render" | sort -u | tr '\n' ' ')"
fi

aws s3api put-object --bucket "$BUCKET" --key index.html \
	--body "$render" --content-type 'text/html; charset=utf-8' \
	--cache-control 'no-cache, must-revalidate' >/dev/null
rm -f "$render"
ok "index.html uploaded with the live endpoints injected"

INVALIDATION=$(aws cloudfront create-invalidation --distribution-id "$DIST_ID" \
	--paths '/index.html' '/*' --query 'Invalidation.Id' --output text)
aws cloudfront wait invalidation-completed --distribution-id "$DIST_ID" --id "$INVALIDATION" 2>/dev/null ||
	warn "invalidation $INVALIDATION still in flight — the page refreshes within a minute"
ok "cache invalidated"

# --------------------------------------------------------- 9. validation ----
log "validation"

TABLE_JSON=$(aws dynamodb describe-table --table-name "$TABLE_NAME" --query 'Table')
table_status=$(jq -r '.TableStatus' <<<"$TABLE_JSON")
table_rcu=$(jq -r '.ProvisionedThroughput.ReadCapacityUnits' <<<"$TABLE_JSON")
table_wcu=$(jq -r '.ProvisionedThroughput.WriteCapacityUnits' <<<"$TABLE_JSON")
[ "$table_status" = "ACTIVE" ] || die "table is $table_status, expected ACTIVE"
[ "$table_rcu" -le 25 ] && [ "$table_wcu" -le 25 ] || die "table capacity exceeds the 25/25 free tier"
ok "table ACTIVE · ${table_rcu} RCU / ${table_wcu} WCU · $(jq -r '.ItemCount' <<<"$TABLE_JSON") item(s)"

concurrency=$(aws lambda get-function-concurrency --function-name "$LAMBDA_NAME" \
	--query 'ReservedConcurrentExecutions' --output text)
if [ "$concurrency" = "$RESERVED_CONCURRENCY" ]; then
	ok "reserved concurrency $concurrency"
else
	CONCURRENCY_APPLIED=0
	warn "reserved concurrency ${concurrency/None/unset} — account ceiling $ACCOUNT_CONCURRENCY, needs > $((RESERVED_CONCURRENCY + 9))"
fi

budget=$(aws budgets describe-budgets --account-id "$ACCOUNT_ID" \
	--query "Budgets[?BudgetName=='$BUDGET_NAME'].[BudgetName, BudgetLimit.Amount] | [0]" --output text)
[ -n "$budget" ] || die "budget $BUDGET_NAME not found"
ok "budget $budget USD"

curl -fsS --max-time 15 "$FUNCTION_URL" >/dev/null || die "function URL did not answer a health check"
ok "function URL answers unauthenticated GET / (health)"

curl -fsS --max-time 15 "$REDIRECT_URI" | grep -q 'NixOS' || die "cloudfront did not serve index.html"
ok "cloudfront serves index.html"

if [ "$CONCURRENCY_APPLIED" != 1 ]; then
	printf '\n\033[1;33mDeployed, with one constraint unmet.\033[0m\n'
	cat <<EOF
  Reserved concurrency ($RESERVED_CONCURRENCY) could NOT be set: this AWS account's Lambda
  concurrency ceiling is $ACCOUNT_CONCURRENCY executions in every region, and AWS
  reserves nothing unless at least 10 stay unreserved. Service Quotas will not
  raise it (it only accepts values above the 1000 default), so this needs an AWS
  support request. Until then the account-wide ceiling of $ACCOUNT_CONCURRENCY is the
  only concurrency cap. Re-run this script after the ceiling is lifted and the
  $RESERVED_CONCURRENCY guard is applied automatically.
EOF
	printf '\n'
	exit 1
fi

printf '\n\033[1;32mDeployed.\033[0m\n\n'
cat <<EOF
  Frontend   $REDIRECT_URI
  API        ${FUNCTION_URL%/}
  User pool  $POOL_ID
  App client $CLIENT_ID
  Table      $TABLE_NAME ($REGION)

  Open the frontend, choose "Sign in with email", create an account, and confirm
  the verification email Cognito sends. Then submit a hash — it appears in the
  table and is readable only by that account.
EOF
printf '\n'
