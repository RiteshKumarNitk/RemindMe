# Authentication

Custom implementation (decision on record): **argon2id password hashing + JWT
access/refresh tokens + DB-backed sessions**. No third-party auth framework.
Serves both the web app (cookie sessions) and the Flutter app (bearer tokens)
from one user store.

> **Design phase only. No authentication code is written in Phase 0.** This
> document is the normative spec Phase 1 must satisfy.

## Requirements (normative — every item is a MUST)

| # | Requirement | Where detailed |
|---|---|---|
| R1 | Passwords are hashed with **argon2id** (memory/time/parallelism from env, OWASP-baseline). Plaintext passwords are never stored, logged, queued, or placed in an audit row. Hashes are never returned to a client. | [Password hashing](#password-hashing) |
| R2 | **Short-lived access tokens.** API access is a signed JWT with `exp` ≤ 15 min (`JWT_ACCESS_TTL`, default 900 s). Stateless; verified on every request; carries a `tv` (token-version) claim for global invalidation. | [API tokens](#api-tokens-flutter-and-other-clients) |
| R3 | **Refresh token rotation.** Every `POST /api/auth/refresh` revokes the presented refresh token and issues a new one in the same `familyId` lineage. Refresh tokens are opaque, random, and stored only as `sha256` (`RefreshToken.hashedToken`). | same |
| R4 | **Refresh token reuse detection.** Presenting an already-revoked refresh token revokes the entire `familyId` (theft assumed) and forces re-login. Error code `REFRESH_REUSE_DETECTED`. | same |
| R5 | **Refresh token revocation.** Individual tokens (`revokedAt`) and whole families are revocable server-side; a `SUSPENDED` membership or disabled user invalidates on next use. | same |
| R6 | **Logout.** `POST /api/auth/logout` revokes the current session/refresh token. `POST /api/auth/logout-all` revokes every session + refresh family for the user and bumps `tv` (invalidating outstanding access tokens). | [Endpoints](#endpoints) |
| R7 | **Session expiry.** Web sessions have an absolute `expiresAt`; expired rows are rejected and swept. Access tokens expire by `exp`; refresh tokens by `expiresAt` (`JWT_REFRESH_TTL`, default 30 d). Password reset revokes all sessions. | [Web sessions](#web-sessions-cookie) |
| R8 | **Google OAuth.** Authorization-code + PKCE flow using `GOOGLE_CLIENT_ID/SECRET/REDIRECT_URL`. ID token verified server-side. Optional — email/password works with Google disabled. | [Google OAuth](#google-oauth) |
| R9 | **Google account linking.** A verified Google `sub` maps 1:1 to a `User` via `IdentityAccount`. If the Google email matches an existing verified `User`, a new `IdentityAccount` is linked (never a silent account merge across unverified emails). This is also the DoseWise Google-user migration path. | [Google OAuth](#google-oauth), [DoseWise migration path](#dosewise-migration-path-spec-4-20) |
| R10 | **Flutter authentication compatibility.** The app authenticates with `Authorization: Bearer <accessToken>`; refresh token kept in platform secure storage (Keychain/Keystore); access token in memory. No cookies, no CSRF surface. CORS does not apply to the native app. Works offline for everything that does not touch the platform API (DoseWise core is unaffected). | [Client compatibility](#client-compatibility) |
| R11 | **Web authentication compatibility.** The web app uses an `HttpOnly` `Secure` `SameSite=Lax` session cookie (hashed at rest, sliding renewal, server-side revocation) plus double-submit CSRF protection on state-changing cookie-auth requests. | [Web sessions](#web-sessions-cookie), [Client compatibility](#client-compatibility) |

## Identity model

- `User` — one global identity. `email` unique (stored lower-cased),
  `passwordHash` nullable (null ⇒ OAuth-only account).
- `IdentityAccount` — links a `User` to an external provider
  (`provider="google"`, `providerAccountId` = Google `sub`).
- `Membership` — where roles and tenant access live. Authentication proves
  *who*; membership resolution decides *where* and *what*.

## Password hashing

- **argon2id** via the `argon2` npm package.
- Parameters from env (`ARGON2_MEMORY_KIB=19456`, `ARGON2_TIME_COST=2`,
  `ARGON2_PARALLELISM=1`) — OWASP-baseline, re-tune with a benchmark.
- On successful login with an outdated parameter set, transparently re-hash.
- Never log or return a hash. Never store a plaintext password, not even
  transiently in a queue or audit row (spec §4, §22).
- Fallback: if the `argon2` native build is problematic on the host, `bcrypt`
  cost 12 is the sanctioned alternative — a `passwordHash` carries its own
  algorithm prefix so both can coexist during a transition.

## Web sessions (cookie)

- On login: create a random 32-byte session token; store `sha256(token)` as
  `Session.hashedSessionToken` with `expiresAt`, `ip`, `userAgent`.
- Set cookie `dw_session=<token>`: `HttpOnly`, `Secure`, `SameSite=Lax`,
  `Path=/`, `Max-Age` = session TTL.
- Each request: hash the cookie, look up the row, check `expiresAt`. Sliding
  renewal on activity past the halfway mark.
- Logout deletes the row. "Logout everywhere" deletes all rows for the user.

## API tokens (Flutter and other clients)

- **Access token** — JWT signed with `JWT_ACCESS_SECRET`, `exp` =
  `JWT_ACCESS_TTL` (900 s). Claims: `sub` (userId), `iss`, `iat`, `exp`,
  `tv` (token version for global invalidation). Stateless; verified on every
  request.
- **Refresh token** — opaque random string; `sha256` stored as
  `RefreshToken.hashedToken` with `familyId`, `expiresAt`, `revokedAt`,
  `replacedById`.
  - `POST /api/auth/refresh` rotates: the presented token is revoked and a new
    one issued in the same `familyId`.
  - **Reuse detection**: presenting an already-revoked token revokes the whole
    `familyId` (assume theft) and forces re-login.
- Clients store the refresh token in secure storage (Keychain / Keystore).
  The access token stays in memory.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/auth/register` | email + password + name → creates `User` (unverified) |
| `POST` | `/api/auth/login` | email + password → session cookie **or** `{ accessToken, refreshToken }` (by `X-Client: web\|app`) |
| `POST` | `/api/auth/refresh` | rotate refresh → new token pair |
| `POST` | `/api/auth/logout` | revoke current session / refresh token |
| `POST` | `/api/auth/logout-all` | revoke every session + bump `tv` |
| `GET`  | `/api/auth/google/start` | begin OAuth (PKCE) |
| `GET`  | `/api/auth/google/callback` | exchange code, link/create `User`, issue session/tokens |
| `POST` | `/api/auth/forgot-password` | email a single-use, expiring reset token (hashed at rest) |
| `POST` | `/api/auth/reset-password` | consume reset token, set new hash, revoke all sessions |
| `POST` | `/api/auth/verify-email` | consume verification token |
| `GET`  | `/api/me` | current user + memberships (role per org) |

All auth routes are rate-limited at `RATE_LIMIT_AUTH_PER_MIN`. Failures are
generic ("invalid email or password") — no account enumeration.

## Google OAuth

- Authorization-code + PKCE. `GOOGLE_CLIENT_ID/SECRET/REDIRECT_URL` from env.
- On callback: verify the ID token, take `sub` + `email` + `name`.
  - `IdentityAccount(provider=google, providerAccountId=sub)` exists → log in
    that user.
  - else email matches an existing `User` → link a new `IdentityAccount`
    (only when that email is verified on both sides).
  - else create a `User` (`passwordHash = null`, `emailVerifiedAt = now`) and
    an `IdentityAccount`.

## Client compatibility

### Flutter (native app) — R10

- **Transport:** `Authorization: Bearer <accessToken>` on every API call.
- **Token storage:** refresh token in platform secure storage
  (iOS Keychain / Android Keystore via a secure-storage plugin); access token
  in memory only, re-minted via `/api/auth/refresh` on `401 TOKEN_EXPIRED`.
- **No cookies / no CSRF** surface for the app; CORS is irrelevant to a native
  client.
- **Offline:** the DoseWise core (reminders, local DB, notifications, TTS,
  widget) does **not** depend on authentication or the platform API. Signing in
  unlocks platform features (appointments, clinic-visible medication sync); it
  never gates local functionality.
- **Login response:** send `X-Client: app` → `POST /api/auth/login` returns
  `{ accessToken, refreshToken }` (no `Set-Cookie`).

### Web app — R11

- **Transport:** `HttpOnly` `Secure` `SameSite=Lax` session cookie
  (`dw_session`), value hashed at rest, sliding renewal, server-side
  revocation.
- **CSRF:** double-submit token (`dw_csrf` cookie + `X-CSRF-Token` header) on
  every state-changing cookie-auth request; `GET` never mutates.
- **Login response:** `X-Client: web` (or default) → `Set-Cookie` + a minimal
  JSON body, no tokens in the body.
- Same `User` store, same `/api/auth/*` endpoints, same RBAC — only the
  credential carrier differs.

## DoseWise migration path (spec §4, §20)

DoseWise today uses two Firebase identities: interactive **Google Sign-In**
(`AuthService`) and **anonymous** auth for sync (`FirebaseBackend`).

| Phase | Auth behaviour |
|---|---|
| 0 | none — backend only |
| 1 | Flutter adds "Sign in" against `/api/auth/*`. Existing Firebase login still works in parallel. |
| 2 | On first platform Google sign-in, the Firebase Google account maps 1:1 to a platform `User` via the same `sub`. A migration key on the client carries the anonymous household id so sync data can be re-homed to the new `Patient`/`Medication` rows. |
| 3 | Firebase Auth retired. Anonymous-only users are prompted once to sign in (Google or email) to keep cloud sync; local data is never lost regardless. |

## Guest / demo access

The platform has a **guest mode strictly for demo and preview** — see the
dedicated design in [GUEST_ACCESS.md](GUEST_ACCESS.md). Summary of the hard
limits:

- A guest session is bound to a single, permanently-seeded **demo
  organization** containing only synthetic data.
- A guest **cannot** read or write any real tenant's data, another user's
  data, or any real clinical record.
- A guest **cannot** bypass tenant resolution or RBAC — it is a normal
  authenticated principal whose membership happens to be `PATIENT`/read-mostly
  in the demo org, with writes sandboxed and auto-expired.
- Guest sessions are short-lived, rate-limited, and never issued a long-lived
  refresh token.

The **existing DoseWise "guest" (offline, no account)** is a different thing —
documented in
[DOSEWISE_EXISTING_FUNCTIONALITY.md](DOSEWISE_EXISTING_FUNCTIONALITY.md) §3 and
[GUEST_ACCESS.md](GUEST_ACCESS.md) — and its mapping to platform auth is an
explicit later decision, not assumed here.

## What is intentionally out of scope for MVP

MFA/TOTP, WebAuthn/passkeys, SSO/SAML, magic links, device management UI.
Hooks are left where they'd attach (`tv` claim, `Session`/`RefreshToken`
metadata) so adding them later is not a rewrite.
