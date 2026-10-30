package main

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"os"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

const (
	maxBuilds      = 200
	maxDescription = 500
	maxHash        = 128
	jwksTTL        = time.Hour
	requestTimeout = 8 * time.Second
)

var (
	tableName  = envOr("TABLE_NAME", "NixBuildTracker")
	userPoolID = envOr("USER_POOL_ID", "")
	clientID   = envOr("COGNITO_CLIENT_ID", "")
	poolRegion = envOr("COGNITO_REGION", envOr("AWS_REGION", "us-east-1"))
)

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// ---------- token verification ----------

type identity struct {
	Subject string
	Email   string
	Expires time.Time
}

type jwk struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type verifier struct {
	mu      sync.Mutex
	keys    map[string]*rsa.PublicKey
	fetched time.Time
	client  *http.Client
}

var tokens = &verifier{client: &http.Client{Timeout: 5 * time.Second}}

func (v *verifier) jwksURL() string {
	return fmt.Sprintf("https://cognito-idp.%s.amazonaws.com/%s/.well-known/jwks.json", poolRegion, userPoolID)
}

func (v *verifier) refresh(force bool) error {
	v.mu.Lock()
	defer v.mu.Unlock()
	if !force && len(v.keys) > 0 && time.Since(v.fetched) < jwksTTL {
		return nil
	}

	resp, err := v.client.Get(v.jwksURL())
	if err != nil {
		return fmt.Errorf("fetch jwks: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("fetch jwks: status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return fmt.Errorf("read jwks: %w", err)
	}

	var set struct {
		Keys []jwk `json:"keys"`
	}
	if err := json.Unmarshal(body, &set); err != nil {
		return fmt.Errorf("parse jwks: %w", err)
	}

	keys := make(map[string]*rsa.PublicKey, len(set.Keys))
	for _, k := range set.Keys {
		if k.Kty != "RSA" || k.Kid == "" {
			continue
		}
		nb, err := base64.RawURLEncoding.DecodeString(k.N)
		if err != nil {
			continue
		}
		eb, err := base64.RawURLEncoding.DecodeString(k.E)
		if err != nil {
			continue
		}
		e := new(big.Int).SetBytes(eb)
		if !e.IsInt64() || e.Int64() <= 0 {
			continue
		}
		keys[k.Kid] = &rsa.PublicKey{N: new(big.Int).SetBytes(nb), E: int(e.Int64())}
	}
	if len(keys) == 0 {
		return errors.New("jwks holds no usable RSA key")
	}

	v.keys, v.fetched = keys, time.Now()
	return nil
}

func (v *verifier) key(kid string) (*rsa.PublicKey, error) {
	if err := v.refresh(false); err != nil {
		return nil, err
	}
	v.mu.Lock()
	key, found := v.keys[kid]
	v.mu.Unlock()
	if found {
		return key, nil
	}
	// A key rotation invalidates the cache; one forced refetch keeps sign-in working.
	if err := v.refresh(true); err != nil {
		return nil, err
	}
	v.mu.Lock()
	key, found = v.keys[kid]
	v.mu.Unlock()
	if !found {
		return nil, fmt.Errorf("unknown signing key %q", kid)
	}
	return key, nil
}

var errUnauthorized = errors.New("unauthorized")

type claims struct {
	Subject  string `json:"sub"`
	Email    string `json:"email"`
	TokenUse string `json:"token_use"`
	Audience string `json:"aud"`
	ClientID string `json:"client_id"`
	Issuer   string `json:"iss"`
	Expires  int64  `json:"exp"`
}

func authorize(header string) (identity, error) {
	token, ok := strings.CutPrefix(strings.TrimSpace(header), "Bearer ")
	if !ok || token == "" {
		return identity{}, errUnauthorized
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return identity{}, errUnauthorized
	}

	rawHeader, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return identity{}, errUnauthorized
	}
	var head struct {
		Kid string `json:"kid"`
		Alg string `json:"alg"`
	}
	if err := json.Unmarshal(rawHeader, &head); err != nil || head.Alg != "RS256" {
		return identity{}, errUnauthorized
	}

	pub, err := tokens.key(head.Kid)
	if err != nil {
		return identity{}, err
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return identity{}, errUnauthorized
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(pub, crypto.SHA256, digest[:], sig); err != nil {
		return identity{}, errUnauthorized
	}

	rawClaims, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return identity{}, errUnauthorized
	}
	var c claims
	if err := json.Unmarshal(rawClaims, &c); err != nil {
		return identity{}, errUnauthorized
	}

	wantIssuer := fmt.Sprintf("https://cognito-idp.%s.amazonaws.com/%s", poolRegion, userPoolID)
	if c.Issuer != wantIssuer || c.Subject == "" {
		return identity{}, errUnauthorized
	}
	if c.Expires <= time.Now().Unix() {
		return identity{}, errUnauthorized
	}
	switch c.TokenUse {
	case "id":
		if c.Audience != clientID {
			return identity{}, errUnauthorized
		}
	case "access":
		if c.ClientID != clientID {
			return identity{}, errUnauthorized
		}
	default:
		return identity{}, errUnauthorized
	}

	return identity{Subject: c.Subject, Email: c.Email, Expires: time.Unix(c.Expires, 0)}, nil
}

// ---------- storage ----------

var (
	dbOnce   sync.Once
	dbClient *dynamodb.Client
	dbErr    error
)

func db() (*dynamodb.Client, error) {
	dbOnce.Do(func() {
		cfg, err := awsconfig.LoadDefaultConfig(context.Background())
		if err != nil {
			dbErr = err
			return
		}
		dbClient = dynamodb.NewFromConfig(cfg)
	})
	return dbClient, dbErr
}

type build struct {
	BuildHash   string `json:"buildHash"`
	Description string `json:"description"`
	CreatedAt   string `json:"createdAt"`
}

func itemString(item map[string]types.AttributeValue, key string) string {
	if v, ok := item[key].(*types.AttributeValueMemberS); ok {
		return v.Value
	}
	return ""
}

func listBuilds(ctx context.Context, userID string) ([]build, error) {
	client, err := db()
	if err != nil {
		return nil, err
	}

	in := &dynamodb.QueryInput{
		TableName:              &tableName,
		KeyConditionExpression: aws.String("userId = :u"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":u": &types.AttributeValueMemberS{Value: userID},
		},
	}

	builds := []build{}
	for len(builds) < maxBuilds {
		page, err := client.Query(ctx, in)
		if err != nil {
			return nil, err
		}
		for _, item := range page.Items {
			builds = append(builds, build{
				BuildHash:   itemString(item, "buildHash"),
				Description: itemString(item, "description"),
				CreatedAt:   itemString(item, "createdAt"),
			})
		}
		if len(page.LastEvaluatedKey) == 0 {
			break
		}
		in.ExclusiveStartKey = page.LastEvaluatedKey
	}

	sort.Slice(builds, func(i, j int) bool { return builds[i].CreatedAt > builds[j].CreatedAt })
	if len(builds) > maxBuilds {
		builds = builds[:maxBuilds]
	}
	return builds, nil
}

func putBuild(ctx context.Context, id identity, hash, description string) (build, error) {
	client, err := db()
	if err != nil {
		return build{}, err
	}

	createdAt := time.Now().UTC().Format(time.RFC3339)
	item := map[string]types.AttributeValue{
		"userId":      &types.AttributeValueMemberS{Value: id.Subject},
		"buildHash":   &types.AttributeValueMemberS{Value: hash},
		"description": &types.AttributeValueMemberS{Value: description},
		"createdAt":   &types.AttributeValueMemberS{Value: createdAt},
	}
	if id.Email != "" {
		item["email"] = &types.AttributeValueMemberS{Value: id.Email}
	}

	_, err = client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: &tableName,
		Item:      item,
	})
	if err != nil {
		return build{}, err
	}
	return build{BuildHash: hash, Description: description, CreatedAt: createdAt}, nil
}

// ---------- http ----------

type apiError struct {
	Error string `json:"error"`
}

func respond(status int, body any) (events.APIGatewayV2HTTPResponse, error) {
	payload, err := json.Marshal(body)
	if err != nil {
		status = http.StatusInternalServerError
		payload = []byte(`{"error":"internal error"}`)
	}
	return events.APIGatewayV2HTTPResponse{
		StatusCode:      status,
		Headers:         map[string]string{"content-type": "application/json"},
		Body:            string(payload),
		IsBase64Encoded: false,
	}, nil
}

func headerValue(headers map[string]string, name string) string {
	if v, ok := headers[name]; ok {
		return v
	}
	for key, value := range headers {
		if strings.EqualFold(key, name) {
			return value
		}
	}
	return ""
}

var hashPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:+/=@-]{2,127}$`)

func handle(ctx context.Context, req events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	path := req.RequestContext.HTTP.Path
	if path == "" {
		path = req.RawPath
	}
	method := req.RequestContext.HTTP.Method
	if method == "" {
		method = http.MethodGet
	}

	switch path {
	case "/", "/health":
		if method != http.MethodGet {
			return respond(http.StatusMethodNotAllowed, apiError{"method not allowed"})
		}
		return respond(http.StatusOK, map[string]any{
			"status":  "ok",
			"service": "nix-build-tracker",
			"table":   tableName,
		})
	case "/builds":
	default:
		return respond(http.StatusNotFound, apiError{"not found"})
	}

	caller, err := authorize(headerValue(req.Headers, "authorization"))
	if err != nil {
		return respond(http.StatusUnauthorized, apiError{"missing or invalid Cognito bearer token"})
	}

	switch method {
	case http.MethodGet:
		builds, err := listBuilds(ctx, caller.Subject)
		if err != nil {
			return respond(http.StatusInternalServerError, apiError{"could not read builds"})
		}
		return respond(http.StatusOK, map[string]any{
			"userId": caller.Subject,
			"count":  len(builds),
			"builds": builds,
		})

	case http.MethodPost:
		body := req.Body
		if req.IsBase64Encoded {
			decoded, err := base64.StdEncoding.DecodeString(body)
			if err != nil {
				return respond(http.StatusBadRequest, apiError{"body is not valid base64"})
			}
			body = string(decoded)
		}

		var in struct {
			BuildHash   string `json:"buildHash"`
			Description string `json:"description"`
		}
		if err := json.Unmarshal([]byte(body), &in); err != nil {
			return respond(http.StatusBadRequest, apiError{"body must be JSON: {\"buildHash\":\"...\",\"description\":\"...\"}"})
		}
		in.BuildHash = strings.TrimSpace(in.BuildHash)
		in.Description = strings.TrimSpace(in.Description)
		if !hashPattern.MatchString(in.BuildHash) || len(in.BuildHash) > maxHash {
			return respond(http.StatusBadRequest, apiError{"buildHash must be 3-128 chars of [A-Za-z0-9._:+/=@-]"})
		}
		if len(in.Description) > maxDescription {
			return respond(http.StatusBadRequest, apiError{fmt.Sprintf("description must be at most %d chars", maxDescription)})
		}

		saved, err := putBuild(ctx, caller, in.BuildHash, in.Description)
		if err != nil {
			return respond(http.StatusInternalServerError, apiError{"could not save build"})
		}
		return respond(http.StatusCreated, saved)

	default:
		return respond(http.StatusMethodNotAllowed, apiError{"method not allowed"})
	}
}

func main() {
	if userPoolID == "" || clientID == "" {
		// A misconfigured function fails loudly in the logs rather than 401-ing forever.
		fmt.Fprintln(os.Stderr, "USER_POOL_ID and COGNITO_CLIENT_ID must be set")
		os.Exit(1)
	}
	lambda.Start(handle)
}
