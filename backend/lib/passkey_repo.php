<?php
/**
 * Persistence for `web-auth/webauthn-lib`. Stores credential sources in MySQL.
 */

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/http.php';

use Webauthn\PublicKeyCredentialSource;
use Webauthn\PublicKeyCredentialSourceRepository;
use Webauthn\PublicKeyCredentialUserEntity;

final class BHPasskeyRepository implements PublicKeyCredentialSourceRepository
{
    public function findOneByCredentialId(string $publicKeyCredentialId): ?PublicKeyCredentialSource
    {
        $stmt = db()->prepare(
            'SELECT credential_source FROM passkey_credentials
              WHERE credential_id_b64u = :cid LIMIT 1'
        );
        $stmt->execute([':cid' => b64url($publicKeyCredentialId)]);
        $row = $stmt->fetch();
        if (!$row) return null;

        $data = json_decode($row['credential_source'], true, 32, JSON_THROW_ON_ERROR);
        return PublicKeyCredentialSource::createFromArray($data);
    }

    /** @return PublicKeyCredentialSource[] */
    public function findAllForUserEntity(PublicKeyCredentialUserEntity $publicKeyCredentialUserEntity): array
    {
        $stmt = db()->prepare(
            'SELECT credential_source FROM passkey_credentials
              WHERE user_id = :u'
        );
        $stmt->execute([':u' => $publicKeyCredentialUserEntity->getId()]);
        $out = [];
        foreach ($stmt->fetchAll() as $row) {
            $data = json_decode($row['credential_source'], true, 32, JSON_THROW_ON_ERROR);
            $out[] = PublicKeyCredentialSource::createFromArray($data);
        }
        return $out;
    }

    public function saveCredentialSource(PublicKeyCredentialSource $publicKeyCredentialSource): void
    {
        $cidB64u = b64url($publicKeyCredentialSource->getPublicKeyCredentialId());
        $userId  = $publicKeyCredentialSource->getUserHandle();
        $payload = json_encode($publicKeyCredentialSource, JSON_UNESCAPED_SLASHES);

        $stmt = db()->prepare(
            'INSERT INTO passkey_credentials
                (credential_id_b64u, user_id, credential_source, sign_count, transports, last_used_at)
             VALUES
                (:cid, :u, :src, :sc, :tr, NOW())
             ON DUPLICATE KEY UPDATE
                credential_source = VALUES(credential_source),
                sign_count        = VALUES(sign_count),
                last_used_at      = NOW()'
        );
        $stmt->execute([
            ':cid' => $cidB64u,
            ':u'   => $userId,
            ':src' => $payload,
            ':sc'  => $publicKeyCredentialSource->getCounter(),
            ':tr'  => implode(',', $publicKeyCredentialSource->getTransports()),
        ]);
    }
}
