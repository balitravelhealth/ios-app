<?php
/**
 * Single source of truth for configuration. Read from environment variables
 * with sensible defaults so a misconfigured server fails closed.
 */

declare(strict_types=1);

// Guard so this file can be `require`'d (not require_once) safely from
// multiple callers — they need the returned array but the function only
// needs to be defined once.
if (!function_exists('env_str')) {
    function env_str(string $key, ?string $default = null): string {
        $v = getenv($key);
        if ($v === false || $v === '') {
            if ($default === null) {
                throw new RuntimeException("Missing required environment variable: $key");
            }
            return $default;
        }
        return $v;
    }
}

return [
    // ── Database ────────────────────────────────────────────────────────
    'db_host' => env_str('DB_HOST', 'localhost'),
    'db_name' => env_str('DB_NAME', 'balihealth'),
    'db_user' => env_str('DB_USER', 'bth_app'),
    'db_pass' => env_str('DB_PASS', ''),

    // ── User-Agent gate (keep in sync with iOS AppUserAgent.appKey) ─────
    'app_user_agent_key' => env_str('APP_USER_AGENT_KEY', 'BTH-IOS-7c3e9f'),

    // ── Identity providers ──────────────────────────────────────────────
    'google_ios_client_id' => env_str(
        'GOOGLE_IOS_CLIENT_ID',
        '779721266536-ean24hl5pgla3k3t98dodo66eacpl84r.apps.googleusercontent.com'
    ),
    'apple_bundle_id' => env_str('APPLE_BUNDLE_ID', 'com.YourCompany.BaliTravelHealth'),

    // ── Passkey / WebAuthn ──────────────────────────────────────────────
    'rp_id'   => env_str('RP_ID', 'balihealth.me'),
    'rp_name' => env_str('RP_NAME', 'Bali Travel Health'),
    'origin'  => 'https://' . env_str('RP_ID', 'balihealth.me'),

    // ── Sessions ────────────────────────────────────────────────────────
    'session_ttl_days' => (int) env_str('SESSION_TTL_DAYS', '90'),

    // ── Cache directory (JWKS + ceremonies) ─────────────────────────────
    'cache_dir' => __DIR__ . '/../cache',
];
