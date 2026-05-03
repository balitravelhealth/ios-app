<?php
/**
 * HTTP plumbing: request parsing, response writing, User-Agent gate, auth.
 * Every endpoint should `require` this file as its first include.
 */

declare(strict_types=1);

require_once __DIR__ . '/db.php';

$GLOBALS['__bth_request_started'] = microtime(true);

// Always return JSON, even on uncaught exceptions / fatal errors. Without
// this, a stray PDOException becomes a 500 HTML page that the iOS client
// can't parse. With it, ops sees a clean JSON error and the underlying
// message goes to the PHP error log.
ini_set('display_errors', '0');
ini_set('log_errors', '1');

set_exception_handler(function (Throwable $e): void {
    error_log('[BTH] uncaught ' . $e::class . ': ' . $e->getMessage()
        . ' @ ' . basename($e->getFile()) . ':' . $e->getLine());
    if (!headers_sent()) {
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode(['error' => 'server_error']);
    }
});

set_error_handler(function (int $severity, string $message, string $file, int $line): bool {
    // Honour `@`-suppressed calls: when the @ operator is in effect,
    // error_reporting() is 0 for the duration. Skip these silently.
    if ((error_reporting() & $severity) === 0) return true;

    // Only escalate hard errors. Notices, warnings, and deprecations are
    // logged but never turn into fatal 500s — that bites way too often
    // (e.g. a stray deprecation notice from a vendor library would otherwise
    // 500 the whole API).
    if (in_array($severity, [E_ERROR, E_USER_ERROR, E_RECOVERABLE_ERROR], true)) {
        throw new ErrorException($message, 0, $severity, $file, $line);
    }
    $kind = match (true) {
        ($severity & (E_WARNING | E_USER_WARNING))         !== 0 => 'warning',
        ($severity & (E_NOTICE  | E_USER_NOTICE))          !== 0 => 'notice',
        ($severity & (E_DEPRECATED | E_USER_DEPRECATED))   !== 0 => 'deprecated',
        default => "level=$severity",
    };
    error_log("[BTH] $kind: $message @ " . basename($file) . ":$line");
    return true;
});

register_shutdown_function(function (): void {
    $err = error_get_last();
    if ($err && in_array($err['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        error_log('[BTH] fatal ' . $err['message'] . ' @ ' . basename($err['file']) . ':' . $err['line']);
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: application/json; charset=utf-8');
            echo json_encode(['error' => 'server_error']);
        }
    }
});

// ─── Response helpers ─────────────────────────────────────────────────────

function json_out(int $code, array $payload): never {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    bth_log_request($code);
    exit;
}

function no_content(): never {
    http_response_code(204);
    header('Cache-Control: no-store');
    bth_log_request(204);
    exit;
}

function bth_log_request(int $status): void {
    $elapsed = (int) ((microtime(true) - ($GLOBALS['__bth_request_started'] ?? microtime(true))) * 1000);
    $uid = $GLOBALS['__bth_user_id'] ?? '-';
    $route = $_SERVER['REQUEST_URI'] ?? '?';
    error_log("[BTH] uid=$uid route=$route status=$status ms=$elapsed");
}

// ─── Request helpers ──────────────────────────────────────────────────────

function json_input(): array {
    $raw = file_get_contents('php://input') ?: '';
    if ($raw === '') return [];
    try {
        $decoded = json_decode($raw, true, 32, JSON_THROW_ON_ERROR);
    } catch (JsonException $e) {
        json_out(400, ['error' => 'invalid_json']);
    }
    return is_array($decoded) ? $decoded : [];
}

function bearer_token(): ?string {
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    return preg_match('/^Bearer\s+([A-Za-z0-9_\-\.]+)$/i', $h, $m) ? $m[1] : null;
}

function require_method(string $method): void {
    if ($_SERVER['REQUEST_METHOD'] !== $method) {
        header("Allow: $method");
        json_out(405, ['error' => 'method_not_allowed']);
    }
}

// ─── User-Agent gate ──────────────────────────────────────────────────────
//
// Keeps casual scrapers and curl probes out. The iOS client stamps every
// request with a User-Agent that starts with the shared key.

function require_app_user_agent(): void {
    $cfg = require __DIR__ . '/env.php';
    $key = $cfg['app_user_agent_key'];
    $ua  = $_SERVER['HTTP_USER_AGENT'] ?? '';
    if (!str_starts_with($ua, $key . ' ')) {
        json_out(403, ['error' => 'forbidden']);
    }
}

// ─── Auth ────────────────────────────────────────────────────────────────

/** Returns the user id for a valid bearer token, or null. */
function auth_user_id(): ?string {
    $token = bearer_token();
    if (!$token) return null;

    $stmt = db()->prepare(
        'SELECT user_id FROM sessions
          WHERE token = :t AND revoked_at IS NULL AND expires_at > NOW()'
    );
    $stmt->execute([':t' => $token]);
    $row = $stmt->fetch();
    if (!$row) return null;

    $GLOBALS['__bth_user_id'] = $row['user_id'];
    return $row['user_id'];
}

/** Aborts with 401 if the request isn't authenticated. */
function require_auth(): string {
    $uid = auth_user_id();
    if (!$uid) json_out(401, ['error' => 'unauthorized']);
    return $uid;
}

/** Issue a fresh session token for a user. */
function issue_session(string $userId): string {
    $cfg   = require __DIR__ . '/env.php';
    $token = bin2hex(random_bytes(32));
    $stmt  = db()->prepare(
        'INSERT INTO sessions (token, user_id, expires_at)
         VALUES (:t, :u, DATE_ADD(NOW(), INTERVAL :d DAY))'
    );
    $stmt->execute([
        ':t' => $token,
        ':u' => $userId,
        ':d' => $cfg['session_ttl_days'],
    ]);
    return $token;
}

// ─── base64url helpers ────────────────────────────────────────────────────

function b64url(string $bytes): string {
    return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
}

function b64url_decode(string $s): string {
    $padded = strtr($s, '-_', '+/');
    $padded .= str_repeat('=', (4 - strlen($padded) % 4) % 4);
    $decoded = base64_decode($padded, true);
    if ($decoded === false) throw new RuntimeException('bad_base64url');
    return $decoded;
}
