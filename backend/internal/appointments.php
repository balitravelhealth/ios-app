<?php
/**
 * POST /internal/appointments.php — create a nursing appointment.
 */

declare(strict_types=1);

require_once __DIR__ . '/../lib/http.php';

require_app_user_agent();
require_method('POST');
$uid = require_auth();
$b   = json_input();

$nurseId      = trim((string) ($b['nurseId']     ?? ''));
$scheduledAt  = trim((string) ($b['scheduledAt'] ?? ''));
$address      = trim((string) ($b['address']     ?? ''));
$lat          = $b['latitude']  ?? null;
$lng          = $b['longitude'] ?? null;
$description  = trim((string) ($b['description'] ?? ''));

if (!preg_match('/^[0-9a-f-]{36}$/', $nurseId))      json_out(400, ['error' => 'bad_nurse_id']);
if (mb_strlen($address) === 0 || mb_strlen($address) > 500)
                                                      json_out(400, ['error' => 'bad_address']);
if (mb_strlen($description) === 0 || mb_strlen($description) > 255)
                                                      json_out(400, ['error' => 'bad_description']);
if (!is_numeric($lat) || !is_numeric($lng))           json_out(400, ['error' => 'bad_coords']);

$ts = strtotime($scheduledAt);
if ($ts === false || $ts < time() - 60)               json_out(400, ['error' => 'bad_scheduled_at']);

// Verify nurse exists and is active.
$check = db()->prepare('SELECT 1 FROM nurses WHERE id = :id AND is_active = 1');
$check->execute([':id' => $nurseId]);
if (!$check->fetch())                                 json_out(404, ['error' => 'nurse_not_found']);

$id = uuid();
db()->prepare(
    'INSERT INTO appointments
        (id, user_id, nurse_id, scheduled_at, address, latitude, longitude, description)
     VALUES
        (:id, :u, :n, :s, :a, :lat, :lng, :d)'
)->execute([
    ':id'  => $id,
    ':u'   => $uid,
    ':n'   => $nurseId,
    ':s'   => gmdate('Y-m-d H:i:s', $ts),
    ':a'   => $address,
    ':lat' => (float) $lat,
    ':lng' => (float) $lng,
    ':d'   => $description,
]);

json_out(200, ['appointmentId' => $id]);
