# Bali Travel Health — Backend (production-ready starter)

Drop-in PHP backend for `https://balihealth.me/internal/`. Pairs 1:1 with the iOS client. Tested against PHP 8.2+ on Apache or Nginx with HTTPS.

## File map

```
backend/
├── README.md                         (this file)
├── composer.json                     `composer install` to fetch deps
├── schema.sql                        full DB DDL — apply once
├── .htaccess                         HTTPS + block /lib + security headers
├── .well-known/
│   └── apple-app-site-association    served at /.well-known/...
├── lib/                              shared helpers (NOT directly accessible)
│   ├── env.php
│   ├── db.php
│   ├── http.php
│   ├── google_verify.php
│   ├── apple_verify.php
│   ├── passkey_repo.php
│   └── passkey_service.php
└── internal/                         the API endpoints
    ├── credentials.php
    ├── profile.php
    ├── nurses.php
    ├── appointments.php
    ├── appointments-active.php
    └── passkey/
        ├── begin.php
        └── finish.php
```

## Deploy in 8 steps

1. **Upload** the whole `backend/` folder so its contents land at the document
   root of `balihealth.me`. (i.e. `composer.json`, `.htaccess`, `internal/`,
   `lib/`, `.well-known/` all sit at the webroot.)

2. **Install dependencies**:
   ```bash
   cd /var/www/balihealth.me
   composer install --no-dev --optimize-autoloader
   ```

3. **Provision the database**:
   ```bash
   mysql -u root -p < schema.sql
   ```

4. **Set environment variables** — easiest is to edit `lib/env.php` directly
   and replace the defaults, OR set them in your Apache vhost / PHP-FPM pool:
   ```ini
   SetEnv DB_HOST localhost
   SetEnv DB_NAME balihealth
   SetEnv DB_USER bth_app
   SetEnv DB_PASS "<strong-password>"
   SetEnv APP_USER_AGENT_KEY "BTH-IOS-7c3e9f"
   SetEnv GOOGLE_IOS_CLIENT_ID "779721266536-ean24hl5pgla3k3t98dodo66eacpl84r.apps.googleusercontent.com"
   SetEnv APPLE_BUNDLE_ID "com.YourCompany.BaliTravelHealth"
   SetEnv RP_ID "balihealth.me"
   ```

5. **Make the cache directory writable** (used by JWKS + passkey ceremonies):
   ```bash
   mkdir -p cache
   chown www-data:www-data cache
   chmod 770 cache
   ```

6. **AASA file** — replace `TEAMID` and bundle id in
   `.well-known/apple-app-site-association` with your real values. Verify:
   ```bash
   curl -i https://balihealth.me/.well-known/apple-app-site-association
   ```
   Must return `200` with `Content-Type: application/json` (Apple checks).

7. **Sanity-check from the command line**:
   ```bash
   # Should be 403 (no User-Agent gate) — proves the gate works.
   curl -i https://balihealth.me/internal/nurses.php
   #
   # Should be 200 with [] (the only public route).
   curl -i -A "BTH-IOS-7c3e9f curl/test" https://balihealth.me/internal/nurses.php
   #
   # Should be 401 (no bearer token).
   curl -i -A "BTH-IOS-7c3e9f curl/test" https://balihealth.me/internal/appointments-active.php
   ```

8. **Flip the iOS feature flag** to `useDummyData = false` once curl tests pass.

## Security notes

- `lib/` is blocked at the web layer in `.htaccess`. Direct GET to
  `/lib/db.php` returns 403.
- All endpoints behind `internal/` require the **User-Agent gate** plus a
  **bearer session token**. Public endpoints (only `nurses.php`) require the
  gate but not auth.
- All payloads are validated with `json_decode(..., flags: JSON_THROW_ON_ERROR)`.
- All SQL goes through prepared statements.
- Errors are logged via `error_log()` with the request id; the response body
  never leaks stack traces.
- Identity tokens (Apple/Google) are verified against the live JWKS — the
  client cannot forge a sign-in.
- Passkeys use `web-auth/webauthn-lib` for full WebAuthn-spec verification.

## Composer dependencies

```json
{
  "require": {
    "php": "^8.2",
    "ext-pdo_mysql": "*",
    "ext-openssl": "*",
    "ext-mbstring": "*",
    "firebase/php-jwt": "^6.10",
    "web-auth/webauthn-lib": "^5.0"
  }
}
```

## Logging

Every endpoint emits one structured log line via `error_log()`:

```
[BTH] uid=<user> route=<path> status=<code> ms=<elapsed>
```

To see it tail your PHP error log:

```bash
tail -f /var/log/php_errors.log | grep BTH
```

## Updating

When the iOS schema changes, the iOS file under each endpoint header in
[../BACKEND.md](../BACKEND.md) names the source of truth. Update the `Codable`
shape on the iOS side first, then mirror it here.
