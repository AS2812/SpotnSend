
-- ------------------------------------------------------
-- Civic Watch - PostgreSQL schema
-- ------------------------------------------------------

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS civic_app;
COMMENT ON SCHEMA civic_app IS 'Core tables for the civic incident reporting and mapping application.';
SET search_path TO civic_app, public;

-- === Enumerated types ===
CREATE TYPE account_status AS ENUM ('pending', 'verified', 'suspended');
CREATE TYPE user_role AS ENUM ('user', 'moderator', 'admin');
CREATE TYPE verification_status AS ENUM ('pending', 'approved', 'rejected', 'cancelled');
CREATE TYPE notify_scope AS ENUM ('people', 'government', 'both');
CREATE TYPE report_state AS ENUM ('submitted', 'under_review', 'approved', 'rejected', 'archived');
CREATE TYPE media_kind AS ENUM ('image', 'video');
CREATE TYPE notification_type AS ENUM ('system', 'report_update', 'verification', 'reminder');
CREATE TYPE notification_channel AS ENUM ('in_app', 'push', 'email', 'sms');
CREATE TYPE notification_delivery_status AS ENUM ('pending', 'sent', 'delivered', 'failed');
CREATE TYPE two_factor_method AS ENUM ('totp', 'sms', 'email');
CREATE TYPE feedback_kind AS ENUM ('comment', 'status_update', 'resolution', 'admin_note');
CREATE TYPE language_code AS ENUM ('en', 'ar');
CREATE TYPE theme_preference AS ENUM ('light', 'dark', 'system');
CREATE TYPE map_view_mode AS ENUM ('map', 'list');
CREATE TYPE identity_document_kind AS ENUM ('national_id_front', 'national_id_back', 'selfie');
CREATE TYPE bug_status AS ENUM ('open', 'investigating', 'resolved', 'closed');
CREATE TYPE audit_action AS ENUM ('insert', 'update', 'delete');
CREATE TYPE report_flag_reason AS ENUM ('spam', 'misleading', 'duplicate', 'test', 'other');
CREATE TYPE authority_level AS ENUM ('local', 'regional', 'national');
CREATE TYPE report_dispatch_status AS ENUM ('pending', 'notified', 'acknowledged', 'dismissed');
CREATE TYPE report_priority AS ENUM ('low', 'normal', 'high', 'critical');
-- === Users & authentication ===
CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    username CITEXT NOT NULL UNIQUE,
    email CITEXT NOT NULL UNIQUE,
    hashed_password TEXT NOT NULL,
    password_changed_at TIMESTAMPTZ,
    phone_country_code VARCHAR(8),
    phone_number VARCHAR(32),
    phone_verified_at TIMESTAMPTZ,
    id_number VARCHAR(50),
    account_status account_status NOT NULL DEFAULT ''pending'',
    role user_role NOT NULL DEFAULT ''user'',
    allow_persistent_sessions BOOLEAN NOT NULL DEFAULT FALSE,
    two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    failed_login_attempts SMALLINT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT phone_presence CHECK ((phone_country_code IS NULL) = (phone_number IS NULL)),
    CONSTRAINT full_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT username_not_blank CHECK (btrim(username::TEXT) <> ''),
    CONSTRAINT email_not_blank CHECK (btrim(email::TEXT) <> ''),
    CONSTRAINT id_number_not_blank CHECK (id_number IS NULL OR btrim(id_number) <> ''),
    CONSTRAINT users_failed_attempts_ck CHECK (failed_login_attempts >= 0)
);

COMMENT ON TABLE users IS 'Application users, including authentication fields and verification state.';
COMMENT ON COLUMN users.allow_persistent_sessions IS 'Set when the user opts into remember-me sessions.';
COMMENT ON COLUMN users.two_factor_enabled IS 'True when at least one 2FA method is active.';
COMMENT ON COLUMN users.failed_login_attempts IS 'Incremented on incorrect password attempts to drive temporary lockouts.';

CREATE UNIQUE INDEX users_phone_unique_idx
    ON users (phone_country_code, phone_number)
    WHERE phone_number IS NOT NULL;

CREATE UNIQUE INDEX users_id_number_unique_idx
    ON users (id_number)
    WHERE id_number IS NOT NULL;

CREATE TABLE user_identity_documents (
    document_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    document_type identity_document_kind NOT NULL,
    file_url TEXT NOT NULL,
    file_hash TEXT,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT document_url_not_blank CHECK (btrim(file_url) <> '')
);

COMMENT ON TABLE user_identity_documents IS 'Uploaded identity artefacts collected during verification.';
COMMENT ON COLUMN user_identity_documents.file_hash IS 'Optional hash to detect duplicate uploads.';

CREATE UNIQUE INDEX user_identity_documents_type_unq
    ON user_identity_documents (user_id, document_type);

CREATE TABLE account_verifications (
    verification_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status verification_status NOT NULL DEFAULT ''pending'',
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    rejection_reason TEXT,
    notes TEXT,
    CONSTRAINT account_verification_review CHECK (
        (status = ''pending'' AND reviewed_at IS NULL) OR
        (status <> ''pending'' AND reviewed_at IS NOT NULL)
    )
);

COMMENT ON TABLE account_verifications IS 'History of verification requests and their outcomes.';

CREATE INDEX account_verifications_user_idx
    ON account_verifications (user_id, submitted_at DESC);

CREATE UNIQUE INDEX account_verifications_pending_unq
    ON account_verifications (user_id)
    WHERE status = ''pending'';

CREATE TABLE phone_verifications (
    phone_verification_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    phone_country_code VARCHAR(8) NOT NULL,
    phone_number VARCHAR(32) NOT NULL,
    channel notification_channel NOT NULL DEFAULT ''sms'',
    code_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    verified_at TIMESTAMPTZ,
    attempt_count SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT phone_verifications_number_not_blank CHECK (btrim(phone_number) <> ''),
    CONSTRAINT phone_verifications_country_not_blank CHECK (btrim(phone_country_code) <> ''),
    CONSTRAINT phone_verifications_code_not_blank CHECK (btrim(code_hash) <> ''),
    CONSTRAINT phone_verifications_attempts_ck CHECK (attempt_count >= 0)
);

COMMENT ON TABLE phone_verifications IS 'SMS verification codes issued during onboarding.';

CREATE INDEX phone_verifications_user_idx
    ON phone_verifications (user_id, created_at DESC);

CREATE UNIQUE INDEX phone_verifications_active_idx
    ON phone_verifications (user_id)
    WHERE verified_at IS NULL;

CREATE TABLE user_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL,
    client_ip INET,
    user_agent TEXT,
    device_name VARCHAR(120),
    remember_me BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    CONSTRAINT refresh_token_not_blank CHECK (btrim(refresh_token_hash) <> '')
);

COMMENT ON TABLE user_sessions IS 'Persistent sessions for login and remember-me tokens.';

CREATE UNIQUE INDEX user_sessions_refresh_token_unq
    ON user_sessions (refresh_token_hash);

CREATE INDEX user_sessions_user_idx
    ON user_sessions (user_id, expires_at);
-- === Reporting taxonomy ===
CREATE TABLE report_categories (
    category_id SMALLSERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    slug VARCHAR(80) NOT NULL,
    description TEXT,
    icon_name VARCHAR(64),
    color_hex VARCHAR(9),
    sort_order SMALLINT NOT NULL DEFAULT 100,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT report_categories_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT report_categories_slug_not_blank CHECK (btrim(slug) <> '')
);

COMMENT ON TABLE report_categories IS 'Top-level taxonomy used to filter and display incident reports.';

CREATE UNIQUE INDEX report_categories_name_unq
    ON report_categories (lower(name));

CREATE UNIQUE INDEX report_categories_slug_unq
    ON report_categories (lower(slug));

CREATE TABLE report_subcategories (
    subcategory_id SERIAL PRIMARY KEY,
    category_id SMALLINT NOT NULL REFERENCES report_categories(category_id) ON DELETE CASCADE,
    name VARCHAR(80) NOT NULL,
    description TEXT,
    sort_order SMALLINT NOT NULL DEFAULT 100,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT report_subcategories_name_not_blank CHECK (btrim(name) <> '')
);

ALTER TABLE report_subcategories
    ADD CONSTRAINT report_subcategories_category_pair UNIQUE (subcategory_id, category_id);

COMMENT ON TABLE report_subcategories IS 'Fine-grained categories that depend on a parent category.';

CREATE UNIQUE INDEX report_subcategories_name_unq
    ON report_subcategories (category_id, lower(name));
-- === Authorities domain ===
CREATE TABLE authorities (
    authority_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    slug VARCHAR(150) NOT NULL,
    description TEXT,
    level authority_level NOT NULL DEFAULT ''national'',
    contact_person VARCHAR(120),
    contact_email CITEXT,
    contact_phone VARCHAR(32),
    hotline_phone VARCHAR(32),
    website_url TEXT,
    service_radius_meters INTEGER NOT NULL DEFAULT 20000,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_geog geography(Point, 4326) GENERATED ALWAYS AS (
        CASE
            WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN
                ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
            ELSE NULL
        END
    ) STORED,
    address TEXT,
    city VARCHAR(120),
    region VARCHAR(120),
    country VARCHAR(120),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT authorities_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT authorities_slug_not_blank CHECK (btrim(slug) <> ''),
    CONSTRAINT authorities_radius_ck CHECK (service_radius_meters BETWEEN 100 AND 500000)
);

COMMENT ON TABLE authorities IS 'Government or national agencies that receive escalated reports.';

CREATE UNIQUE INDEX authorities_slug_unq
    ON authorities (lower(slug));

CREATE UNIQUE INDEX authorities_name_unq
    ON authorities (lower(name));

CREATE INDEX authorities_active_idx
    ON authorities (is_active);

CREATE INDEX authorities_location_geog_idx
    ON authorities USING GIST (location_geog);

CREATE TABLE authority_categories (
    authority_id BIGINT NOT NULL REFERENCES authorities(authority_id) ON DELETE CASCADE,
    category_id SMALLINT NOT NULL REFERENCES report_categories(category_id) ON DELETE CASCADE,
    PRIMARY KEY (authority_id, category_id)
);

COMMENT ON TABLE authority_categories IS 'Maps authorities to the report categories they handle.';
-- === Reports & media ===
CREATE TABLE reports (
    report_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    category_id SMALLINT NOT NULL REFERENCES report_categories(category_id) ON DELETE RESTRICT,
    subcategory_id INTEGER REFERENCES report_subcategories(subcategory_id) ON DELETE SET NULL,
    status report_state NOT NULL DEFAULT ''submitted'',
    priority report_priority NOT NULL DEFAULT ''normal'',
    notify_scope notify_scope NOT NULL DEFAULT ''people'',
    description TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location_geog geography(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
    ) STORED,
    location_name TEXT,
    address TEXT,
    city VARCHAR(120),
    alert_radius_meters INTEGER DEFAULT 500,
    government_ticket_ref TEXT,
    notified_people_at TIMESTAMPTZ,
    notified_government_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    CONSTRAINT reports_description_not_blank CHECK (btrim(description) <> ''),
    CONSTRAINT reports_latitude_ck CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT reports_longitude_ck CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT reports_alert_radius_ck CHECK (alert_radius_meters IS NULL OR alert_radius_meters BETWEEN 50 AND 20000)
);

ALTER TABLE reports
    ADD CONSTRAINT reports_subcategory_consistency
    FOREIGN KEY (subcategory_id, category_id)
    REFERENCES report_subcategories(subcategory_id, category_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED;

COMMENT ON TABLE reports IS 'Incidents submitted by users, available on the map and list views.';
COMMENT ON COLUMN reports.alert_radius_meters IS 'Snapshot of the radius chosen when the report was filed.';
COMMENT ON COLUMN reports.notify_scope IS 'Target audience selected in the report form.';
COMMENT ON COLUMN reports.location_geog IS 'Geography point used for distance queries.';
COMMENT ON COLUMN reports.priority IS 'Used to escalate critical reports to authorities.';

CREATE INDEX reports_category_idx
    ON reports (category_id, subcategory_id);

CREATE INDEX reports_state_idx
    ON reports (status);

CREATE INDEX reports_priority_idx
    ON reports (priority);

CREATE INDEX reports_created_idx
    ON reports (created_at DESC);

CREATE INDEX reports_user_idx
    ON reports (user_id, created_at DESC);

CREATE INDEX reports_location_geog_idx
    ON reports USING GIST (location_geog);

CREATE TABLE report_media (
    media_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id BIGINT NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    media_type media_kind NOT NULL,
    storage_url TEXT NOT NULL,
    thumbnail_url TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_cover BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT report_media_url_not_blank CHECK (btrim(storage_url) <> '')
);

COMMENT ON TABLE report_media IS 'Image and video attachments linked to a report.';

CREATE INDEX report_media_report_idx
    ON report_media (report_id);

CREATE UNIQUE INDEX report_media_cover_idx
    ON report_media (report_id)
    WHERE is_cover;

CREATE TABLE report_feedbacks (
    feedback_id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    feedback_type feedback_kind NOT NULL DEFAULT ''comment'',
    comment TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT report_feedbacks_comment_not_blank CHECK (btrim(comment) <> '')
);

COMMENT ON TABLE report_feedbacks IS 'User feedback entries that power account stats.';

CREATE INDEX report_feedbacks_report_idx
    ON report_feedbacks (report_id, created_at);

CREATE INDEX report_feedbacks_user_idx
    ON report_feedbacks (user_id, created_at);

CREATE TABLE report_flags (
    flag_id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    reason report_flag_reason NOT NULL DEFAULT ''spam'',
    details TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT report_flags_reason_details_ck CHECK (
        reason <> ''other'' OR (details IS NOT NULL AND btrim(details) <> '')
    )
);

COMMENT ON TABLE report_flags IS 'Crowd-sourced flags to detect spam or abusive reports.';

CREATE UNIQUE INDEX report_flags_unique_flagger
    ON report_flags (report_id, user_id);

CREATE INDEX report_flags_report_idx
    ON report_flags (report_id);

CREATE INDEX report_flags_user_idx
    ON report_flags (user_id);

CREATE TABLE report_authority_dispatches (
    dispatch_id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES reports(report_id) ON DELETE CASCADE,
    authority_id BIGINT NOT NULL REFERENCES authorities(authority_id) ON DELETE CASCADE,
    status report_dispatch_status NOT NULL DEFAULT ''pending'',
    channel notification_channel,
    notified_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    dismissed_at TIMESTAMPTZ,
    notes TEXT,
    created_by BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT report_authority_dispatch_unique UNIQUE (report_id, authority_id)
);

COMMENT ON TABLE report_authority_dispatches IS 'Tracks when authorities are notified about a report and their acknowledgement status.';

CREATE INDEX report_authority_dispatch_status_idx
    ON report_authority_dispatches (status, notified_at DESC);

CREATE INDEX report_authority_dispatch_report_idx
    ON report_authority_dispatches (report_id);

CREATE INDEX report_authority_dispatch_authority_idx
    ON report_authority_dispatches (authority_id);
-- === Map preferences & favourites ===
CREATE TABLE favorite_spots (
    favorite_spot_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(80) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location_geog geography(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
    ) STORED,
    radius_meters INTEGER NOT NULL DEFAULT 250,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT favorite_spots_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT favorite_spots_latitude_ck CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT favorite_spots_longitude_ck CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT favorite_spots_radius_ck CHECK (radius_meters BETWEEN 50 AND 20000)
);

COMMENT ON TABLE favorite_spots IS 'User-defined locations that always trigger alerts.';

CREATE INDEX favorite_spots_user_idx
    ON favorite_spots (user_id);

CREATE INDEX favorite_spots_location_idx
    ON favorite_spots USING GIST (location_geog);

CREATE TABLE user_map_preferences (
    user_id BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    default_radius_meters INTEGER NOT NULL DEFAULT 1000,
    default_view map_view_mode NOT NULL DEFAULT ''map'',
    include_favorites_by_default BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_map_preferences_radius_ck CHECK (default_radius_meters BETWEEN 50 AND 20000)
);

COMMENT ON TABLE user_map_preferences IS 'Stores the last-used radius/view filters per user.';

CREATE TABLE user_category_filters (
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    category_id SMALLINT NOT NULL REFERENCES report_categories(category_id) ON DELETE CASCADE,
    is_selected BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, category_id)
);

COMMENT ON TABLE user_category_filters IS 'Optional overrides for each user''s default category selections.';
-- === Notifications ===
CREATE TABLE notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    notification_type notification_type NOT NULL DEFAULT ''system'',
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    related_report_id BIGINT REFERENCES reports(report_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    seen_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT notifications_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT notifications_body_not_blank CHECK (btrim(body) <> '')
);

COMMENT ON TABLE notifications IS 'Per-user inbox surfaced in the notifications tab.';

CREATE INDEX notifications_user_idx
    ON notifications (user_id, created_at DESC);

CREATE INDEX notifications_unseen_idx
    ON notifications (user_id)
    WHERE seen_at IS NULL AND deleted_at IS NULL;

CREATE TABLE notification_deliveries (
    delivery_id BIGSERIAL PRIMARY KEY,
    notification_id BIGINT NOT NULL REFERENCES notifications(notification_id) ON DELETE CASCADE,
    channel notification_channel NOT NULL,
    status notification_delivery_status NOT NULL DEFAULT ''pending'',
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT notification_deliveries_unique_channel UNIQUE (notification_id, channel)
);

CREATE INDEX notification_deliveries_status_idx
    ON notification_deliveries (status, created_at DESC);

CREATE TABLE user_notification_preferences (
    user_id BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    email_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE user_notification_preferences IS 'Fine-grained toggles for push/email/SMS delivery.';
-- === Settings ===
CREATE TABLE user_settings (
    user_id BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    language language_code NOT NULL DEFAULT ''en'',
    theme theme_preference NOT NULL DEFAULT ''light'',
    contact_email TEXT,
    contact_phone VARCHAR(32),
    two_factor_prompt BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_settings_contact_email_not_blank CHECK (contact_email IS NULL OR btrim(contact_email) <> '')
);

COMMENT ON TABLE user_settings IS 'App preferences surfaced on the settings tab.';

-- === Security ===
CREATE TABLE two_factor_methods (
    two_factor_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    method two_factor_method NOT NULL,
    secret TEXT NOT NULL,
    label TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    CONSTRAINT two_factor_secret_not_blank CHECK (btrim(secret) <> '')
);

COMMENT ON TABLE two_factor_methods IS 'Second-factor secrets (TOTP, SMS backup codes, etc.).';

CREATE UNIQUE INDEX two_factor_methods_user_method_unq
    ON two_factor_methods (user_id, method)
    WHERE enabled;

-- === Support ===
CREATE TABLE bug_reports (
    bug_report_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status bug_status NOT NULL DEFAULT ''open'',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    CONSTRAINT bug_reports_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT bug_reports_description_not_blank CHECK (btrim(description) <> '')
);

COMMENT ON TABLE bug_reports IS 'Entries submitted from the ''Report a bug'' settings option.';

CREATE INDEX bug_reports_status_idx
    ON bug_reports (status, created_at DESC);

-- === Auditing ===
CREATE TABLE audit_events (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    action audit_action NOT NULL,
    changes JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_events IS 'Immutable audit trail covering inserts, updates, and deletes.';

CREATE INDEX audit_events_table_idx
    ON audit_events (table_name, record_id);
-- === Functions & triggers ===
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER set_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_report_categories_updated_at
BEFORE UPDATE ON report_categories
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_report_subcategories_updated_at
BEFORE UPDATE ON report_subcategories
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_reports_updated_at
BEFORE UPDATE ON reports
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_report_feedbacks_updated_at
BEFORE UPDATE ON report_feedbacks
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_user_notification_preferences_updated_at
BEFORE UPDATE ON user_notification_preferences
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_user_settings_updated_at
BEFORE UPDATE ON user_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_user_category_filters_updated_at
BEFORE UPDATE ON user_category_filters
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_user_map_preferences_updated_at
BEFORE UPDATE ON user_map_preferences
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_bug_reports_updated_at
BEFORE UPDATE ON bug_reports
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_authorities_updated_at
BEFORE UPDATE ON authorities
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_report_authority_dispatches_updated_at
BEFORE UPDATE ON report_authority_dispatches
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Prevent unverified users from submitting reports.
CREATE OR REPLACE FUNCTION enforce_verified_reporter()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    current_status account_status;
BEGIN
    SELECT account_status INTO current_status
    FROM users
    WHERE user_id = NEW.user_id;

    IF current_status IS DISTINCT FROM ''verified'' THEN
        RAISE EXCEPTION 'Only verified accounts can submit reports (user_id=%).', NEW.user_id
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER reports_require_verified_user
BEFORE INSERT ON reports
FOR EACH ROW EXECUTE FUNCTION enforce_verified_reporter();

-- Keep the cached two_factor_enabled flag in sync.
CREATE OR REPLACE FUNCTION sync_two_factor_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP <> ''DELETE'' THEN
        UPDATE users
        SET two_factor_enabled = EXISTS (
            SELECT 1 FROM two_factor_methods tfm
            WHERE tfm.user_id = NEW.user_id AND tfm.enabled
        )
        WHERE user_id = NEW.user_id;
    END IF;

    IF TG_OP <> ''INSERT'' THEN
        UPDATE users
        SET two_factor_enabled = EXISTS (
            SELECT 1 FROM two_factor_methods tfm
            WHERE tfm.user_id = OLD.user_id AND tfm.enabled
        )
        WHERE user_id = OLD.user_id;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER two_factor_methods_sync_status
AFTER INSERT OR UPDATE OR DELETE ON two_factor_methods
FOR EACH ROW EXECUTE FUNCTION sync_two_factor_status();

-- Prevent reporters from flagging their own reports.
CREATE OR REPLACE FUNCTION prevent_self_flagging()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    owner_id BIGINT;
BEGIN
    SELECT user_id INTO owner_id
    FROM reports
    WHERE report_id = NEW.report_id;

    IF owner_id = NEW.user_id THEN
        RAISE EXCEPTION 'Users cannot flag their own reports (report_id=%).', NEW.report_id
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER report_flags_prevent_self
BEFORE INSERT ON report_flags
FOR EACH ROW EXECUTE FUNCTION prevent_self_flagging();

-- Audit trail for reports table.
CREATE OR REPLACE FUNCTION audit_reports_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    payload JSONB;
    actor_id BIGINT;
    action_value audit_action;
BEGIN
    IF TG_OP = ''DELETE'' THEN
        payload := to_jsonb(OLD);
        actor_id := OLD.user_id;
        action_value := ''delete'';
        INSERT INTO audit_events (table_name, record_id, user_id, action, changes)
        VALUES (TG_TABLE_NAME, OLD.report_id::TEXT, actor_id, action_value, payload);
        RETURN OLD;
    ELSIF TG_OP = ''INSERT'' THEN
        payload := to_jsonb(NEW);
        actor_id := NEW.user_id;
        action_value := ''insert'';
        INSERT INTO audit_events (table_name, record_id, user_id, action, changes)
        VALUES (TG_TABLE_NAME, NEW.report_id::TEXT, actor_id, action_value, payload);
        RETURN NEW;
    ELSE
        payload := jsonb_build_object(
            'before', to_jsonb(OLD),
            'after', to_jsonb(NEW)
        );
        actor_id := NEW.user_id;
        action_value := ''update'';
        INSERT INTO audit_events (table_name, record_id, user_id, action, changes)
        VALUES (TG_TABLE_NAME, NEW.report_id::TEXT, actor_id, action_value, payload);
        RETURN NEW;
    END IF;
END;
$$;

CREATE TRIGGER reports_audit_changes
AFTER INSERT OR UPDATE OR DELETE ON reports
FOR EACH ROW EXECUTE FUNCTION audit_reports_changes();
-- Stored helper: fetch nearby reports with optional filters.
CREATE OR REPLACE FUNCTION find_reports_nearby(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters INTEGER DEFAULT 1000,
    p_category_ids SMALLINT[] DEFAULT NULL,
    p_subcategory_ids INTEGER[] DEFAULT NULL,
    p_statuses report_state[] DEFAULT ARRAY[
        ''approved''::report_state,
        ''under_review''::report_state,
        ''submitted''::report_state
    ],
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    report_id BIGINT,
    user_id BIGINT,
    category_id SMALLINT,
    subcategory_id INTEGER,
    status report_state,
    priority report_priority,
    distance_meters DOUBLE PRECISION,
    description TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
AS $$
    SELECT r.report_id,
           r.user_id,
           r.category_id,
           r.subcategory_id,
           r.status,
           r.priority,
           ST_Distance(
               r.location_geog,
               ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
           ) AS distance_meters,
           r.description,
           r.created_at
    FROM reports r
    WHERE ST_DWithin(
              r.location_geog,
              ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
              p_radius_meters
          )
      AND (p_category_ids IS NULL OR r.category_id = ANY (p_category_ids))
      AND (p_subcategory_ids IS NULL OR r.subcategory_id = ANY (p_subcategory_ids))
      AND (p_statuses IS NULL OR r.status = ANY (p_statuses))
    ORDER BY distance_meters, r.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
$$;

-- Stored helper: fetch authorities near a coordinate filtered by category.
CREATE OR REPLACE FUNCTION find_authorities_nearby(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters INTEGER DEFAULT 50000,
    p_category_ids SMALLINT[] DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    authority_id BIGINT,
    name VARCHAR,
    level authority_level,
    distance_meters DOUBLE PRECISION,
    service_radius_meters INTEGER,
    contact_phone VARCHAR,
    hotline_phone VARCHAR,
    contact_email CITEXT
)
LANGUAGE sql
AS $$
    SELECT a.authority_id,
           a.name,
           a.level,
           ST_Distance(
               a.location_geog,
               ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
           ) AS distance_meters,
           a.service_radius_meters,
           a.contact_phone,
           a.hotline_phone,
           a.contact_email
    FROM authorities a
    LEFT JOIN authority_categories ac
        ON ac.authority_id = a.authority_id
    WHERE a.is_active
      AND a.location_geog IS NOT NULL
      AND ST_DWithin(
            a.location_geog,
            ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
            COALESCE(p_radius_meters, a.service_radius_meters)
          )
      AND (
            p_category_ids IS NULL
            OR ac.category_id = ANY (p_category_ids)
            OR ac.category_id IS NULL
          )
    ORDER BY distance_meters
    LIMIT p_limit;
$$;

COMMIT;
