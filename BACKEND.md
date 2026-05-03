# Bali Travel Health — Backend API spec & starter code

This is the contract the iOS client expects. Implement these PHP endpoints (or any equivalent stack — Node, Python, Go) on `balihealth.me` and you can flip `AppFlags.useDummyData = false` to go live.

---

## 0. TODO checklist

- [ ] Provision MySQL/MariaDB and apply the schema in §1 (now includes the `passkey_credentials` table — §1)
- [ ] Add `require_app_user_agent();` to every endpoint — §2.3
- [ ] Serve `/.well-known/apple-app-site-association` with `webcredentials` — §7.1
- [ ] Add Associated Domains entitlement to Xcode target with `webcredentials:balihealth.me` — §7.2
- [ ] Implement `POST /internal/passkey/begin` and `POST /internal/passkey/finish` — §7.3
- [ ] Verify Apple / Google identity tokens server-side (do **not** trust the client alone) — §2.1
- [ ] Implement `POST /credentials.php` — sign-in / sign-up — §3.1
- [ ] Implement `GET /credentials.php` — session validation — §3.2
- [ ] Implement `POST /profile.php` — onboarding profile + travel info upsert — §3.3
- [ ] Implement `GET /nurses.php` — list nurses — §3.4
- [ ] Implement `POST /appointments.php` — create appointment — §3.5
- [ ] Implement `GET /appointments-active.php` — return current/upcoming appointment or `204` — §3.6
- [ ] HTTPS only (TLS) and HSTS header
- [ ] Rate limiting on `credentials.php` (e.g. fail2ban or per-IP throttle)
- [ ] Backups + log rotation
- [ ] CORS not required (native client) — but reject unknown origins if you ever add a web client
- [ ] Set `AppFlags.useDummyData = false` in the iOS app once everything is green

---

## 1. Database schema (MySQL / MariaDB 10.5+)

```sql
CREATE DATABASE IF NOT EXISTS balihealth
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE balihealth;

-- One row per real human, regardless of provider.
CREATE TABLE users (
    id              CHAR(36)        PRIMARY KEY,           -- UUID v4
    apple_sub       VARCHAR(255)    NULL UNIQUE,           -- Apple `sub` claim
    google_sub      VARCHAR(255)    NULL UNIQUE,           -- Google `sub` claim
    email           VARCHAR(320)    NULL,
    name            VARCHAR(120)    NULL,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Bearer tokens issued after sign-in.
CREATE TABLE sessions (
    token           CHAR(64)        PRIMARY KEY,           -- random hex(32)
    user_id         CHAR(36)        NOT NULL,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at      DATETIME        NOT NULL,
    revoked_at      DATETIME        NULL,
    INDEX (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Onboarding profile (1:1 with users).
CREATE TABLE profiles (
    user_id         CHAR(36)        PRIMARY KEY,
    name            VARCHAR(120)    NOT NULL,
    country_code    CHAR(2)         NOT NULL,              -- ISO-3166 alpha-2
    date_of_birth   DATE            NOT NULL,
    gender          ENUM('male','female') NOT NULL,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Optional travel window (1:1 with users; nullable as a whole).
CREATE TABLE travel_info (
    user_id         CHAR(36)        PRIMARY KEY,
    arrival_date    DATE            NOT NULL,
    departure_date  DATE            NOT NULL,
    season          ENUM('rainy','dry') NULL,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Nurse directory (admin-managed).
CREATE TABLE nurses (
    id              CHAR(36)        PRIMARY KEY,
    name            VARCHAR(120)    NOT NULL,
    experience      VARCHAR(120)    NOT NULL,
    base_rate       DECIMAL(10,2)   NOT NULL,
    currency_code   CHAR(3)         NOT NULL DEFAULT 'IDR',
    avatar_url      VARCHAR(500)    NULL,
    bio             TEXT            NULL,
    whatsapp_number VARCHAR(32)     NOT NULL,              -- E.164, e.g. +6281...
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Bookings.
-- Passkey credentials (one user can register multiple devices).
CREATE TABLE passkey_credentials (
    credential_id   VARBINARY(255)  PRIMARY KEY,           -- raw credentialID bytes
    user_id         CHAR(36)        NOT NULL,
    public_key      VARBINARY(512)  NOT NULL,              -- COSE / DER-encoded
    sign_count      BIGINT UNSIGNED NOT NULL DEFAULT 0,
    transports      VARCHAR(120)    NULL,                  -- e.g. "internal,hybrid"
    aaguid          BINARY(16)      NULL,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at    DATETIME        NULL,
    INDEX (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Short-lived challenges issued by /passkey/begin (one row per session).
-- Use a session cookie or random "ceremony id" to look the row up at /finish.
CREATE TABLE passkey_challenges (
    ceremony_id           CHAR(64)    PRIMARY KEY,         -- random hex(32)
    registration_challenge VARBINARY(64) NOT NULL,
    registration_user_id  VARBINARY(64) NOT NULL,
    login_challenge       VARBINARY(64) NOT NULL,
    expires_at            DATETIME      NOT NULL
) ENGINE=InnoDB;

CREATE TABLE appointments (
    id              CHAR(36)        PRIMARY KEY,
    user_id         CHAR(36)        NOT NULL,
    nurse_id        CHAR(36)        NOT NULL,
    scheduled_at    DATETIME        NOT NULL,              -- UTC
    address         VARCHAR(500)    NOT NULL,
    latitude        DECIMAL(9,6)    NOT NULL,
    longitude       DECIMAL(9,6)    NOT NULL,
    description     VARCHAR(255)    NOT NULL,
    status          ENUM('confirmed','cancelled','completed') NOT NULL DEFAULT 'confirmed',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (user_id, scheduled_at),
    FOREIGN KEY (user_id)  REFERENCES users(id)   ON DELETE CASCADE,
    FOREIGN KEY (nurse_id) REFERENCES nurses(id)
) ENGINE=InnoDB;
```

---

## 2. Shared helpers

### 2.1 Identity token verification

The iOS client posts the **identity token** (a JWT) it received from Apple or Google. Server-side you must verify the signature against the provider's JWKS and extract `sub`/`email`/`name`. **Never** trust the JSON the client sends without verifying the JWT.

For Apple, fetch [`https://appleid.apple.com/auth/keys`](https://appleid.apple.com/auth/keys); for Google, [`https://www.googleapis.com/oauth2/v3/certs`](https://www.googleapis.com/oauth2/v3/certs). Use a maintained library — for PHP, `firebase/php-jwt` (Composer):

```bash
composer require firebase/php-jwt guzzlehttp/guzzle
```

### 2.2 `lib/db.php`

```php
<?php
function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host=localhost;dbname=balihealth;charset=utf8mb4',
            getenv('DB_USER'),
            getenv('DB_PASS'),
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
    }
    return $pdo;
}

function uuid(): string {
    $d = random_bytes(16);
    $d[6] = chr((ord($d[6]) & 0x0f) | 0x40);
    $d[8] = chr((ord($d[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($d), 4));
}

function json_input(): array {
    $raw = file_get_contents('php://input');
    return json_decode($raw, true) ?? [];
}

function json_out(int $code, array $payload): void {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function bearer_token(): ?string {
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    return preg_match('/^Bearer\s+(.+)$/i', $h, $m) ? $m[1] : null;
}
```

### 2.3 `lib/gate.php` — User-Agent gate

The iOS app stamps every request with a custom User-Agent that starts with a
shared key. Reject anything that doesn't carry it. Keep the key in sync with
`AppUserAgent.appKey` in [BaliTravelHealth/Networking/AppUserAgent.swift](BaliTravelHealth/Networking/AppUserAgent.swift).

```php
<?php
// Must match `AppUserAgent.appKey` in the iOS app.
const APP_USER_AGENT_KEY = 'BTH-IOS-7c3e9f';

/**
 * Reject requests that aren't from the official Bali Travel Health iOS app.
 * Call as the first thing in every endpoint.
 */
function require_app_user_agent(): void {
    $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
    // Header value looks like:
    //   "BTH-IOS-7c3e9f BaliTravelHealth/1.0.0 (1; iOS 26.2; iPhone16,2)"
    if (!str_starts_with($ua, APP_USER_AGENT_KEY . ' ')) {
        http_response_code(403);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['error' => 'forbidden']);
        exit;
    }
}
```

Add `require_app_user_agent();` at the top of every `*.php` endpoint (right
after the `require_once` lines). Any request missing the header — `curl`, a
browser, a scraper — will get a flat `403`.

> ⚠️ **This is filtering, not security.** A determined attacker can copy the
> header value once they've sniffed it. Continue to require the bearer
> session token (`require_auth()`) on every protected route.

### 2.4 `lib/auth.php`

```php
<?php
require_once __DIR__ . '/db.php';

/**
 * Validate a bearer token. Returns the user_id or null.
 */
function auth_user_id(): ?string {
    $token = bearer_token();
    if (!$token) return null;
    $stmt = db()->prepare(
        'SELECT user_id FROM sessions
          WHERE token = :t AND revoked_at IS NULL AND expires_at > NOW()'
    );
    $stmt->execute([':t' => $token]);
    $row = $stmt->fetch();
    return $row ? $row['user_id'] : null;
}

function require_auth(): string {
    $uid = auth_user_id();
    if (!$uid) json_out(401, ['error' => 'unauthorized']);
    return $uid;
}

function issue_session(string $userId): string {
    $token = bin2hex(random_bytes(32));
    $stmt = db()->prepare(
        'INSERT INTO sessions (token, user_id, expires_at)
         VALUES (:t, :u, DATE_ADD(NOW(), INTERVAL 90 DAY))'
    );
    $stmt->execute([':t' => $token, ':u' => $userId]);
    return $token;
}

/**
 * Verify an Apple or Google identity token against the provider's JWKS.
 * Returns ['sub' => ..., 'email' => ..., 'name' => ...] or throws.
 */
function verify_identity_token(string $provider, string $jwt): array {
    // TODO: implement with firebase/php-jwt + JWKS.
    // For Apple, audience must match your iOS bundle identifier.
    // For Google, audience must match the iOS OAuth client_id.
    //
    // Pseudocode:
    //   $jwks = file_get_contents($provider === 'apple'
    //       ? 'https://appleid.apple.com/auth/keys'
    //       : 'https://www.googleapis.com/oauth2/v3/certs');
    //   $keys = JWK::parseKeySet(json_decode($jwks, true));
    //   $payload = (array) JWT::decode($jwt, $keys);
    //   if ($provider === 'apple'  && $payload['iss'] !== 'https://appleid.apple.com') throw...
    //   if ($provider === 'google' && $payload['iss'] !== 'https://accounts.google.com') throw...
    //   verify exp, aud, iat...
    //   return ['sub' => $payload['sub'], 'email' => $payload['email'] ?? null, 'name' => $payload['name'] ?? null];
    throw new RuntimeException('verify_identity_token not implemented');
}
```

---

## 3. Endpoints

### 3.1 `POST /credentials.php` — sign-in / sign-up

**Request body**
```json
{
  "action": "signin",                 // or "signup"
  "provider": "apple",                // or "google"
  "providerUserId": "001234.abc...",  // sub claim
  "identityToken": "<JWT>",
  "email": "user@example.com",        // optional
  "name": "Made Suparna"              // optional
}
```

**Successful response (200)**
```json
{
  "sessionToken": "9f86…",
  "refreshToken": null,
  "userID": "f1c4…",
  "name": "Made Suparna",
  "email": "user@example.com",
  "isNewUser": false
}
```

**Error responses the iOS client recognises**
- Sign-in for unknown user → `404` **or** `{"code":"user_not_found"}`
- Sign-up for existing user → `409` **or** `{"code":"user_exists"}`
- Anything else → `4xx`/`5xx` with `{"error": "<plain text>"}`

**`credentials.php`**
```php
<?php
require_once __DIR__ . '/lib/db.php';
require_once __DIR__ . '/lib/auth.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET')  { require __DIR__ . '/credentials_get.php'; exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { json_out(405, ['error' => 'method_not_allowed']); }

$body = json_input();
$action       = $body['action']         ?? '';
$provider     = $body['provider']       ?? '';
$providerSub  = $body['providerUserId'] ?? '';
$idToken      = $body['identityToken']  ?? '';
$email        = $body['email']          ?? null;
$name         = $body['name']           ?? null;

if (!in_array($action,   ['signin','signup'], true)) json_out(400, ['error' => 'bad_action']);
if (!in_array($provider, ['apple','google'],  true)) json_out(400, ['error' => 'bad_provider']);
if (!$providerSub || !$idToken)                       json_out(400, ['error' => 'missing_credentials']);

try {
    $verified = verify_identity_token($provider, $idToken);
    if ($verified['sub'] !== $providerSub) json_out(401, ['error' => 'token_subject_mismatch']);
} catch (Throwable $e) {
    json_out(401, ['error' => 'invalid_identity_token']);
}

$col = $provider === 'apple' ? 'apple_sub' : 'google_sub';
$stmt = db()->prepare("SELECT id, name, email FROM users WHERE $col = :s LIMIT 1");
$stmt->execute([':s' => $providerSub]);
$user = $stmt->fetch();

if ($action === 'signin') {
    if (!$user) json_out(404, ['code' => 'user_not_found']);
} else { // signup
    if ($user) json_out(409, ['code' => 'user_exists']);
    $userId = uuid();
    $insert = db()->prepare(
        "INSERT INTO users (id, $col, email, name) VALUES (:id, :s, :e, :n)"
    );
    $insert->execute([':id' => $userId, ':s' => $providerSub, ':e' => $email, ':n' => $name]);
    $user = ['id' => $userId, 'name' => $name, 'email' => $email];
}

$session = issue_session($user['id']);

json_out(200, [
    'sessionToken' => $session,
    'refreshToken' => null,
    'userID'       => $user['id'],
    'name'         => $user['name'],
    'email'        => $user['email'],
    'isNewUser'    => $action === 'signup',
]);
```

### 3.2 `GET /credentials.php` — session validation

Used by the iOS client at launch to check the bearer token. Return `200` if valid, `401` otherwise. **Anything else** (404, 405, 5xx) is treated as "unknown" by the client and the user stays signed in offline.

**`credentials_get.php`** (included by `credentials.php` above)
```php
<?php
$uid = auth_user_id();
if (!$uid) json_out(401, ['error' => 'unauthorized']);
json_out(200, ['userID' => $uid]);
```

### 3.3 `POST /profile.php` — upsert onboarding profile + travel

**Request body**
```json
{
  "name": "Made Suparna",
  "countryCode": "ID",
  "dateOfBirth": "1990-04-12",
  "gender": "male",
  "arrivalDate": "2026-06-14",
  "departureDate": "2026-06-21",
  "season": "dry"
}
```
Travel fields are optional (skip-onboarding case).

**Response: 204 No Content** on success.

```php
<?php
require_once __DIR__ . '/lib/db.php';
require_once __DIR__ . '/lib/auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') json_out(405, ['error' => 'method_not_allowed']);
$uid = require_auth();
$b   = json_input();

$required = ['name','countryCode','dateOfBirth','gender'];
foreach ($required as $k) if (!isset($b[$k])) json_out(400, ['error' => "missing_$k"]);
if (!in_array($b['gender'], ['male','female'], true)) json_out(400, ['error' => 'bad_gender']);

db()->prepare(
    'INSERT INTO profiles (user_id, name, country_code, date_of_birth, gender)
     VALUES (:u, :n, :c, :d, :g)
     ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        country_code = VALUES(country_code),
        date_of_birth = VALUES(date_of_birth),
        gender = VALUES(gender)'
)->execute([
    ':u' => $uid, ':n' => $b['name'], ':c' => $b['countryCode'],
    ':d' => $b['dateOfBirth'], ':g' => $b['gender']
]);

if (!empty($b['arrivalDate']) && !empty($b['departureDate'])) {
    db()->prepare(
        'INSERT INTO travel_info (user_id, arrival_date, departure_date, season)
         VALUES (:u, :a, :d, :s)
         ON DUPLICATE KEY UPDATE
            arrival_date = VALUES(arrival_date),
            departure_date = VALUES(departure_date),
            season = VALUES(season)'
    )->execute([
        ':u' => $uid, ':a' => $b['arrivalDate'], ':d' => $b['departureDate'],
        ':s' => $b['season'] ?? null
    ]);
} else {
    db()->prepare('DELETE FROM travel_info WHERE user_id = :u')->execute([':u' => $uid]);
}

http_response_code(204);
```

### 3.4 `GET /nurses.php` — list nurses

**Response (200)**
```json
[
  {
    "id": "n_001",
    "name": "Made Suparna",
    "experience": "8 years experience",
    "base_rate": 250000,
    "currency_code": "IDR",
    "avatar_url": "https://cdn.balihealth.me/n_001.jpg",
    "bio": "Specialised in elderly home care."
  }
]
```
The iOS client decodes with `keyDecodingStrategy = .convertFromSnakeCase`, so `snake_case` keys above map to camelCase in Swift automatically.

```php
<?php
require_once __DIR__ . '/lib/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') json_out(405, ['error' => 'method_not_allowed']);

$rows = db()->query(
    'SELECT id, name, experience, base_rate, currency_code, avatar_url, bio
       FROM nurses
      WHERE is_active = 1
      ORDER BY name'
)->fetchAll();

// Cast numeric strings to numbers for clean Swift Decimal decoding.
foreach ($rows as &$r) {
    $r['base_rate'] = (float) $r['base_rate'];
}

json_out(200, $rows);
```

### 3.5 `POST /appointments.php` — book

**Request body** (matches Swift's `AppointmentRequest`)
```json
{
  "nurseId": "n_001",
  "scheduledAt": "2026-06-15T10:30:00Z",
  "address": "Jl. Sunset Road No. 818, Kuta",
  "latitude": -8.7109,
  "longitude": 115.1705,
  "description": "Outpatient follow-up after dengue."
}
```

**Response (200)**
```json
{ "appointmentId": "appt_…" }
```

```php
<?php
require_once __DIR__ . '/lib/db.php';
require_once __DIR__ . '/lib/auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') json_out(405, ['error' => 'method_not_allowed']);
$uid = require_auth();
$b   = json_input();

foreach (['nurseId','scheduledAt','address','latitude','longitude','description'] as $k) {
    if (!isset($b[$k])) json_out(400, ['error' => "missing_$k"]);
}
if (mb_strlen($b['description']) > 255) json_out(400, ['error' => 'description_too_long']);

$id = uuid();
db()->prepare(
    'INSERT INTO appointments
        (id, user_id, nurse_id, scheduled_at, address, latitude, longitude, description)
     VALUES
        (:id, :u, :n, :s, :a, :lat, :lng, :d)'
)->execute([
    ':id' => $id,
    ':u'  => $uid,
    ':n'  => $b['nurseId'],
    ':s'  => gmdate('Y-m-d H:i:s', strtotime($b['scheduledAt'])),
    ':a'  => $b['address'],
    ':lat'=> $b['latitude'],
    ':lng'=> $b['longitude'],
    ':d'  => $b['description'],
]);

json_out(200, ['appointmentId' => $id]);
```

### 3.6 `GET /appointments-active.php` — current/upcoming booking

The card on the Nursing Care screen stays visible until 1 day past `scheduledAt` (handled client-side). On the server, return the most recent confirmed appointment whose `scheduledAt` ≥ now − 1 day, or `204 No Content` if none.

**Response (200)**
```json
{
  "id": "appt_42",
  "nurseId": "n_001",
  "nurseName": "Made Suparna",
  "nurseAvatarUrl": "https://cdn.balihealth.me/n_001.jpg",
  "nurseWhatsapp": "+6281234567890",
  "address": "Jl. Sunset Road No. 818, Kuta",
  "scheduledAt": "2026-06-15T10:30:00Z"
}
```

```php
<?php
require_once __DIR__ . '/lib/db.php';
require_once __DIR__ . '/lib/auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') json_out(405, ['error' => 'method_not_allowed']);
$uid = require_auth();

$stmt = db()->prepare(
    "SELECT a.id, a.nurse_id, a.scheduled_at, a.address,
            n.name AS nurse_name, n.avatar_url AS nurse_avatar_url, n.whatsapp_number
       FROM appointments a
       JOIN nurses n ON n.id = a.nurse_id
      WHERE a.user_id = :u
        AND a.status  = 'confirmed'
        AND a.scheduled_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY)
      ORDER BY a.scheduled_at ASC
      LIMIT 1"
);
$stmt->execute([':u' => $uid]);
$row = $stmt->fetch();

if (!$row) { http_response_code(204); exit; }

json_out(200, [
    'id'             => $row['id'],
    'nurseId'        => $row['nurse_id'],
    'nurseName'      => $row['nurse_name'],
    'nurseAvatarUrl' => $row['nurse_avatar_url'],
    'nurseWhatsapp'  => $row['whatsapp_number'],
    'address'        => $row['address'],
    'scheduledAt'    => gmdate('c', strtotime($row['scheduled_at'])),  // ISO-8601 UTC
]);
```

---

## 4. Apache `.htaccess` (optional)

Map the clean paths the client uses to PHP files, force HTTPS, and block direct access to `lib/`:

```apache
RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

# Block library directory
RewriteRule ^lib/ - [F,L]

Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header always set X-Content-Type-Options "nosniff"
```

---

## 5. Testing without the iOS app

```bash
# Note: pass `-A "BTH-IOS-7c3e9f curl/test"` so the User-Agent gate accepts
# the request. Without it you'll get a flat 403 from the gate in §2.3.

# Sign-up (new account)
curl -X POST https://balihealth.me/credentials.php \
  -A 'BTH-IOS-7c3e9f curl/test' \
  -H 'Content-Type: application/json' \
  -d '{"action":"signup","provider":"apple","providerUserId":"001.test","identityToken":"<jwt>","email":"a@b.com","name":"Test"}'

# Validate session
curl https://balihealth.me/credentials.php \
  -H 'Authorization: Bearer <token>'

# Save profile
curl -X POST https://balihealth.me/profile.php \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test","countryCode":"ID","dateOfBirth":"1990-04-12","gender":"male"}'

# List nurses
curl https://balihealth.me/nurses.php

# Book
curl -X POST https://balihealth.me/appointments.php \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{"nurseId":"n_001","scheduledAt":"2026-06-15T10:30:00Z","address":"Jl. Sunset 1","latitude":-8.71,"longitude":115.17,"description":"hello"}'

# Active appointment
curl https://balihealth.me/appointments-active.php \
  -H 'Authorization: Bearer <token>'
```

---

## 7. Passkey (WebAuthn) endpoints

The iOS app's "Continue With Passkey" button calls these two endpoints. Replaces Sign in with Apple. Both go to `https://balihealth.me/internal/passkey/...`.

### 7.1 `apple-app-site-association`

Serve at `https://balihealth.me/.well-known/apple-app-site-association` with `Content-Type: application/json` (no `.json` extension on the URL):

```json
{
  "applinks": { "apps": [], "details": [] },
  "webcredentials": {
    "apps": ["TEAMID.com.YourCompany.BaliTravelHealth"]
  }
}
```

Replace `TEAMID` with your Apple Developer team ID and the bundle identifier with your real one. Verify with:

```bash
curl -I https://balihealth.me/.well-known/apple-app-site-association
# expect Content-Type: application/json + 200
```

### 7.2 Xcode capability

In Xcode → Target → **Signing & Capabilities** → **+ Capability** → **Associated Domains** → add:

```
webcredentials:balihealth.me
```

Without this entitlement the system will refuse to create or use passkeys for `balihealth.me`.

### 7.3 Endpoints

#### `POST /internal/passkey/begin`

**Request body**: empty `{}`.

**Response (200)**
```json
{
  "rpId": "balihealth.me",
  "registrationChallenge": "<base64url; 32 bytes>",
  "registrationUserId":    "<base64url; 16 bytes>",
  "registrationDisplayName": "Bali Travel Health",
  "loginChallenge":        "<base64url; 32 bytes>"
}
```

Store `registrationChallenge` + `registrationUserId` + `loginChallenge` in `passkey_challenges` keyed by a ceremony id (cookie or hidden field) with a 5-minute expiry. The client doesn't see the ceremony id — server side, key it on the request's session/IP/UA combo, OR return it in the response body and require it back at `/finish`.

#### `POST /internal/passkey/finish`

The client sends one of two payload shapes; switch on `type`.

**Registration payload**
```json
{
  "type": "registration",
  "credentialId": "<base64url>",
  "attestationObject": "<base64url>",       // CBOR
  "clientDataJSON": "<base64url>"
}
```

Server-side verification:
1. Decode `clientDataJSON`. Verify `type == "webauthn.create"`, `challenge == registrationChallenge`, `origin == "https://balihealth.me"`.
2. Decode `attestationObject` (CBOR). Extract `authData`. Verify `rpIdHash == SHA-256("balihealth.me")` and the user-presence flag is set.
3. Extract the COSE-encoded public key + AAGUID + sign-count from `authData`'s attestedCredentialData.
4. Create a row in `users` and `passkey_credentials` (or upsert if the user is signing back in on another device — link by `userId` if you want multi-device).
5. Issue a session via `issue_session($userId)` and return the standard `ServerSession` JSON.

**Assertion payload**
```json
{
  "type": "assertion",
  "credentialId": "<base64url>",
  "authenticatorData": "<base64url>",
  "clientDataJSON":    "<base64url>",
  "signature":         "<base64url>",
  "userHandle":        "<base64url|null>"
}
```

Server-side verification:
1. Look up `passkey_credentials` by `credential_id`. If missing → 401.
2. Decode `clientDataJSON`. Verify `type == "webauthn.get"`, `challenge == loginChallenge`, `origin == "https://balihealth.me"`.
3. Decode `authenticatorData`. Verify `rpIdHash` and user-presence flag.
4. Compute `signedData = authenticatorData || SHA-256(clientDataJSON)`. Verify `signature` against the stored `public_key` (RSA or ECDSA per the COSE alg).
5. Reject if the new sign-count is **less than or equal to** the stored `sign_count` (cloned-authenticator detection). Update the row.
6. Issue a session via `issue_session($userId)` and return `ServerSession`.

**Recommended PHP library**: [`web-auth/webauthn-lib`](https://github.com/web-auth/webauthn-framework) — handles all the CBOR / COSE / signature mechanics so you don't have to write them by hand.

```bash
composer require web-auth/webauthn-lib
```

**401 contract**: any verification failure (challenge mismatch, signature invalid, unknown credential, sign-count regression) MUST return HTTP **401** with `{"error":"<plain message>"}`. The iOS client surfaces this as `AuthenticationError.unauthorized` — the user sees an alert and **cannot proceed past the login screen**. No fallback, no offline persistence, no Setup screen, no Home.

### 7.4 Bare-bones PHP skeleton (without webauthn-lib)

```php
<?php
// internal/passkey/begin.php
require_once __DIR__ . '/../../lib/db.php';
require_once __DIR__ . '/../../lib/gate.php';
require_app_user_agent();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') json_out(405, ['error' => 'method_not_allowed']);

$ceremonyId = bin2hex(random_bytes(32));
$regChallenge = random_bytes(32);
$regUserId    = random_bytes(16);   // opaque, server-generated
$logChallenge = random_bytes(32);

db()->prepare(
    'INSERT INTO passkey_challenges
       (ceremony_id, registration_challenge, registration_user_id, login_challenge, expires_at)
     VALUES (:c, :rc, :ru, :lc, DATE_ADD(NOW(), INTERVAL 5 MINUTE))'
)->execute([
    ':c'  => $ceremonyId,
    ':rc' => $regChallenge,
    ':ru' => $regUserId,
    ':lc' => $logChallenge,
]);

// Bind the ceremony to the caller via a short-lived cookie.
setcookie('passkey_ceremony', $ceremonyId, [
    'expires'  => time() + 300,
    'path'     => '/internal/passkey',
    'httponly' => true,
    'secure'   => true,
    'samesite' => 'Strict',
]);

function b64url(string $bytes): string {
    return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
}

json_out(200, [
    'rpId'                    => 'balihealth.me',
    'registrationChallenge'   => b64url($regChallenge),
    'registrationUserId'      => b64url($regUserId),
    'registrationDisplayName' => 'Bali Travel Health',
    'loginChallenge'          => b64url($logChallenge),
]);
```

`finish.php` is too big to inline here — that's where `web-auth/webauthn-lib` does the heavy lifting. Shape the response as `ServerSession` (`sessionToken`, `userID`, `name`, `email`).

---

## 8. iOS files this contract maps to

| Endpoint | Swift file |
|---|---|
| `POST /credentials.php` (action=signin/signup) | [BaliTravelHealth/Authentication/AuthAPIClient.swift](BaliTravelHealth/Authentication/AuthAPIClient.swift) — `signIn`, `signUp`, `signInOrSignUp` |
| `GET /credentials.php` | [BaliTravelHealth/Authentication/AuthAPIClient.swift](BaliTravelHealth/Authentication/AuthAPIClient.swift) — `validate(sessionToken:)` |
| `POST /profile.php` | [BaliTravelHealth/Authentication/ProfileAPIClient.swift](BaliTravelHealth/Authentication/ProfileAPIClient.swift) — `upload` |
| `GET /nurses.php` | [BaliTravelHealth/Services/NurseService.swift](BaliTravelHealth/Services/NurseService.swift) — `fetchAll` |
| `POST /appointments.php` | [BaliTravelHealth/Services/AppointmentAPIClient.swift](BaliTravelHealth/Services/AppointmentAPIClient.swift) — `submit` |
| `GET /appointments-active.php` | [BaliTravelHealth/Services/AppointmentAPIClient.swift](BaliTravelHealth/Services/AppointmentAPIClient.swift) — `fetchActive` |
| `User-Agent` gate key | [BaliTravelHealth/Networking/AppUserAgent.swift](BaliTravelHealth/Networking/AppUserAgent.swift) — `AppUserAgent.appKey` |
| `POST /internal/passkey/begin`, `/finish` | [BaliTravelHealth/Authentication/PasskeyAPIClient.swift](BaliTravelHealth/Authentication/PasskeyAPIClient.swift), [BaliTravelHealth/Authentication/PasskeyManager.swift](BaliTravelHealth/Authentication/PasskeyManager.swift) |

The exact endpoint URLs are configured at the top of each Swift file — change them in one place if you don't want them all on `balihealth.me`.

---

_Generated 2026-05-05. Update as the API evolves._
