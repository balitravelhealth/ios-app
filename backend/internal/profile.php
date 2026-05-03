<?php
/**
 * GET  /internal/profile.php — return the saved profile + travel info, or 204.
 * POST /internal/profile.php — upsert onboarding profile + travel info.
 * Returns 204 No Content on success.
 */

declare(strict_types=1);

require_once __DIR__ . '/../lib/http.php';

require_app_user_agent();

// ── GET = fetch saved profile so the iOS client can resume onboarding ─────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $uid = require_auth();

    $stmt = db()->prepare(
        'SELECT name, country_code, date_of_birth, gender
           FROM profiles WHERE user_id = :u'
    );
    $stmt->execute([':u' => $uid]);
    $row = $stmt->fetch();
    if (!$row) no_content();

    $payload = [
        'name'         => $row['name'],
        'countryCode'  => $row['country_code'],
        'dateOfBirth'  => $row['date_of_birth'],     // YYYY-MM-DD
        'gender'       => $row['gender'],
    ];

    $tStmt = db()->prepare(
        'SELECT arrival_date, departure_date, season
           FROM travel_info WHERE user_id = :u'
    );
    $tStmt->execute([':u' => $uid]);
    if ($t = $tStmt->fetch()) {
        $payload['travel'] = [
            'arrivalDate'   => $t['arrival_date'],
            'departureDate' => $t['departure_date'],
            'season'        => $t['season'],
        ];
    }

    json_out(200, $payload);
}

require_method('POST');
$uid = require_auth();
$b   = json_input();

// ── Required profile fields ──────────────────────────────────────────────
$name         = trim((string) ($b['name']         ?? ''));
$countryCode  = strtoupper(trim((string) ($b['countryCode']  ?? '')));
$dateOfBirth  = trim((string) ($b['dateOfBirth']  ?? ''));
$gender       = strtolower(trim((string) ($b['gender']       ?? '')));

if ($name === '')                                      json_out(400, ['error' => 'missing_name']);
if (mb_strlen($name) > 64)                             json_out(400, ['error' => 'name_too_long']);
if (!preg_match('/^[A-Z]{2}$/', $countryCode))         json_out(400, ['error' => 'bad_country']);
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateOfBirth))json_out(400, ['error' => 'bad_dob']);
if (!in_array($gender, ['male','female'], true))       json_out(400, ['error' => 'bad_gender']);

db()->prepare(
    'INSERT INTO profiles (user_id, name, country_code, date_of_birth, gender)
     VALUES (:u, :n, :c, :d, :g)
     ON DUPLICATE KEY UPDATE
        name           = VALUES(name),
        country_code   = VALUES(country_code),
        date_of_birth  = VALUES(date_of_birth),
        gender         = VALUES(gender)'
)->execute([
    ':u' => $uid, ':n' => $name, ':c' => $countryCode,
    ':d' => $dateOfBirth, ':g' => $gender,
]);

// Also keep users.name fresh so the Profile screen has it.
db()->prepare('UPDATE users SET name = :n WHERE id = :u')
    ->execute([':n' => $name, ':u' => $uid]);

// ── Optional travel info ─────────────────────────────────────────────────
$arrival   = trim((string) ($b['arrivalDate']   ?? ''));
$departure = trim((string) ($b['departureDate'] ?? ''));
$season    = trim((string) ($b['season']        ?? ''));

if ($arrival !== '' && $departure !== '') {
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $arrival))   json_out(400, ['error' => 'bad_arrival']);
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $departure)) json_out(400, ['error' => 'bad_departure']);
    if ($departure < $arrival)                            json_out(400, ['error' => 'departure_before_arrival']);
    if ($season !== '' && !in_array($season, ['rainy','dry'], true)) {
        json_out(400, ['error' => 'bad_season']);
    }

    db()->prepare(
        'INSERT INTO travel_info (user_id, arrival_date, departure_date, season)
         VALUES (:u, :a, :d, :s)
         ON DUPLICATE KEY UPDATE
            arrival_date   = VALUES(arrival_date),
            departure_date = VALUES(departure_date),
            season         = VALUES(season)'
    )->execute([
        ':u' => $uid, ':a' => $arrival, ':d' => $departure,
        ':s' => $season !== '' ? $season : null,
    ]);
} else {
    db()->prepare('DELETE FROM travel_info WHERE user_id = :u')->execute([':u' => $uid]);
}

no_content();
