<?php
/**
 * GET /internal/nurses.php — list all active nurses.
 * Public read (no auth) but still gated by the User-Agent check.
 */

declare(strict_types=1);

require_once __DIR__ . '/../lib/http.php';

require_app_user_agent();
require_method('GET');

$rows = db()->query(
    'SELECT id, name, experience, base_rate, currency_code, avatar_url, bio
       FROM nurses
      WHERE is_active = 1
      ORDER BY name'
)->fetchAll();

// Cast numeric strings → numbers for clean Decimal decoding on iOS.
foreach ($rows as &$r) {
    $r['base_rate'] = (float) $r['base_rate'];
}

json_out(200, $rows);
