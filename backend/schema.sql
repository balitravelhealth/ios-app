-- Bali Travel Health — full database schema.
-- Apply once: mysql -u root -p < schema.sql

CREATE DATABASE IF NOT EXISTS balihealth
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE balihealth;

-- ── Users ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id              CHAR(36)        PRIMARY KEY,
    apple_sub       VARCHAR(255)    NULL UNIQUE,
    google_sub      VARCHAR(255)    NULL UNIQUE,
    email           VARCHAR(320)    NULL,
    name            VARCHAR(120)    NULL,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ── Sessions (bearer tokens) ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
    token           CHAR(64)        PRIMARY KEY,
    user_id         CHAR(36)        NOT NULL,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at      DATETIME        NOT NULL,
    revoked_at      DATETIME        NULL,
    INDEX (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Onboarding profile ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
    user_id         CHAR(36)        PRIMARY KEY,
    name            VARCHAR(120)    NOT NULL,
    country_code    CHAR(2)         NOT NULL,
    date_of_birth   DATE            NOT NULL,
    gender          ENUM('male','female') NOT NULL,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Optional travel window ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS travel_info (
    user_id         CHAR(36)        PRIMARY KEY,
    arrival_date    DATE            NOT NULL,
    departure_date  DATE            NOT NULL,
    season          ENUM('rainy','dry') NULL,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Nurse directory ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS nurses (
    id              CHAR(36)        PRIMARY KEY,
    name            VARCHAR(120)    NOT NULL,
    experience      VARCHAR(120)    NOT NULL,
    base_rate       DECIMAL(10,2)   NOT NULL,
    currency_code   CHAR(3)         NOT NULL DEFAULT 'IDR',
    avatar_url      VARCHAR(500)    NULL,
    bio             TEXT            NULL,
    whatsapp_number VARCHAR(32)     NOT NULL,
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ── Appointments ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS appointments (
    id              CHAR(36)        PRIMARY KEY,
    user_id         CHAR(36)        NOT NULL,
    nurse_id        CHAR(36)        NOT NULL,
    scheduled_at    DATETIME        NOT NULL,
    address         VARCHAR(500)    NOT NULL,
    latitude        DECIMAL(9,6)    NOT NULL,
    longitude       DECIMAL(9,6)    NOT NULL,
    description     VARCHAR(255)    NOT NULL,
    status          ENUM('confirmed','cancelled','completed') NOT NULL DEFAULT 'confirmed',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (user_id, scheduled_at),
    FOREIGN KEY (user_id)  REFERENCES users(id)   ON DELETE CASCADE,
    FOREIGN KEY (nurse_id) REFERENCES nurses(id)
) ENGINE=InnoDB;

-- ── Passkey credentials (one user can register multiple devices) ─────────
CREATE TABLE IF NOT EXISTS passkey_credentials (
    credential_id_b64u VARCHAR(255)  PRIMARY KEY,           -- base64url, easy to query
    user_id            CHAR(36)      NOT NULL,
    credential_source  MEDIUMBLOB    NOT NULL,              -- serialized PublicKeyCredentialSource
    sign_count         BIGINT UNSIGNED NOT NULL DEFAULT 0,
    transports         VARCHAR(120)  NULL,
    created_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at       DATETIME      NULL,
    INDEX (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Passkey ceremonies (short-lived register/login challenges) ───────────
CREATE TABLE IF NOT EXISTS passkey_ceremonies (
    id                     CHAR(64)      PRIMARY KEY,        -- random hex(32)
    creation_options       MEDIUMBLOB    NULL,                -- serialized PublicKeyCredentialCreationOptions
    request_options        MEDIUMBLOB    NULL,                -- serialized PublicKeyCredentialRequestOptions
    expires_at             DATETIME      NOT NULL
) ENGINE=InnoDB;

-- ── Optional: seed a couple of nurses so the iOS Nursing tab isn't empty ──
INSERT IGNORE INTO nurses (id, name, experience, base_rate, currency_code, whatsapp_number, bio) VALUES
  (UUID(), 'Made Suparna',  '8 years experience', 250000, 'IDR', '+6281234567890', 'Specialised in elderly home care.'),
  (UUID(), 'Putu Sari',     '5 years experience', 200000, 'IDR', '+6281234567891', 'Pediatric and post-op recovery.'),
  (UUID(), 'Ketut Adnyani', '12 years experience',300000, 'IDR', '+6281234567892', 'Senior ICU nurse, fluent in English & Japanese.');
