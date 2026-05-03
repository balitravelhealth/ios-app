<?php
/**
 * Wires `web-auth/webauthn-lib` together. Exposes `passkey_begin()` and
 * `passkey_finish()` used by the two passkey endpoints.
 */

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/passkey_repo.php';

use Cose\Algorithm\Manager as CoseAlgorithmManager;
use Cose\Algorithm\Signature\ECDSA\ES256;
use Cose\Algorithm\Signature\RSA\RS256;
use Webauthn\AttestationStatement\AttestationObjectLoader;
use Webauthn\AttestationStatement\AttestationStatementSupportManager;
use Webauthn\AttestationStatement\NoneAttestationStatementSupport;
use Webauthn\AuthenticationExtensions\ExtensionOutputCheckerHandler;
use Webauthn\AuthenticatorAssertionResponse;
use Webauthn\AuthenticatorAssertionResponseValidator;
use Webauthn\AuthenticatorAttestationResponse;
use Webauthn\AuthenticatorAttestationResponseValidator;
use Webauthn\AuthenticatorSelectionCriteria;
use Webauthn\PublicKeyCredentialCreationOptions;
use Webauthn\PublicKeyCredentialDescriptor;
use Webauthn\PublicKeyCredentialLoader;
use Webauthn\PublicKeyCredentialParameters;
use Webauthn\PublicKeyCredentialRequestOptions;
use Webauthn\PublicKeyCredentialRpEntity;
use Webauthn\PublicKeyCredentialUserEntity;
use Webauthn\TokenBinding\IgnoreTokenBindingHandler;

// ─── Library wiring ───────────────────────────────────────────────────────

function passkey_repository(): BHPasskeyRepository {
    static $r = null;
    return $r ??= new BHPasskeyRepository();
}

function passkey_attestation_manager(): AttestationStatementSupportManager {
    static $m = null;
    if ($m === null) {
        $m = new AttestationStatementSupportManager();
        // iOS Passkeys self-attest; "none" is the right choice for UX-first apps.
        $m->add(new NoneAttestationStatementSupport());
    }
    return $m;
}

function passkey_credential_loader(): PublicKeyCredentialLoader {
    static $l = null;
    return $l ??= new PublicKeyCredentialLoader(
        new AttestationObjectLoader(passkey_attestation_manager())
    );
}

function passkey_attestation_validator(): AuthenticatorAttestationResponseValidator {
    static $v = null;
    return $v ??= new AuthenticatorAttestationResponseValidator(
        passkey_attestation_manager(),
        passkey_repository(),
        new IgnoreTokenBindingHandler(),
        new ExtensionOutputCheckerHandler()
    );
}

function passkey_assertion_validator(): AuthenticatorAssertionResponseValidator {
    static $v = null;
    return $v ??= new AuthenticatorAssertionResponseValidator(
        passkey_repository(),
        new IgnoreTokenBindingHandler(),
        new ExtensionOutputCheckerHandler(),
        new CoseAlgorithmManager()
            // ES256 (most common; Apple's default) and RS256 (legacy):
            // $am->add(new ES256()); etc.
    );
}

function cose_algorithm_manager(): CoseAlgorithmManager {
    static $m = null;
    if ($m === null) {
        $m = new CoseAlgorithmManager();
        $m->add(new ES256());
        $m->add(new RS256());
    }
    return $m;
}

// ─── Begin: produce both creation + request options ───────────────────────

function passkey_begin(): array {
    $cfg = require __DIR__ . '/env.php';

    $rp = new PublicKeyCredentialRpEntity($cfg['rp_name'], $cfg['rp_id']);

    // The user entity is opaque; we generate a temporary id that the client
    // will associate with the new account if registration happens.
    $tempUserId = random_bytes(16);
    $user = new PublicKeyCredentialUserEntity(
        'new-user-' . bin2hex(substr($tempUserId, 0, 4)),
        $tempUserId,
        $cfg['rp_name']
    );

    $creation = new PublicKeyCredentialCreationOptions(
        $rp,
        $user,
        random_bytes(32),
        [
            new PublicKeyCredentialParameters('public-key', -7),  // ES256
            new PublicKeyCredentialParameters('public-key', -257),// RS256
        ]
    );
    $creation
        ->setAuthenticatorSelection(
            AuthenticatorSelectionCriteria::create()
                ->setUserVerification(AuthenticatorSelectionCriteria::USER_VERIFICATION_REQUIREMENT_PREFERRED)
                ->setAuthenticatorAttachment(AuthenticatorSelectionCriteria::AUTHENTICATOR_ATTACHMENT_PLATFORM)
        )
        ->setAttestation(PublicKeyCredentialCreationOptions::ATTESTATION_CONVEYANCE_PREFERENCE_NONE)
        ->setTimeout(300_000);

    $request = new PublicKeyCredentialRequestOptions(random_bytes(32));
    $request->setRpId($cfg['rp_id'])
            ->setUserVerification(PublicKeyCredentialRequestOptions::USER_VERIFICATION_REQUIREMENT_PREFERRED)
            ->setTimeout(300_000);

    // Persist both options under one ceremony id; client doesn't see the id —
    // we bind via short-lived secure cookie.
    $ceremonyId = bin2hex(random_bytes(32));
    db()->prepare(
        'INSERT INTO passkey_ceremonies (id, creation_options, request_options, expires_at)
         VALUES (:id, :co, :ro, DATE_ADD(NOW(), INTERVAL 5 MINUTE))'
    )->execute([
        ':id' => $ceremonyId,
        ':co' => json_encode($creation, JSON_UNESCAPED_SLASHES),
        ':ro' => json_encode($request,  JSON_UNESCAPED_SLASHES),
    ]);

    setcookie('bth_ceremony', $ceremonyId, [
        'expires'  => time() + 300,
        'path'     => '/internal/passkey',
        'httponly' => true,
        'secure'   => true,
        'samesite' => 'Strict',
    ]);

    return [
        'rpId'                    => $cfg['rp_id'],
        'registrationChallenge'   => b64url($creation->getChallenge()),
        'registrationUserId'      => b64url($tempUserId),
        'registrationDisplayName' => $cfg['rp_name'],
        'loginChallenge'          => b64url($request->getChallenge()),
    ];
}

// ─── Finish: verify whatever the client returned ──────────────────────────

/** @return array{userId:string, sessionToken:string, name:?string, email:?string} */
function passkey_finish(array $body): array {
    $ceremonyId = $_COOKIE['bth_ceremony'] ?? '';
    if (!$ceremonyId) throw new RuntimeException('missing_ceremony');

    $stmt = db()->prepare('SELECT * FROM passkey_ceremonies WHERE id = :id AND expires_at > NOW()');
    $stmt->execute([':id' => $ceremonyId]);
    $ceremony = $stmt->fetch();
    if (!$ceremony) throw new RuntimeException('ceremony_expired');

    // One-time use — burn the ceremony so it can't be replayed.
    db()->prepare('DELETE FROM passkey_ceremonies WHERE id = :id')->execute([':id' => $ceremonyId]);

    $type = $body['type'] ?? '';
    if ($type === 'registration') {
        return passkey_finish_registration($body, $ceremony);
    } elseif ($type === 'assertion') {
        return passkey_finish_assertion($body, $ceremony);
    } else {
        throw new RuntimeException('bad_type');
    }
}

function passkey_finish_registration(array $body, array $ceremony): array {
    $cfg      = require __DIR__ . '/env.php';
    $creation = PublicKeyCredentialCreationOptions::createFromString($ceremony['creation_options']);

    // Build the credential response from the iOS payload (keys are camelCase
    // from Swift, but the loader expects WebAuthn shape — adapt below).
    $credentialJson = json_encode([
        'id'       => $body['credentialId'],
        'rawId'    => $body['credentialId'],
        'type'     => 'public-key',
        'response' => [
            'attestationObject' => $body['attestationObject'],
            'clientDataJSON'    => $body['clientDataJSON'],
        ],
    ], JSON_UNESCAPED_SLASHES);

    $credential = passkey_credential_loader()->load($credentialJson);
    $response   = $credential->getResponse();
    if (!$response instanceof AuthenticatorAttestationResponse) {
        throw new RuntimeException('not_attestation');
    }

    $source = passkey_attestation_validator()->check(
        $response,
        $creation,
        // PSR-7 request — the lib only uses Host/origin.
        passkey_psr7_request()
    );

    // Mint a real user row keyed off the credential's user handle.
    $userId = uuid();
    db()->prepare('INSERT INTO users (id) VALUES (:id)')->execute([':id' => $userId]);

    // Re-bind the credential source to the real user id, then save.
    $sourceWithUser = $source->setUserHandle($userId);
    passkey_repository()->saveCredentialSource($sourceWithUser);

    return [
        'userId'       => $userId,
        'sessionToken' => issue_session($userId),
        'name'         => null,
        'email'        => null,
    ];
}

function passkey_finish_assertion(array $body, array $ceremony): array {
    $cfg     = require __DIR__ . '/env.php';
    $request = PublicKeyCredentialRequestOptions::createFromString($ceremony['request_options']);

    $credentialJson = json_encode([
        'id'       => $body['credentialId'],
        'rawId'    => $body['credentialId'],
        'type'     => 'public-key',
        'response' => [
            'authenticatorData' => $body['authenticatorData'],
            'clientDataJSON'    => $body['clientDataJSON'],
            'signature'         => $body['signature'],
            'userHandle'        => $body['userHandle'] ?? null,
        ],
    ], JSON_UNESCAPED_SLASHES);

    $credential = passkey_credential_loader()->load($credentialJson);
    $response   = $credential->getResponse();
    if (!$response instanceof AuthenticatorAssertionResponse) {
        throw new RuntimeException('not_assertion');
    }

    $userHandle = isset($body['userHandle']) ? b64url_decode($body['userHandle']) : null;

    $source = passkey_assertion_validator()->check(
        $credential->getRawId(),
        $response,
        $request,
        passkey_psr7_request(),
        $userHandle
    );

    $userId = $source->getUserHandle();
    $stmt   = db()->prepare('SELECT name, email FROM users WHERE id = :id');
    $stmt->execute([':id' => $userId]);
    $row = $stmt->fetch() ?: ['name' => null, 'email' => null];

    return [
        'userId'       => $userId,
        'sessionToken' => issue_session($userId),
        'name'         => $row['name'],
        'email'        => $row['email'],
    ];
}

/** Build a tiny PSR-7 request object the validators expect. */
function passkey_psr7_request(): \Psr\Http\Message\ServerRequestInterface {
    $factory = new \Nyholm\Psr7\Factory\Psr17Factory();
    return $factory
        ->createServerRequest($_SERVER['REQUEST_METHOD'] ?? 'POST',
                              ($_SERVER['HTTPS'] ?? '' ? 'https://' : 'http://')
                              . ($_SERVER['HTTP_HOST'] ?? 'localhost')
                              . ($_SERVER['REQUEST_URI'] ?? '/'));
}
