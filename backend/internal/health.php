<?php
/**
 * GET /internal/health.php — diagnostic endpoint.
 *
 * Returns a JSON report of every preflight check. Use this to debug 500s
 * before flipping the iOS feature flag. Delete the file (or block via
 * .htaccess) once everything reports `"ok": true`.
 */

declare(strict_types=1);

// Capture EVERYTHING so we always return JSON, even on fatal include errors.
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

set_exception_handler(function (Throwable $e): void {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'ok' => false,
        'fatal' => $e::class . ': ' . $e->getMessage(),
        'file'  => basename($e->getFile()) . ':' . $e->getLine(),
    ]);
    exit;
});

$report = ['ok' => true, 'checks' => []];
$mark = function (string $key, string $msg, bool $ok = true) use (&$report): void {
    $report['checks'][$key] = $msg;
    if (!$ok) $report['ok'] = false;
};

// 1. PHP version
$mark('php_version', PHP_VERSION, version_compare(PHP_VERSION, '8.2.0', '>='));

// 2. Required extensions
foreach (['pdo_mysql', 'openssl', 'mbstring', 'curl', 'json'] as $ext) {
    $mark("ext_$ext", extension_loaded($ext) ? 'loaded' : 'MISSING',
          extension_loaded($ext));
}

// 3. Composer autoloader
$autoload = __DIR__ . '/../vendor/autoload.php';
if (is_file($autoload)) {
    require_once $autoload;
    $mark('composer', 'vendor/autoload.php OK');
} else {
    $mark('composer', 'MISSING — run `composer install --no-dev`', false);
}

// 4. env.php loads
try {
    $cfg = require __DIR__ . '/../lib/env.php';
    $mark('env', 'loaded (DB ' . $cfg['db_host'] . '/' . $cfg['db_name'] . ')');
} catch (Throwable $e) {
    $mark('env', 'FAIL: ' . $e->getMessage(), false);
    echo json_encode($report);
    exit;
}

// 5. http.php loads (so json_out etc. work)
try {
    require_once __DIR__ . '/../lib/http.php';
    $mark('http_lib', 'loaded');
} catch (Throwable $e) {
    $mark('http_lib', 'FAIL: ' . $e->getMessage(), false);
    echo json_encode($report);
    exit;
}

// http.php installed its own terse exception handler ({"error":"server_error"})
// — clobber it with a verbose one so health output keeps showing the real
// failure for every later check.
set_exception_handler(function (Throwable $e) use (&$report): void {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    $report['ok'] = false;
    $report['fatal'] = [
        'class'   => $e::class,
        'message' => $e->getMessage(),
        'file'    => basename($e->getFile()) . ':' . $e->getLine(),
        'trace'   => array_slice(array_map(
            fn($f) => basename($f['file'] ?? '?') . ':' . ($f['line'] ?? '?')
                     . ' ' . ($f['class'] ?? '') . ($f['type'] ?? '') . ($f['function'] ?? '?'),
            $e->getTrace()
        ), 0, 8),
    ];
    echo json_encode($report, JSON_UNESCAPED_SLASHES);
});

// 6. User-Agent gate (must be present on this endpoint too)
require_app_user_agent();
$mark('user_agent_gate', 'passed (' . substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 40) . '…)');

// 7. DB reachable
try {
    $row = db()->query('SELECT VERSION() v')->fetch();
    $mark('db_connect', 'OK (MySQL ' . $row['v'] . ')');
} catch (Throwable $e) {
    $mark('db_connect', 'FAIL: ' . $e->getMessage(), false);
    json_out(500, $report);
}

// 8. Schema applied
foreach (['users', 'sessions', 'profiles', 'travel_info', 'nurses',
          'appointments', 'passkey_credentials', 'passkey_ceremonies'] as $t) {
    try {
        $c = (int) db()->query("SELECT COUNT(*) c FROM `$t`")->fetch()['c'];
        $mark("table_$t", "OK ($c rows)");
    } catch (Throwable $e) {
        $mark("table_$t", 'MISSING — apply schema.sql', false);
    }
}

// 9. Cache directory writable
$cacheDir = __DIR__ . '/../cache';
if (!is_dir($cacheDir)) @mkdir($cacheDir, 0770, true);
$mark('cache_dir', is_writable($cacheDir) ? 'writable' : 'NOT WRITABLE — chmod 770 cache',
      is_writable($cacheDir));

// 10. Time skew (JWT verification fails if server clock drifts > a few minutes)
$skew = abs(time() - (int) gmdate('U'));
$mark('clock_utc', date('c') . ' (skew ' . $skew . 's)', $skew < 60);

json_out($report['ok'] ? 200 : 500, $report);
