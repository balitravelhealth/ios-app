<?php
/**
 * POST /internal/passkey/begin
 * Returns the unified registration + login challenge bundle the iOS client
 * passes to ASAuthorizationController.
 */

declare(strict_types=1);

require_once __DIR__ . '/../../lib/http.php';
require_once __DIR__ . '/../../lib/passkey_service.php';

require_app_user_agent();
require_method('POST');

try {
    $payload = passkey_begin();
    json_out(200, $payload);
} catch (Throwable $e) {
    error_log('[BTH] passkey/begin failed: ' . $e->getMessage());
    json_out(500, ['error' => 'passkey_begin_failed']);
}
