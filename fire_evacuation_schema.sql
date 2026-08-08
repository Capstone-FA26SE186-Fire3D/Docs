-- ==============================================================================
-- Project : Fire Evacuation Training 3D
-- Version : 3.1 (Fix Business & Logic Issues)
-- Date    : 2026-08-08
-- Changes :
--   1. Fixed sessions: Made campaign_id NULLABLE, added scenario_version_id, guest_token.
--   2. Enhanced session_results: Added total_distance_meters, path_traveled, client timestamps.
--   3. Refactored user_devices: Removed guest_token to strictly map physical devices.
--   4. Multi-tenant isolation: Added organization_id to building_floors & release_qr_codes.
--   5. Enhanced session_checkpoints: Added player_status & world_interactive_states.
--   6. Enhanced source_documents: Added floor_id for multi-floor 2D/3D file mapping.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==============================================================================
-- ENUM TYPES
-- ==============================================================================

CREATE TYPE user_role_enum AS ENUM (
    'PlatformAdmin', 'OrgOwner', 'BimOperator', 'FireReviewer', 'Member'
);

CREATE TYPE file_type_enum AS ENUM ('IFC', 'RVT', 'DWG', 'DXF', 'PDF');

CREATE TYPE revision_status_enum AS ENUM (
    'Draft', 'Uploaded', 'Processing', 'NeedsFix', 
    'ReviewRequired', 'Approved', 'Rejected', 'Failed', 
    'Published', 'Superseded'
);

CREATE TYPE review_action_enum AS ENUM ('Approved', 'Rejected');

CREATE TYPE release_status_enum AS ENUM (
    'Built', 'Verified', 'Active', 'Deprecated', 'Revoked', 'ArchivedWarning'
);

CREATE TYPE campaign_status_enum AS ENUM (
    'Draft', 'Active', 'Closed', 'Archived'
);

CREATE TYPE quarantine_status_enum AS ENUM (
    'Pending', 'Accepted', 'Rejected'
);

CREATE TYPE session_mode_enum AS ENUM ('Learn', 'Guided', 'Assessment');

CREATE TYPE session_status_enum AS ENUM (
    'Created', 'Launching', 'Running', 'Completed',
    'CompletedWithDeprecation', 'ScenarioUnsurvivable',
    'Aborted', 'Abandoned', 'Crashed'
);

CREATE TYPE audit_action_enum AS ENUM (
    'Upload', 'Approve', 'Reject', 'Publish', 'Revoke',
    'Sync', 'Login', 'Logout', 'Download', 'Delete', 'Create', 'Update',
    'Rollback', 'Grant', 'Resume'
);

CREATE TYPE processing_step_enum AS ENUM (
    'Quarantine', 'Parse', 'CleanGeometry', 'Decimate',
    'GenNavMesh', 'GenHazardGrid', 'ExportGLB', 'PackageBundle'
);

CREATE TYPE processing_step_status_enum AS ENUM ('Started', 'Success', 'Failed');

-- ==============================================================================
-- COMMON FUNCTIONS
-- ==============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ==============================================================================
-- GROUP 1: Multi-tenant & User Management
-- ==============================================================================

CREATE TABLE organizations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255) NOT NULL,
    slug        VARCHAR(100) UNIQUE NOT NULL,
    plan        VARCHAR(50) DEFAULT 'free',
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(255),
    role            user_role_enum NOT NULL,
    is_active       BOOLEAN DEFAULT true,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT check_org_role CHECK (
        (role = 'PlatformAdmin' AND organization_id IS NULL)
        OR (role != 'PlatformAdmin' AND organization_id IS NOT NULL)
    )
);

-- Bảng lưu thiết bị phần cứng vật lý (Fix Lỗi 3: Tách biệt guest_token khỏi thiết bị)
CREATE TABLE user_devices (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID REFERENCES users(id) ON DELETE SET NULL, -- Nullable nếu thiết bị dùng chung/guest
    device_uuid    VARCHAR(255) NOT NULL UNIQUE,                -- Unique identifier duy nhất của phần cứng
    device_model   VARCHAR(255),
    os_version     VARCHAR(50),
    app_version    VARCHAR(50),
    last_seen_at   TIMESTAMPTZ DEFAULT NOW(),
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- GROUP 2: Building Management
-- ==============================================================================

CREATE TABLE buildings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    building_type   VARCHAR(100),
    total_floors    INT DEFAULT 1,
    is_active       BOOLEAN DEFAULT true,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE TABLE building_locations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES buildings(id) ON DELETE CASCADE UNIQUE,
    address     TEXT,
    city        VARCHAR(255),
    district    VARCHAR(255),
    latitude    DECIMAL(10, 8),
    longitude   DECIMAL(11, 8),
    geojson     JSONB,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Fix Lỗi 4: Thêm organization_id để cô lập Multi-tenant
CREATE TABLE building_floors (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id     UUID REFERENCES buildings(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES organizations(id) NOT NULL,
    floor_number    INT NOT NULL,
    floor_name      VARCHAR(100),
    floor_plan_url  TEXT,
    area_sqm        DECIMAL(10, 2),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (building_id, floor_number)
);

CREATE TABLE building_contacts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id  UUID REFERENCES buildings(id) ON DELETE CASCADE,
    contact_name VARCHAR(255) NOT NULL,
    contact_role VARCHAR(100),
    phone        VARCHAR(50),
    email        VARCHAR(255),
    is_primary   BOOLEAN DEFAULT false,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- GROUP 3: BIM Pipeline
-- ==============================================================================

CREATE TABLE revisions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id    UUID REFERENCES buildings(id),
    uploaded_by    UUID REFERENCES users(id),
    version_label  VARCHAR(100),
    primary_type   file_type_enum,
    status         revision_status_enum NOT NULL DEFAULT 'Draft',
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Fix Lỗi 6: Thêm floor_id để map bản vẽ 2D/PDF theo tầng
CREATE TABLE source_documents (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id        UUID REFERENCES revisions(id) ON DELETE CASCADE,
    floor_id           UUID REFERENCES building_floors(id) ON DELETE SET NULL,
    uploaded_by        UUID REFERENCES users(id),
    original_filename  VARCHAR(500) NOT NULL,
    file_type          file_type_enum NOT NULL,
    file_size_bytes    BIGINT,
    storage_url        TEXT NOT NULL,
    mime_type          VARCHAR(100),
    sha256_hash        VARCHAR(64),
    quarantine_status  quarantine_status_enum NOT NULL DEFAULT 'Pending',
    quarantine_note    TEXT,
    usage_rights       TEXT,
    source_tool        VARCHAR(255),
    created_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE annotation_sets (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    data           JSONB NOT NULL DEFAULT '{}',
    provenance     VARCHAR(50) DEFAULT 'operator',
    created_by     UUID REFERENCES users(id),
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (revision_id, version_number)
);

CREATE TABLE revision_processing_logs (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE,
    step           processing_step_enum NOT NULL,
    status         processing_step_status_enum NOT NULL,
    message        TEXT,
    duration_ms    INT,
    attempt_number INT DEFAULT 1,
    logged_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE revision_reviews (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE,
    reviewed_by    UUID REFERENCES users(id),
    action         review_action_enum NOT NULL,
    review_message TEXT,
    reviewed_at    TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_reject_message CHECK (
        action != 'Rejected' OR (review_message IS NOT NULL AND review_message != '')
    )
);

-- ==============================================================================
-- GROUP 4: Release Management
-- ==============================================================================

CREATE TABLE releases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id     UUID REFERENCES revisions(id) UNIQUE,
    building_id     UUID REFERENCES buildings(id),
    organization_id UUID REFERENCES organizations(id) NOT NULL,
    approved_by     UUID REFERENCES users(id),
    revoked_by      UUID REFERENCES users(id),
    status          release_status_enum NOT NULL DEFAULT 'Built',
    revoked_reason  TEXT,
    published_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_revoke_fields CHECK (
        (status NOT IN ('Revoked', 'ArchivedWarning'))
        OR (revoked_reason IS NOT NULL AND revoked_reason != '' AND revoked_by IS NOT NULL)
    )
);

CREATE TABLE release_packages (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id          UUID REFERENCES releases(id) ON DELETE CASCADE UNIQUE,
    manifest_url        TEXT NOT NULL,
    package_url         TEXT NOT NULL,
    checksum_sha256     VARCHAR(64),
    package_size_bytes  BIGINT,
    min_runtime_version VARCHAR(20),
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Fix Lỗi 4: Thêm organization_id
CREATE TABLE release_qr_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id      UUID REFERENCES releases(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES organizations(id) NOT NULL,
    floor_id        UUID REFERENCES building_floors(id),
    created_by      UUID REFERENCES users(id),
    qr_hash         VARCHAR(255) UNIQUE NOT NULL,
    label           VARCHAR(255),
    is_public       BOOLEAN DEFAULT false,
    expires_at      TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- GROUP 5: Campaign, Scenario & Assignment
-- ==============================================================================

CREATE TABLE scenario_versions (
    id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id                        UUID REFERENCES releases(id),
    organization_id                   UUID REFERENCES organizations(id) NOT NULL,
    version_number                    INT NOT NULL DEFAULT 1,
    name                              VARCHAR(255),
    fire_source_config                JSONB DEFAULT '{}',
    npc_config                        JSONB DEFAULT '{}',
    blocked_elements                  JSONB DEFAULT '[]',
    guidance_level                    VARCHAR(50) DEFAULT 'full',
    safety_thresholds                 JSONB DEFAULT '{}',
    replan_interval_seconds           INT DEFAULT 5,
    score_wrong_exit_penalty          INT DEFAULT 10,
    score_hazard_per_second_penalty   DECIMAL(5, 2) DEFAULT 0.50,
    score_time_bonus_threshold_seconds INT DEFAULT 120,
    is_approved                       BOOLEAN DEFAULT false,
    approved_by                       UUID REFERENCES users(id),
    approved_at                       TIMESTAMPTZ,
    created_by                        UUID REFERENCES users(id),
    created_at                        TIMESTAMPTZ DEFAULT NOW(),
    updated_at                        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (release_id, version_number)
);

CREATE TABLE campaigns (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id          UUID REFERENCES releases(id),
    scenario_version_id UUID REFERENCES scenario_versions(id),
    organization_id     UUID REFERENCES organizations(id) NOT NULL,
    name                VARCHAR(255) NOT NULL,
    description         TEXT,
    start_date          TIMESTAMPTZ,
    end_date            TIMESTAMPTZ,
    status              campaign_status_enum NOT NULL DEFAULT 'Draft',
    max_attempts        INT DEFAULT 1,
    created_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_campaign_dates CHECK (end_date IS NULL OR end_date > start_date)
);

CREATE TABLE assignments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id     UUID REFERENCES campaigns(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES organizations(id) NOT NULL,
    max_attempts    INT DEFAULT 1,
    attempts_used   INT DEFAULT 0,
    due_date        TIMESTAMPTZ,
    assigned_at     TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    UNIQUE (campaign_id, user_id),
    CONSTRAINT check_attempts CHECK (attempts_used <= max_attempts)
);

-- ==============================================================================
-- GROUP 6: Session & Results
-- ==============================================================================

-- Fix Lỗi 1 & Lỗi 3: campaign_id nullable, thêm scenario_version_id, guest_token
CREATE TABLE sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id         UUID REFERENCES campaigns(id),             -- Nullable (cho phép Free/Ad-hoc QR drill)
    scenario_version_id UUID REFERENCES scenario_versions(id) NOT NULL, -- Bắt buộc để biết cấu hình scenario
    organization_id     UUID REFERENCES organizations(id) NOT NULL,
    user_id             UUID REFERENCES users(id),                 -- Nullable nếu là Guest
    guest_token         VARCHAR(255),                              -- Nullable nếu là Member
    device_id           UUID REFERENCES user_devices(id),
    qr_code_id          UUID REFERENCES release_qr_codes(id),
    assignment_id       UUID REFERENCES assignments(id),
    mode                session_mode_enum NOT NULL,
    status              session_status_enum NOT NULL DEFAULT 'Created',
    started_at          TIMESTAMPTZ DEFAULT NOW(),
    ended_at            TIMESTAMPTZ,
    CONSTRAINT check_user_or_guest CHECK (user_id IS NOT NULL OR guest_token IS NOT NULL)
);

-- Fix Lỗi 2: Bổ sung metrics analytics đường đi & client timestamps
CREATE TABLE session_results (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id            UUID REFERENCES sessions(id) ON DELETE CASCADE UNIQUE,
    score                 DECIMAL(10, 2) DEFAULT 0,
    time_taken_seconds    INT,
    wrong_exits           INT DEFAULT 0,
    hazard_exposure_score DECIMAL(10, 2) DEFAULT 0,
    total_distance_meters DECIMAL(8, 2) DEFAULT 0,             -- Quãng đường di chuyển
    reached_exit          BOOLEAN DEFAULT false,
    exit_point_id         VARCHAR(100),
    path_traveled         JSONB DEFAULT '[]',                  -- Tóm tắt đường đi [{x,y,z,t}] cho Replay 2D/3D
    client_started_at     TIMESTAMPTZ,                         -- Giờ bắt đầu thực tế ở máy client
    client_ended_at       TIMESTAMPTZ,                         -- Giờ kết thúc thực tế ở máy client
    is_synced             BOOLEAN DEFAULT false,
    synced_at             TIMESTAMPTZ,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- Fix Lỗi 5: Thêm player_status & world_interactive_states cho Crash Recovery
CREATE TABLE session_checkpoints (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id               UUID REFERENCES sessions(id) ON DELETE CASCADE,
    sequence_number          INT NOT NULL,
    player_transform         JSONB NOT NULL,                   -- x, y, z, rotation
    player_status            JSONB DEFAULT '{}',               -- Health, Stamina, Smoke inhalation level
    world_interactive_states JSONB DEFAULT '{}',               -- Trạng thái cửa, bình chữa cháy...
    hazard_time_step         INT NOT NULL,
    npc_states               JSONB DEFAULT '[]',
    active_objectives        JSONB DEFAULT '[]',
    release_hash             VARCHAR(64),
    scenario_hash            VARCHAR(64),
    created_at               TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (session_id, sequence_number)
);

CREATE TABLE session_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES sessions(id) ON DELETE CASCADE,
    event_type  VARCHAR(100) NOT NULL,
    event_data  JSONB DEFAULT '{}',
    recorded_at TIMESTAMPTZ NOT NULL
);

-- ==============================================================================
-- GROUP 7: Audit & Security
-- ==============================================================================

CREATE TABLE audit_logs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID,
    action        audit_action_enum NOT NULL,
    target_entity VARCHAR(100) NOT NULL,
    target_id     UUID,
    old_values    JSONB,
    new_values    JSONB,
    ip_address    INET,
    user_agent    TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- INDEXES
-- ==============================================================================

CREATE INDEX idx_org_active ON organizations(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_org    ON users(organization_id);
CREATE INDEX idx_users_active ON users(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_role   ON users(role);

CREATE INDEX idx_devices_user ON user_devices(user_id);
CREATE INDEX idx_devices_uuid ON user_devices(device_uuid);

CREATE INDEX idx_buildings_org    ON buildings(organization_id);
CREATE INDEX idx_buildings_active ON buildings(deleted_at) WHERE deleted_at IS NULL;

CREATE INDEX idx_floors_building ON building_floors(building_id);
CREATE INDEX idx_floors_org      ON building_floors(organization_id);

CREATE INDEX idx_contacts_building ON building_contacts(building_id);

CREATE INDEX idx_revisions_building ON revisions(building_id);
CREATE INDEX idx_revisions_status   ON revisions(status);

CREATE INDEX idx_source_docs_revision   ON source_documents(revision_id);
CREATE INDEX idx_source_docs_floor      ON source_documents(floor_id);
CREATE INDEX idx_source_docs_quarantine ON source_documents(quarantine_status);

CREATE INDEX idx_annotations_revision ON annotation_sets(revision_id);
CREATE INDEX idx_proc_logs_revision   ON revision_processing_logs(revision_id);
CREATE INDEX idx_reviews_revision     ON revision_reviews(revision_id);

CREATE INDEX idx_releases_revision ON releases(revision_id);
CREATE INDEX idx_releases_building ON releases(building_id);
CREATE INDEX idx_releases_org      ON releases(organization_id);
CREATE INDEX idx_releases_status   ON releases(status);

CREATE UNIQUE INDEX idx_qr_hash   ON release_qr_codes(qr_hash);
CREATE INDEX idx_qr_release       ON release_qr_codes(release_id);
CREATE INDEX idx_qr_org           ON release_qr_codes(organization_id);

CREATE INDEX idx_scenario_release  ON scenario_versions(release_id);
CREATE INDEX idx_scenario_org      ON scenario_versions(organization_id);

CREATE INDEX idx_campaigns_release  ON campaigns(release_id);
CREATE INDEX idx_campaigns_scenario ON campaigns(scenario_version_id);
CREATE INDEX idx_campaigns_org      ON campaigns(organization_id);

CREATE INDEX idx_assignments_campaign ON assignments(campaign_id);
CREATE INDEX idx_assignments_user     ON assignments(user_id);

CREATE INDEX idx_sessions_campaign   ON sessions(campaign_id);
CREATE INDEX idx_sessions_scenario   ON sessions(scenario_version_id);
CREATE INDEX idx_sessions_user       ON sessions(user_id);
CREATE INDEX idx_sessions_guest      ON sessions(guest_token);
CREATE INDEX idx_sessions_org        ON sessions(organization_id);

CREATE INDEX idx_results_session  ON session_results(session_id);
CREATE INDEX idx_results_unsynced ON session_results(is_synced) WHERE is_synced = false;

CREATE INDEX idx_checkpoints_session ON session_checkpoints(session_id);

CREATE INDEX idx_events_session ON session_events(session_id);
CREATE INDEX idx_events_type    ON session_events(event_type);

CREATE INDEX idx_audit_user   ON audit_logs(user_id);
CREATE INDEX idx_audit_target ON audit_logs(target_entity, target_id);

-- ==============================================================================
-- TRIGGERS & RULES
-- ==============================================================================

CREATE TRIGGER set_ts_organizations BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_users BEFORE UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_buildings BEFORE UPDATE ON buildings FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_building_locations BEFORE UPDATE ON building_locations FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_building_floors BEFORE UPDATE ON building_floors FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_building_contacts BEFORE UPDATE ON building_contacts FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_revisions BEFORE UPDATE ON revisions FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_releases BEFORE UPDATE ON releases FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_scenario_versions BEFORE UPDATE ON scenario_versions FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_campaigns BEFORE UPDATE ON campaigns FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_session_results BEFORE UPDATE ON session_results FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE RULE prevent_update_audit_logs AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
CREATE RULE prevent_delete_audit_logs AS ON DELETE TO audit_logs DO INSTEAD NOTHING;