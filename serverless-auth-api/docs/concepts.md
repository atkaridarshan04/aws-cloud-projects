# 📚 Concepts & Services — Serverless Auth + Multi-Tenant API

Deep notes on every AWS service, auth pattern, and design decision used in this project.

---

## 👤 Amazon Cognito

Cognito is AWS's managed identity service. It handles everything you'd otherwise have to build yourself for user auth.

### User Pools vs Identity Pools

These are two completely separate things that are often confused:

| | User Pool | Identity Pool |
|--|-----------|---------------|
| Purpose | User directory — signup, login, JWT issuance | Exchange tokens for temporary AWS credentials |
| What it gives you | JWT tokens (ID, Access, Refresh) | `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token` |
| Use case | Authenticate users to your API | Let users directly call AWS services (S3, DynamoDB) from client |
| Used in this project | ✅ Yes | ❌ No |

**In this project we only use a User Pool.** Users authenticate to get a JWT, and that JWT is used to call our API Gateway — not AWS services directly.

### What a User Pool Gives You Out of the Box
- User registration with email/phone verification
- Secure password storage (you never see the password)
- Login with username/password
- MFA support (TOTP, SMS)
- Password policies (min length, complexity)
- Account recovery (forgot password flow)
- JWT issuance on successful login
- Token refresh via Refresh Token
- Hosted UI (optional — a pre-built login page)

### Custom Attributes
Cognito lets you add custom attributes to user profiles. They're prefixed with `custom:` and are embedded in the JWT.

In this project:
- `custom:tenant_id` — which company/org this user belongs to
- `custom:role` — `admin` or `member`

These are set at signup and travel in every JWT the user receives. This is the mechanism that carries tenant identity from login all the way to the database query — without any database lookup.

### Cognito App Client
To interact with a User Pool programmatically, you create an **App Client**. It has a client ID (and optionally a client secret). Your frontend or Lambda uses the client ID when calling Cognito's auth APIs (`InitiateAuth`, `SignUp`, etc.).

---

## 🔑 JWT — JSON Web Tokens

A JWT is a compact, URL-safe token that carries **claims** (key-value pairs of information) and is **cryptographically signed** so the receiver can verify it wasn't tampered with.

### Structure

A JWT has three parts separated by dots: `header.payload.signature`

```
eyJhbGciOiJSUzI1NiJ9   ←  header (base64): algorithm used
.
eyJzdWIiOiJ1c2VyXzEyMyIsImN1c3RvbTp0ZW5hbnRfaWQiOiJ0ZW5hbnRfYWNtZSJ9  ← payload (base64): the claims
.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c  ← signature
```

**The signature is the critical part.** It's created by Cognito using its private key. Anyone can read the payload (it's just base64), but only Cognito can create a valid signature. The native JWT authorizer verifies the signature using Cognito's **public key** — if the signature is valid, the claims are trustworthy.

### Cognito's Three Tokens

When a user logs in, Cognito returns three tokens in one response. They are **not** received at registration — only after a successful login.

```
Registration → account created, verification email sent → NO tokens yet
Login        → credentials verified → tokens issued NOW
```

```json
{
  "IdToken":      "eyJ...",   ← send this to YOUR API on every request
  "AccessToken":  "eyJ...",   ← use this to call COGNITO's own APIs
  "RefreshToken": "eyJ..."    ← use this to silently renew the above two
}
```

---

### ID Token vs Access Token — The Real Difference

Both are JWTs. Same format, same structure, issued at the same time, expire at the same time (1 hour). The only difference is **what claims are inside** and **who they're intended for**.

| | ID Token | Access Token |
|--|----------|--------------|
| **Contains** | `email`, `custom:tenant_id`, `custom:role`, `sub` | Scopes (`openid`, `profile`), Cognito groups |
| **Intended for** | YOUR API — to identify the user | COGNITO's own APIs — to act on behalf of the user |
| **Used in this project** | ✅ Yes — sent as `Authorization: Bearer` to API Gateway routes | ✅ Yes — sent to `GET /auth/me`, `POST /auth/logout` which call Cognito APIs |
| **Why not swap them** | Access Token doesn't carry `tenant_id` or `role` — your custom attributes aren't in it | ID Token isn't accepted by Cognito's management APIs |

**The short version:** same type of thing, different payload, different intended recipient. Both are actively used in this project — just for different routes.

**Why does Access Token exist at all?** It comes from the OAuth 2.0 + OpenID Connect standards Cognito is built on. OAuth was designed for third-party access (like "Login with Google") where you need strict separation between *identity* (ID Token) and *permissions to act* (Access Token). In this project:
- ID Token → sent to your API Gateway routes → native JWT authorizer validates it
- Access Token → sent to Cognito-proxying routes (`/auth/me`, `/auth/logout`) → Cognito validates it

**Why this separation exists — security by design:**
Each token has a minimal, specific purpose — this is least privilege applied to tokens themselves. Your API only ever receives the ID Token, so even if your Lambda code is compromised, it can't call `GlobalSignOut` or `ChangePassword` — Cognito rejects the ID Token for those operations. Conversely, if the Access Token leaks, an attacker can't use it to impersonate the user on your API — it carries no `tenant_id` or `role`, and your Lambda Authorizer would reject it. The two tokens can't be swapped, so a breach of one doesn't automatically compromise the other.

Think of it like a building:
- ID Token = employee badge (proves who you are, opens room doors)
- Access Token = facilities keycard (operates building systems — elevators, HVAC)
- Same person holds both, used in completely different places for completely different purposes

**Cognito management operations that require the Access Token:**

| Operation | Cognito API | What it does |
|-----------|-------------|--------------|
| Get user profile | `GetUser` | Returns all user attributes including `custom:tenant_id`, `custom:role` |
| Change password | `ChangePassword` | Updates password (requires old password too) |
| Update attributes | `UpdateUserAttributes` | Change mutable attributes like `custom:role` |
| Sign out everywhere | `GlobalSignOut` | Invalidates all tokens for this user across all devices |

---

### Refresh Token — Silent Renewal

The Refresh Token's only job is to get new ID + Access tokens when they expire — without the user re-entering their password.

```
ID Token expires after 1 hour → API returns 401
        ↓
App silently sends Refresh Token to Cognito
        ↓
Cognito returns fresh ID Token + Access Token
        ↓
User never notices, no re-login prompt

Refresh Token expires after 30 days
        ↓
No silent renewal possible → user must log in again
```

**Why short-lived ID/Access tokens?** If a token gets stolen, the attacker can only use it for at most 1 hour. The Refresh Token is stored more securely and never sent on every API call — much harder to steal.

---

### Where Tokens Are Stored (Client Side)

Same concept as building auth from scratch — you generate a JWT, send it to the browser, browser stores it and attaches it to every request. Cognito does the same thing, just handles the generation and signing for you:

```
From scratch:   Your server signs JWT → browser stores in cookie → sent on every request
With Cognito:   Cognito signs JWT     → browser stores in cookie → sent on every request
```

Storage options:
- **httpOnly cookie** — most secure, JS can't read it (XSS protection)
- **localStorage** — convenient but readable by JS (XSS risk)
- **In-memory** — most secure but lost on page refresh

### Key Claims in the ID Token

```json
{
  "sub": "a1b2c3d4-...",           ← unique user ID (UUID, never changes)
  "email": "user@acme.com",
  "custom:tenant_id": "tenant_acme",
  "custom:role": "admin",
  "iss": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXX",  ← issuer (your User Pool)
  "aud": "your-app-client-id",     ← audience (your App Client)
  "exp": 1714000000,               ← expiry (Unix timestamp)
  "iat": 1713996400                ← issued at
}
```

API Gateway's native JWT authorizer checks `iss` (must match your User Pool), `aud` (must match your App Client), and `exp` (must not be in the past) — in addition to verifying the signature.

### JWKS — JSON Web Key Set

Cognito publishes its public keys at a well-known URL:
```
https://cognito-idp.<region>.amazonaws.com/<user-pool-id>/.well-known/jwks.json
```

The native JWT authorizer (and Lambda Authorizers when used) fetch this URL to get the public keys and verify the JWT signature. The `kid` (key ID) field in the JWT header tells which key to use — Cognito rotates keys periodically so there can be multiple.

---

## 🚦 API Gateway — JWT Authorization

### Native JWT Authorizer (what we use)

API Gateway HTTP API has JWT validation built directly into it — no Lambda needed. You configure two things:
- **Issuer** — your Cognito User Pool URL (`https://cognito-idp.<region>.amazonaws.com/<pool-id>`)
- **Audience** — your App Client ID

This authorizer is attached **only to the `/projects` routes** (which use the ID Token). The `/auth/me` and `/auth/logout` routes use the Access Token, whose `aud` claim is the Cognito endpoint — not the App Client ID — so the gateway authorizer would reject it. Those routes are left without a gateway authorizer; the Lambda validates the Access Token by passing it directly to Cognito's APIs.

API Gateway handles everything internally on every protected request:

```
Client sends Bearer token
        ↓
API Gateway fetches Cognito JWKS (cached internally)
        ↓
Verifies signature, checks exp / iss / aud
        ↓
Valid   → forwards all JWT claims to Lambda, request proceeds
Invalid → returns 401 immediately, Lambda never invoked
```

Claims arrive in the business Lambda as:
```python
claims = event['requestContext']['authorizer']['jwt']['claims']
tenant_id = claims['custom:tenant_id']
role      = claims['custom:role']
user_id   = claims['sub']
```

No library. No layer. No extra Lambda invocation. AWS handles it.

---

### Lambda Authorizer — When to Use It Instead

A Lambda Authorizer is a Lambda function that API Gateway calls before your business Lambda. You write the JWT validation yourself and return an IAM policy.

**Use it when you need custom logic during auth:**
- Check if the tenant's subscription is active (requires a DB lookup)
- Check if the user is banned or suspended
- Multiple identity providers that need claim normalization
- Fine-grained per-route permission logic beyond what's in the JWT
- Audit logging every single auth attempt

**How it works:**
```
Client request (with JWT)
        ↓
API Gateway invokes Lambda Authorizer
        ↓
Your code: fetch JWKS → verify signature → check claims → custom logic
        ↓
Return IAM policy (Allow/Deny) + context object
        ↓
API Gateway caches policy by token (configurable TTL)
        ↓
Business Lambda runs with context.authorizer.tenant_id
```

The IAM policy response shape:
```json
{
  "principalId": "user-sub",
  "policyDocument": {
    "Version": "2012-10-17",
    "Statement": [{ "Action": "execute-api:Invoke", "Effect": "Allow", "Resource": "<method-arn>" }]
  },
  "context": { "tenant_id": "tenant_acme", "role": "admin" }
}
```

**Caching tradeoff:** API Gateway caches the policy by token for a configurable TTL (0–3600s). If you ban a user, the cached policy keeps them authorized until TTL expires. 5 minutes is a common balance.

**For simple JWT validation + claim forwarding** (our case) → native JWT authorizer is the right choice. Lambda Authorizer adds complexity only justified by custom logic requirements.

---

## 🏢 Multi-Tenancy Patterns

Multi-tenancy means multiple customers (tenants) share the same application infrastructure. There are three main isolation models:

### Silo Model — Separate Everything
Each tenant gets their own database, their own infrastructure stack.
- ✅ Strongest isolation — a bug in one tenant's stack can't affect others
- ✅ Easy compliance (data never co-mingled)
- ❌ Expensive — N tenants = N databases
- ❌ Operationally complex — deployments, updates, monitoring multiplied by N
- **Used by:** enterprises with strict compliance requirements, very large tenants

### Pool Model — Shared Everything (what we build)
All tenants share the same table. Every item has `tenant_id` as part of the key.
- ✅ Cost-efficient — one table, one Lambda, one deployment
- ✅ Simple operations — update once, all tenants get it
- ✅ Scales naturally with DynamoDB
- ❌ Isolation is enforced by code — a bug could theoretically leak data
- ❌ One noisy tenant can consume capacity (mitigated with DynamoDB on-demand or per-tenant capacity)
- **Used by:** most SaaS products at scale (Notion, Linear, etc.)

### Bridge Model — Separate Tables, Shared Infra
Each tenant gets their own DynamoDB table, but the same Lambda and API.
- Middle ground — stronger isolation than pool, cheaper than silo
- More complex routing logic

**We use the Pool Model** — it's the most common, most practical, and teaches the most important patterns.

### Tenant Isolation in DynamoDB (Pool Model)

The table design is everything:

```
Table: projects
PK: tenant_id
SK: project_id
```

Every query must include `tenant_id`. The Lambda gets `tenant_id` from the JWT context (not from user input), so:

```python
# HTTP API path — claims forwarded automatically by native JWT authorizer
claims = event['requestContext']['authorizer']['jwt']['claims']
tenant_id = claims['custom:tenant_id']

response = table.query(
    KeyConditionExpression=Key('tenant_id').eq(tenant_id)  # always scoped
)
```

A user cannot pass a different `tenant_id` in the request body to access another tenant's data — because the Lambda ignores any `tenant_id` in the request and only uses the one from the verified JWT context.

---

## 🔐 Authentication vs Authorization

These two words are often used interchangeably but mean completely different things:

### Authentication (AuthN) — *Who are you?*
Proving identity. The user provides credentials (password, biometric, OTP), and the system verifies them and issues a token.

```
User: "I am alice@acme.com, my password is ..."
Cognito: "Credentials valid. Here's your JWT."
```

**Cognito User Pool handles this entirely.**

### Authorization (AuthZ) — *What are you allowed to do?*
Given that we know who you are, deciding what actions you can perform on which resources.

```
Alice (tenant_acme, role=member) → GET /projects → Allowed
Alice (tenant_acme, role=member) → DELETE /tenants/tenant_acme → Denied (admin only)
Alice (tenant_acme, role=admin)  → GET /projects?tenant=tenant_globex → Denied (wrong tenant)
```

**API Gateway native JWT authorizer + business Lambda logic handle this.**

### The Flow in This Project

```
AuthN: Cognito verifies password → issues JWT  (happens at login)
         ↓
AuthZ: API Gateway native JWT authorizer validates token → forwards claims  (happens on every API call)
         ↓
Data scoping: Business Lambda uses tenant_id from JWT claims → DynamoDB query scoped  (happens in business logic)
```

---

## 🔄 Token Lifecycle

```
1. Signup  → Cognito creates user, sends verification email → NO tokens yet
2. Confirm → user clicks verification link / enters code → account active
3. Login   → Cognito returns ID Token (1hr), Access Token (1hr), Refresh Token (30 days)
4. API calls (business routes) → client sends ID Token as Bearer → API Gateway native JWT authorizer validates
5. API calls (Cognito routes)  → client sends Access Token → Cognito validates via GetUser/GlobalSignOut
6. ID/Access Token expires (1hr) → client uses Refresh Token → Cognito returns fresh ID + Access tokens
7. Refresh Token expires (30 days) → no silent renewal → user must log in again
8. Logout → client calls GlobalSignOut with Access Token → all tokens invalidated server-side → client discards locally
```

**Why GlobalSignOut needs the Access Token (not ID Token):**
`GlobalSignOut` is a Cognito management API — it operates on the user's session inside Cognito. Cognito's management APIs only accept the Access Token. The ID Token is for your API to identify the user, not for Cognito to act on the user's session.

---

## 🔗 How It All Fits Together

```
Cognito User Pool
  - Stores users with custom:tenant_id, custom:role
  - Issues signed JWTs on login (ID + Access + Refresh)
  - Publishes public keys at JWKS endpoint
  - Accepts Access Token for management APIs (GetUser, GlobalSignOut)
        │
        ├─── ID Token ──────────────────────────────────────────────────────┐
        │                                                                   ▼
        │                                                    API Gateway HTTP API
        │                                                      Native JWT Authorizer
        │                                                        - Validates token internally
        │                                                        - No Lambda, no library
        │                                                        - Forwards JWT claims to Lambda
        │                                                                   │
        │                                                                   ▼
        │                                                          Business Logic Lambda
        │                                                            - tenant_id from JWT claims context
        │                                                            - DynamoDB query always scoped
        │                                                                   │
        │                                                                   ▼
        │                                                               DynamoDB
        │                                                            - Pool model, PK: tenant_id
        │
        └─── Access Token ──────────────────────────────────────────────────┐
                                                                            ▼
                                                               Auth Lambda (/auth/me, /auth/logout)
                                                                 - No gateway JWT authorizer on these routes
                                                                 - Passes Access Token directly to Cognito
                                                                 - GetUser → returns profile + attributes
                                                                 - GlobalSignOut → invalidates all sessions
```

Each layer has a single responsibility:
- **Cognito** — identity, token issuance, user management APIs
- **API Gateway native JWT authorizer** — ID Token validation and claim forwarding, zero code
- **Business Lambda** — application logic, always tenant-scoped via JWT claims context
- **Auth Lambda** — proxies Cognito management operations using the Access Token
- **DynamoDB** — data persistence with structural tenant isolation
