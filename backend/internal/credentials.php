<?php
/**
 * POST /internal/credentials.php — sign-in / sign-up.
 * GET  /internal/credentials.php — validate session token.
 *
 * Used by Apple + Google paths (the iOS client switches "provider").
 * Passkey users go through /internal/passkey/* instead.
 */

declare(strict_types=1);

require_once __DIR__ . '/../lib/http.php';
require_once __DIR__ . '/../lib/apple_verify.php';   // also defines verify_identity_token

require_app_user_agent();

// ── GET = session validation ─────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $uid = auth_user_id();
    if (!$uid) json_out(401, ['error' => 'unauthorized']);
    json_out(200, ['userID' => $uid]);
}

require_method('POST');

// ── POST body ────────────────────────────────────────────────────────────
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

// ── Verify the identity token against the provider's JWKS ────────────────
try {
    $verified = verify_identity_token($provider, $idToken);
} catch (Throwable $e) {
    $reason = $e->getMessage();
    error_log('[BTH] identity verify failed: ' . $reason);
    // The reason strings come from verify_google_token / verify_apple_token
    // (`bad_audience`, `invalid_jwt`, etc.). They're safe to show — they
    // describe the *category* of failure, not the secret material.
    json_out(401, ['error' => 'invalid_identity_token', 'reason' => $reason]);
}
if ($verified['sub'] !== $providerSub) {
    json_out(401, ['error' => 'token_subject_mismatch']);
}

// ── Look up or create the user ───────────────────────────────────────────
$col = $provider === 'apple' ? 'apple_sub' : 'google_sub';
$stmt = db()->prepare("SELECT id, name, email FROM users WHERE $col = :s LIMIT 1");
$stmt->execute([':s' => $providerSub]);
$user = $stmt->fetch();

if ($action === 'signin') {
    if (!$user) json_out(404, ['code' => 'user_not_found']);
} else {
    if ($user) json_out(409, ['code' => 'user_exists']);

    $userId = uuid();
    $insert = db()->prepare(
        "INSERT INTO users (id, $col, email, name) VALUES (:id, :s, :e, :n)"
    );
    $insert->execute([
        ':id' => $userId,
        ':s'  => $providerSub,
        ':e'  => $email ?: $verified['email'],
        ':n'  => $name  ?: $verified['name'],
    ]);
    $user = [
        'id'    => $userId,
        'name'  => $name ?: $verified['name'],
        'email' => $email ?: $verified['email'],
    ];
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
