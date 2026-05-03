<?php
declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/http.php';

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;

const GOOGLE_JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const GOOGLE_ISSUERS  = ['https://accounts.google.com', 'accounts.google.com'];
const GOOGLE_JWKS_TTL = 3600;

function google_jwks(): array {
    $cfg   = require __DIR__ . '/env.php';
    $cache = $cfg['cache_dir'] . '/google_jwks.json';

    if (is_file($cache) && (time() - filemtime($cache)) < GOOGLE_JWKS_TTL) {
        $cached = json_decode((string) file_get_contents($cache), true);
        if (is_array($cached) && !empty($cached['keys'])) return $cached;
    }

    $ctx  = stream_context_create(['http' => ['timeout' => 5, 'header' => "Accept: application/json\r\n"]]);
    $body = @file_get_contents(GOOGLE_JWKS_URL, false, $ctx);

    if ($body === false) {
        if (is_file($cache)) {
            return json_decode((string) file_get_contents($cache), true);
        }
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
function verify_google_token(string $jwt): array {
    $cfg  = require __DIR__ . '/env.php';
    $keys = JWK::parseKeySet(google_jwks());

    try {
        $payload = (array) JWT::decode($jwt, $keys);
    } catch (Throwable $e) {
        throw new RuntimeException('invalid_jwt');
    }

    if (!in_array($payload['iss'] ?? '', GOOGLE_ISSUERS, true)) {
        throw new RuntimeException('bad_issuer');
    }

    $aud = $payload['aud'] ?? '';
    $audMatches = is_array($aud)
        ? in_array($cfg['google_ios_client_id'], $aud, true)
        : $aud === $cfg['google_ios_client_id'];
    if (!$audMatches) {
        throw new RuntimeException('bad_audience');
    }

    if (empty($payload['sub'])) {
        throw new RuntimeException('missing_sub');
    }

    return [
        'sub'            => (string) $payload['sub'],
        'email'          => isset($payload['email']) ? (string) $payload['email'] : null,
        'name'           => isset($payload['name'])  ? (string) $payload['name']  : null,
        'email_verified' => (bool) ($payload['email_verified'] ?? false),
    ];
}
