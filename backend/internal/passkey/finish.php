<?php
/**
 * POST /internal/passkey/finish
 * Verifies a registration or assertion result and returns ServerSession.
 *
 * Any failure → HTTP 401. The iOS client maps 401 to
 * `AuthenticationError.unauthorized` and blocks the user from continuing.
 */

declare(strict_types=1);

require_once __DIR__ . '/../../lib/http.php';
require_once __DIR__ . '/../../lib/passkey_service.php';

require_app_user_agent();
require_method('POST');

$body = json_input();
$type = $body['type'] ?? '';
if (!in_array($type, ['registration', 'assertion'], true)) {
    json_out(400, ['error' => 'bad_type']);
}

try {
    $result = passkey_finish($body);
} catch (Throwable $e) {
    error_log('[BTH] passkey/finish failed: ' . $e->getMessage());
    json_out(401, ['error' => 'passkey_verification_failed']);
}

json_out(200, [
    'sessionToken' => $result['sessionToken'],
    'refreshToken' => null,
    'userID'       => $result['userId'],
    'name'         => $result['name'],
    'email'        => $result['email'],
    'isNewUser'    => $type === 'registration',
]);
