<?php
/**
 * GET /internal/appointments-active.php — current/upcoming appointment.
 * Returns 204 if the user has no booking newer than 1 day ago.
 */

declare(strict_types=1);

require_once __DIR__ . '/../lib/http.php';

require_app_user_agent();
require_method('GET');
$uid = require_auth();

$stmt = db()->prepare(
    "SELECT a.id, a.nurse_id, a.scheduled_at, a.address,
            n.name AS nurse_name,
            n.avatar_url AS nurse_avatar_url,
            n.whatsapp_number
       FROM appointments a
       JOIN nurses n ON n.id = a.nurse_id
      WHERE a.user_id = :u
        AND a.status  = 'confirmed'
        AND a.scheduled_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY)
      ORDER BY a.scheduled_at ASC
      LIMIT 1"
);
$stmt->execute([':u' => $uid]);
$row = $stmt->fetch();

if (!$row) no_content();

json_out(200, [
    'id'             => $row['id'],
    'nurseId'        => $row['nurse_id'],
    'nurseName'      => $row['nurse_name'],
    'nurseAvatarUrl' => $row['nurse_avatar_url'],
    'nurseWhatsapp'  => $row['whatsapp_number'],
    'address'        => $row['address'],
    'scheduledAt'    => gmdate('c', strtotime($row['scheduled_at'])),
]);
