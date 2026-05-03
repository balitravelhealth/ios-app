<?php
declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/http.php';
require_once __DIR__ . '/google_verify.php';   // verify_identity_token() dispatches to it

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;

const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';
const APPLE_ISSUER   = 'https://appleid.apple.com';
const APPLE_JWKS_TTL = 86400;            // 24h — Apple rotates ~weekly

function apple_jwks(): array {
    $cfg   = require __DIR__ . '/env.php';
    $cache = $cfg['cache_dir'] . '/apple_jwks.json';

    if (is_file($cache) && (time() - filemtime($cache)) < APPLE_JWKS_TTL) {
        $cached = json_decode((string) file_get_contents($cache), true);
        if (is_array($cached) && !empty($cached['keys'])) return $cached;
    }

    $ctx  = stream_context_create(['http' => ['timeout' => 5, 'header' => "Accept: application/json\r\n"]]);
    $body = @file_get_contents(APPLE_JWKS_URL, false, $ctx);

    if ($body === false) {
        if (is_file($cache)) return json_decode((string) file_get_contents($cache), true);
        throw new RuntimeException('jwks_fetch_failed');
    }

    $dir = dirname($cache);
    if (!is_dir($dir)) @mkdir($dir, 0770, true);
    file_put_contents($cache, $body);
    return json_decode($body, true);
}

/**
 * @return array{sub:string, email:?string, name:?string, email_verified:bool}
 */
function verify_apple_token(string $jwt): array {
    $cfg  = require __DIR__ . '/env.php';
    $keys = JWK::parseKeySet(apple_jwks());

    try {
        $payload = (array) JWT::decode($jwt, $keys);
    } catch (Throwable $e) {
        throw new RuntimeException('invalid_jwt');
    }

    if (($payload['iss'] ?? '') !== APPLE_ISSUER) {
        throw new RuntimeException('bad_issuer');
    }
    if (($payload['aud'] ?? '') !== $cfg['apple_bundle_id']) {
        throw new RuntimeException('bad_audience');
    }
    if (empty($payload['sub'])) {
        throw new RuntimeException('missing_sub');
    }

    return [
        'sub'            => (string) $payload['sub'],
        'email'          => isset($payload['email']) ? (string) $payload['email'] : null,
        'name'           => null,                 // Apple only returns a name on first sign-in
        'email_verified' => (bool) ($payload['email_verified'] ?? false),
    ];
}

/** Unified verifier dispatched by `credentials.php` */
function verify_identity_token(string $provider, string $jwt): array {
    return match ($provider) {
        'google' => verify_google_token($jwt),
        'apple'  => verify_apple_token($jwt),
        default  => throw new RuntimeException('unknown_provider'),
    };
}
