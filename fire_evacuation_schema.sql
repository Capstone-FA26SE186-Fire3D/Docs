-- ==============================================================================
-- Project : Fire Evacuation Training 3D
-- Version : 3.0
-- Date    : 2026-08-08
-- Changes : Sync với features/technology/workflows docs
--           + revision_status_enum: thêm Uploaded, NeedsFix, Published
--           + release_status_enum: thêm Built, Verified, ArchivedWarning
--           + campaign_status_enum, quarantine_status_enum: mới
--           + Bảng mới: source_documents, annotation_sets,
--                       scenario_versions, assignments, session_checkpoints
--           + campaigns: is_active → status, thêm scenario_version_id
--           + revisions: raw_file_url/file_size_bytes chuyển sang source_documents
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==============================================================================
-- ENUM TYPES
-- ==============================================================================

CREATE TYPE user_role_enum AS ENUM (
    'PlatformAdmin', 'OrgOwner', 'BimOperator', 'FireReviewer', 'Member'
);

CREATE TYPE file_type_enum AS ENUM ('IFC', 'RVT', 'DWG', 'DXF', 'PDF');

-- Thêm Uploaded (file đã lên server), NeedsFix (cần sửa), Published (đã tạo Release)
CREATE TYPE revision_status_enum AS ENUM (
    'Draft',           -- Revision mới tạo, chưa upload file
    'Uploaded',        -- File đã lên server, chờ worker xử lý
    'Processing',      -- Worker đang chạy
    'NeedsFix',        -- Worker xong, có issue cần Operator sửa
    'ReviewRequired',  -- Sạch issue, chờ FireReviewer duyệt
    'Approved',        -- Reviewer duyệt, chờ build package
    'Rejected',        -- Reviewer từ chối vĩnh viễn
    'Failed',          -- Worker lỗi sau tất cả retry
    'Published',       -- Release đã được tạo thành công
    'Superseded'       -- Đã có revision/release mới hơn thay thế
);

CREATE TYPE review_action_enum AS ENUM ('Approved', 'Rejected');

-- Thêm Built (package đã gen), Verified (hash OK), ArchivedWarning (revoked khi đang dùng)
CREATE TYPE release_status_enum AS ENUM (
    'Built',            -- Package đã build xong, chưa verify
    'Verified',         -- SHA-256 đã kiểm tra, sẵn sàng serve
    'Active',           -- Đang là channel hiện tại của building
    'Deprecated',       -- Bị thay thế bởi release mới hơn
    'Revoked',          -- Bị thu hồi chủ động
    'ArchivedWarning'   -- Bị revoke nhưng có session đang dùng → giữ lại cảnh báo
);

-- Vòng đời campaign
CREATE TYPE campaign_status_enum AS ENUM (
    'Draft',    -- Đang cấu hình, chưa phát
    'Active',   -- Đang trong thời gian chạy
    'Closed',   -- Hết hạn tự nhiên, kết quả hợp lệ
    'Archived'  -- Bị ẩn/thu hồi, không tính vào aggregate chính
);

-- Trạng thái kiểm duyệt file upload
CREATE TYPE quarantine_status_enum AS ENUM (
    'Pending',   -- Chờ scan MIME/hash/malware
    'Accepted',  -- File sạch, chuyển vào worker queue
    'Rejected'   -- File bị từ chối (sai MIME, quá lớn, lỗi)
);

CREATE TYPE session_mode_enum AS ENUM ('Learn', 'Guided', 'Assessment');

CREATE TYPE session_status_enum AS ENUM (
    'Created',
    'Launching',
    'Running',
    'Completed',
    'CompletedWithDeprecation', -- Offline hoàn tất nhưng release đã revoke
    'ScenarioUnsurvivable',     -- Hazard xâm nhập safe pause point, không còn route
    'Aborted',
    'Abandoned',
    'Crashed'
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
-- GROUP 1: Multi-tenant & User Management (3 bảng)
-- ==============================================================================

CREATE TABLE organizations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255) NOT NULL,
    slug        VARCHAR(100) UNIQUE NOT NULL, -- Dùng cho URL, subdomain
    plan        VARCHAR(50) DEFAULT 'free',   -- free, pro, enterprise
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ                   -- soft delete
);

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- PlatformAdmin không thuộc tổ chức nào → nullable
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
    -- PlatformAdmin: organization_id phải NULL; các role khác: phải có organization_id
    CONSTRAINT check_org_role CHECK (
        (role = 'PlatformAdmin' AND organization_id IS NULL)
        OR (role != 'PlatformAdmin' AND organization_id IS NOT NULL)
    )
);

-- Lưu thông tin thiết bị, tách khỏi sessions để tái sử dụng
CREATE TABLE user_devices (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID REFERENCES users(id),    -- nullable nếu là Guest
    guest_token    VARCHAR(255),                 -- nullable nếu là Member đăng nhập
    device_model   VARCHAR(255),
    os_version     VARCHAR(50),
    app_version    VARCHAR(50),
    last_seen_at   TIMESTAMPTZ DEFAULT NOW(),
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_user_or_guest CHECK (user_id IS NOT NULL OR guest_token IS NOT NULL)
);

-- ==============================================================================
-- GROUP 2: Building Management (4 bảng)
-- ==============================================================================

CREATE TABLE buildings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id),
    name            VARCHAR(255) NOT NULL,
    building_type   VARCHAR(100),  -- VD: 'Chung cư', 'Văn phòng', 'Bệnh viện'
    total_floors    INT DEFAULT 1,
    is_active       BOOLEAN DEFAULT true,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

-- Tách ra để query geo riêng, sau này dễ thêm PostGIS
CREATE TABLE building_locations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES buildings(id) UNIQUE,
    address     TEXT,
    city        VARCHAR(255),
    district    VARCHAR(255),
    latitude    DECIMAL(10, 8),
    longitude   DECIMAL(11, 8),
    geojson     JSONB,  -- polygon tòa nhà nếu cần vẽ bản đồ
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Mỗi tầng có QR riêng, bản vẽ riêng
CREATE TABLE building_floors (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id    UUID REFERENCES buildings(id),
    floor_number   INT NOT NULL,
    floor_name     VARCHAR(100),  -- VD: 'Tầng trệt', 'Tầng 1', 'Tầng hầm B1'
    floor_plan_url TEXT,          -- link bản vẽ mặt bằng tầng trên MinIO (tùy chọn)
    area_sqm       DECIMAL(10, 2),
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (building_id, floor_number)
);

-- Người liên hệ an toàn, PCCC của tòa nhà
CREATE TABLE building_contacts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id  UUID REFERENCES buildings(id),
    contact_name VARCHAR(255) NOT NULL,
    contact_role VARCHAR(100),  -- 'Safety Officer', 'PCCC Coordinator', 'Emergency Contact'
    phone        VARCHAR(50),
    email        VARCHAR(255),
    is_primary   BOOLEAN DEFAULT false,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- GROUP 3: BIM Pipeline (5 bảng)
-- ==============================================================================

-- Chỉ lưu metadata tổng của revision. File gốc ở source_documents
CREATE TABLE revisions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id    UUID REFERENCES buildings(id),
    uploaded_by    UUID REFERENCES users(id),
    version_label  VARCHAR(100),           -- VD: 'v1.0', 'v2.3-hotfix'
    primary_type   file_type_enum,         -- Loại file chính của revision này
    status         revision_status_enum NOT NULL DEFAULT 'Draft',
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- File nguồn thực tế: 1 revision có thể có nhiều file (VD: PDF từng tầng)
-- Tách ra để lưu provenance, license, quarantine riêng
CREATE TABLE source_documents (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id        UUID REFERENCES revisions(id),
    uploaded_by        UUID REFERENCES users(id),
    original_filename  VARCHAR(500) NOT NULL,
    file_type          file_type_enum NOT NULL,
    file_size_bytes    BIGINT,
    storage_url        TEXT NOT NULL,       -- MinIO path, chỉ backend đọc được
    mime_type          VARCHAR(100),
    sha256_hash        VARCHAR(64),         -- hash để verify toàn vẹn
    quarantine_status  quarantine_status_enum NOT NULL DEFAULT 'Pending',
    quarantine_note    TEXT,                -- lý do nếu Rejected
    usage_rights       TEXT,               -- ghi chú quyền sử dụng/license
    source_tool        VARCHAR(255),       -- phần mềm dùng để xuất file này
    created_at         TIMESTAMPTZ DEFAULT NOW()
    -- NOTE: Không có updated_at vì file gốc là bất biến sau khi upload
);

-- Versioned operator corrections: semantic label, exit, spawn, hazard source
-- Tách ra khỏi GLB để sửa không cần convert lại hình học
CREATE TABLE annotation_sets (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id    UUID REFERENCES revisions(id),
    version_number INT NOT NULL DEFAULT 1,
    -- JSON chứa toàn bộ annotation: rooms, doors, exits, checkpoints, hazard sources
    data           JSONB NOT NULL DEFAULT '{}',
    -- Nguồn gốc: 'operator' | 'auto' | 'manual-trace'
    provenance     VARCHAR(50) DEFAULT 'operator',
    created_by     UUID REFERENCES users(id),
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (revision_id, version_number)
);

-- Append-only log từng bước xử lý từ Python worker
CREATE TABLE revision_processing_logs (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id    UUID REFERENCES revisions(id),
    step           processing_step_enum NOT NULL,
    status         processing_step_status_enum NOT NULL,
    message        TEXT,    -- log chi tiết hoặc lỗi
    duration_ms    INT,     -- thời gian bước này mất bao lâu
    attempt_number INT DEFAULT 1,  -- worker retry lần 1, 2 hay 3
    logged_at      TIMESTAMPTZ DEFAULT NOW()
    -- NOTE: Không có updated_at vì append-only
);

-- Lịch sử review: 1 revision có thể bị reject → sửa → review lại nhiều lần
CREATE TABLE revision_reviews (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id    UUID REFERENCES revisions(id),
    reviewed_by    UUID REFERENCES users(id),
    action         review_action_enum NOT NULL,
    review_message TEXT,  -- bắt buộc nếu action = Rejected
    reviewed_at    TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_reject_message CHECK (
        action != 'Rejected' OR (review_message IS NOT NULL AND review_message != '')
    )
);

-- ==============================================================================
-- GROUP 4: Release Management (3 bảng)
-- ==============================================================================

CREATE TABLE releases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id     UUID REFERENCES revisions(id) UNIQUE, -- mỗi revision chỉ có tối đa 1 release
    building_id     UUID REFERENCES buildings(id),         -- DENORM để query nhanh
    organization_id UUID REFERENCES organizations(id),     -- DENORM để query nhanh
    approved_by     UUID REFERENCES users(id),
    revoked_by      UUID REFERENCES users(id),             -- nullable
    status          release_status_enum NOT NULL DEFAULT 'Built',
    revoked_reason  TEXT,
    published_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    -- Khi Revoke: bắt buộc phải có cả revoked_reason và revoked_by
    CONSTRAINT check_revoke_fields CHECK (
        (status NOT IN ('Revoked', 'ArchivedWarning'))
        OR (revoked_reason IS NOT NULL AND revoked_reason != '' AND revoked_by IS NOT NULL)
    )
);

-- Thông tin file package trên MinIO, tách khỏi release core
CREATE TABLE release_packages (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id          UUID REFERENCES releases(id) UNIQUE,
    manifest_url        TEXT NOT NULL,   -- JSON manifest trên MinIO
    package_url         TEXT NOT NULL,   -- Addressables zip đã mã hóa trên MinIO
    checksum_sha256     VARCHAR(64),     -- verify tính toàn vẹn khi download
    package_size_bytes  BIGINT,
    min_runtime_version VARCHAR(20),     -- VD: '3.44.0' (Flutter min version)
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 1 release có thể có nhiều QR code (mỗi tầng 1 QR)
CREATE TABLE release_qr_codes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id  UUID REFERENCES releases(id),
    floor_id    UUID REFERENCES building_floors(id), -- nullable: QR gắn với tầng cụ thể
    created_by  UUID REFERENCES users(id),
    qr_hash     VARCHAR(255) UNIQUE NOT NULL,
    label       VARCHAR(255),    -- VD: 'Tầng 1 - Cửa chính', 'Tầng 3 - Hành lang B'
    is_public   BOOLEAN DEFAULT false,  -- cho phép Guest quét
    expires_at  TIMESTAMPTZ,            -- null = vĩnh viễn
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- GROUP 5: Campaign, Scenario & Assignment (3 bảng)
-- ==============================================================================

-- Scenario được version hóa, có thể dùng chung cho nhiều campaign
-- Phải được FireReviewer approve trước khi campaign có thể dùng
CREATE TABLE scenario_versions (
    id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id                        UUID REFERENCES releases(id),
    organization_id                   UUID REFERENCES organizations(id),  -- DENORM
    version_number                    INT NOT NULL DEFAULT 1,
    name                              VARCHAR(255),
    -- Cấu hình nguồn cháy và lan rộng
    fire_source_config                JSONB DEFAULT '{}',  -- vị trí, thời điểm bắt đầu
    npc_config                        JSONB DEFAULT '{}',  -- archetypes, mật độ, hành vi
    blocked_elements                  JSONB DEFAULT '[]',  -- cửa/cầu thang bị chặn theo thời gian
    guidance_level                    VARCHAR(50) DEFAULT 'full',  -- full | partial | none
    -- Ngưỡng an toàn do FireReviewer set
    safety_thresholds                 JSONB DEFAULT '{}',
    -- Tham số tính điểm
    replan_interval_seconds           INT DEFAULT 5,
    score_wrong_exit_penalty          INT DEFAULT 10,
    score_hazard_per_second_penalty   DECIMAL(5, 2) DEFAULT 0.50,
    score_time_bonus_threshold_seconds INT DEFAULT 120,
    -- Phê duyệt: FireReviewer phải approve trước khi dùng
    is_approved                       BOOLEAN DEFAULT false,
    approved_by                       UUID REFERENCES users(id),  -- nullable
    approved_at                       TIMESTAMPTZ,                -- nullable
    created_by                        UUID REFERENCES users(id),
    created_at                        TIMESTAMPTZ DEFAULT NOW(),
    updated_at                        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (release_id, version_number)
);

-- Campaign ghim release và scenario_version cụ thể
CREATE TABLE campaigns (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id          UUID REFERENCES releases(id),
    scenario_version_id UUID REFERENCES scenario_versions(id),
    organization_id     UUID REFERENCES organizations(id),  -- DENORM
    name                VARCHAR(255) NOT NULL,
    description         TEXT,
    start_date          TIMESTAMPTZ,
    end_date            TIMESTAMPTZ,
    -- Thay is_active BOOLEAN bằng status enum đầy đủ hơn
    status              campaign_status_enum NOT NULL DEFAULT 'Draft',
    max_attempts        INT DEFAULT 1,  -- số lần thử tối đa mỗi participant
    created_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_campaign_dates CHECK (end_date IS NULL OR end_date > start_date)
);

-- Phân công participant vào campaign
CREATE TABLE assignments (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id  UUID REFERENCES campaigns(id),
    user_id      UUID REFERENCES users(id),
    organization_id UUID REFERENCES organizations(id),  -- DENORM
    max_attempts INT DEFAULT 1,
    attempts_used INT DEFAULT 0,
    due_date     TIMESTAMPTZ,       -- nullable
    assigned_at  TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,       -- nullable, khi đạt yêu cầu hoàn thành
    UNIQUE (campaign_id, user_id),
    CONSTRAINT check_attempts CHECK (attempts_used <= max_attempts)
);

-- ==============================================================================
-- GROUP 6: Session & Results (4 bảng)
-- ==============================================================================

-- Chỉ lưu identity + mode + trạng thái
CREATE TABLE sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id     UUID REFERENCES campaigns(id),
    user_id         UUID REFERENCES users(id),          -- NULL nếu là Guest
    device_id       UUID REFERENCES user_devices(id),   -- NULL nếu Member đã login
    organization_id UUID REFERENCES organizations(id),  -- DENORM
    qr_code_id      UUID REFERENCES release_qr_codes(id), -- biết user quét QR nào, tầng nào
    assignment_id   UUID REFERENCES assignments(id),    -- nullable nếu Guest
    mode            session_mode_enum NOT NULL,
    status          session_status_enum NOT NULL DEFAULT 'Created',
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    -- Bắt buộc phải có ít nhất 1 trong 2: user đã đăng nhập HOẶC device record của guest
    CONSTRAINT check_user_or_device CHECK (user_id IS NOT NULL OR device_id IS NOT NULL)
);

-- Kết quả cuối của session, chỉ ghi 1 lần khi session kết thúc
CREATE TABLE session_results (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id            UUID REFERENCES sessions(id) UNIQUE,
    score                 DECIMAL(10, 2) DEFAULT 0,
    time_taken_seconds    INT,
    wrong_exits           INT DEFAULT 0,
    hazard_exposure_score DECIMAL(10, 2) DEFAULT 0,
    reached_exit          BOOLEAN DEFAULT false,
    -- Unity scene object name, VD: 'Exit_Door_3F_North' - KHÔNG phải UUID
    exit_point_id         VARCHAR(100),
    is_synced             BOOLEAN DEFAULT false,  -- false = chưa đẩy lên backend
    synced_at             TIMESTAMPTZ,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- Unity ghi checkpoint mỗi 30-60 giây để Flutter có thể resume khi crash
CREATE TABLE session_checkpoints (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id       UUID REFERENCES sessions(id),
    sequence_number  INT NOT NULL,           -- monotonic, tăng dần
    player_transform JSONB NOT NULL,         -- x, y, z, rotation của người chơi
    hazard_time_step INT NOT NULL,           -- bước thời gian hazard hiện tại
    npc_states       JSONB DEFAULT '[]',     -- state của từng NPC
    active_objectives JSONB DEFAULT '[]',   -- mục tiêu đang làm
    release_hash     VARCHAR(64),            -- phải khớp để resume
    scenario_hash    VARCHAR(64),
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    -- Chỉ giữ checkpoint mới nhất là đủ dùng; xóa cũ sau sync
    UNIQUE (session_id, sequence_number)
);

-- Append-only event log từ Unity. Dùng PARTITION nếu cần scale
CREATE TABLE session_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES sessions(id) ON DELETE CASCADE,
    event_type  VARCHAR(100) NOT NULL,
    -- x/y/z, npc_id, hazard_level, route info, decision context...
    event_data  JSONB DEFAULT '{}',
    recorded_at TIMESTAMPTZ NOT NULL
);

-- ==============================================================================
-- GROUP 7: Audit & Security (1 bảng)
-- ==============================================================================

CREATE TABLE audit_logs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID,                    -- KHÔNG DÙNG FK (tránh cascade delete xóa log)
    action        audit_action_enum NOT NULL,
    target_entity VARCHAR(100) NOT NULL,  -- 'Revision', 'Release', 'Campaign'...
    target_id     UUID,
    old_values    JSONB,
    new_values    JSONB,
    ip_address    INET,
    user_agent    TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW()
    -- NOTE: Không có updated_at. RULE bên dưới chặn UPDATE/DELETE.
);

-- ==============================================================================
-- INDEXES
-- ==============================================================================

-- organizations
CREATE INDEX idx_org_active ON organizations(deleted_at) WHERE deleted_at IS NULL;

-- users
CREATE INDEX idx_users_org    ON users(organization_id);
CREATE INDEX idx_users_active ON users(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_role   ON users(role);

-- user_devices
CREATE INDEX idx_devices_user  ON user_devices(user_id);
CREATE INDEX idx_devices_guest ON user_devices(guest_token);

-- buildings
CREATE INDEX idx_buildings_org    ON buildings(organization_id);
CREATE INDEX idx_buildings_active ON buildings(deleted_at) WHERE deleted_at IS NULL;

-- building_floors
CREATE INDEX idx_floors_building ON building_floors(building_id);

-- building_contacts
CREATE INDEX idx_contacts_building ON building_contacts(building_id);

-- revisions
CREATE INDEX idx_revisions_building ON revisions(building_id);
CREATE INDEX idx_revisions_status   ON revisions(status);
CREATE INDEX idx_revisions_uploader ON revisions(uploaded_by);

-- source_documents
CREATE INDEX idx_source_docs_revision   ON source_documents(revision_id);
CREATE INDEX idx_source_docs_quarantine ON source_documents(quarantine_status);

-- annotation_sets
CREATE INDEX idx_annotations_revision ON annotation_sets(revision_id);

-- revision_processing_logs
CREATE INDEX idx_proc_logs_revision ON revision_processing_logs(revision_id);
CREATE INDEX idx_proc_logs_status   ON revision_processing_logs(status);

-- revision_reviews
CREATE INDEX idx_reviews_revision ON revision_reviews(revision_id);
CREATE INDEX idx_reviews_reviewer ON revision_reviews(reviewed_by);

-- releases
CREATE INDEX idx_releases_revision ON releases(revision_id);
CREATE INDEX idx_releases_building ON releases(building_id);
CREATE INDEX idx_releases_org      ON releases(organization_id);
CREATE INDEX idx_releases_status   ON releases(status);

-- release_qr_codes
CREATE UNIQUE INDEX idx_qr_hash   ON release_qr_codes(qr_hash);
CREATE INDEX idx_qr_release       ON release_qr_codes(release_id);
CREATE INDEX idx_qr_floor         ON release_qr_codes(floor_id);
CREATE INDEX idx_qr_active        ON release_qr_codes(is_active) WHERE is_active = true;

-- scenario_versions
CREATE INDEX idx_scenario_release  ON scenario_versions(release_id);
CREATE INDEX idx_scenario_org      ON scenario_versions(organization_id);
CREATE INDEX idx_scenario_approved ON scenario_versions(is_approved) WHERE is_approved = true;

-- campaigns
CREATE INDEX idx_campaigns_release  ON campaigns(release_id);
CREATE INDEX idx_campaigns_scenario ON campaigns(scenario_version_id);
CREATE INDEX idx_campaigns_org      ON campaigns(organization_id);
CREATE INDEX idx_campaigns_status   ON campaigns(status);

-- assignments
CREATE INDEX idx_assignments_campaign ON assignments(campaign_id);
CREATE INDEX idx_assignments_user     ON assignments(user_id);

-- sessions
CREATE INDEX idx_sessions_campaign   ON sessions(campaign_id);
CREATE INDEX idx_sessions_user       ON sessions(user_id);
CREATE INDEX idx_sessions_org        ON sessions(organization_id);
CREATE INDEX idx_sessions_status     ON sessions(status);
CREATE INDEX idx_sessions_qr         ON sessions(qr_code_id);
CREATE INDEX idx_sessions_assignment ON sessions(assignment_id);

-- session_results
CREATE INDEX idx_results_session  ON session_results(session_id);
CREATE INDEX idx_results_unsynced ON session_results(is_synced) WHERE is_synced = false;

-- session_checkpoints
CREATE INDEX idx_checkpoints_session ON session_checkpoints(session_id);

-- session_events
CREATE INDEX idx_events_session ON session_events(session_id);
CREATE INDEX idx_events_type    ON session_events(event_type);
CREATE INDEX idx_events_time    ON session_events(recorded_at);

-- audit_logs
CREATE INDEX idx_audit_user   ON audit_logs(user_id);
CREATE INDEX idx_audit_target ON audit_logs(target_entity, target_id);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_time   ON audit_logs(created_at DESC);

-- ==============================================================================
-- TRIGGERS & RULES
-- ==============================================================================

CREATE TRIGGER set_ts_organizations
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_users
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_buildings
    BEFORE UPDATE ON buildings
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_building_locations
    BEFORE UPDATE ON building_locations
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_building_floors
    BEFORE UPDATE ON building_floors
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_building_contacts
    BEFORE UPDATE ON building_contacts
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_revisions
    BEFORE UPDATE ON revisions
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_releases
    BEFORE UPDATE ON releases
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_scenario_versions
    BEFORE UPDATE ON scenario_versions
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_campaigns
    BEFORE UPDATE ON campaigns
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER set_ts_session_results
    BEFORE UPDATE ON session_results
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- Bảo vệ audit_logs: không cho UPDATE hay DELETE
CREATE RULE prevent_update_audit_logs AS
    ON UPDATE TO audit_logs DO INSTEAD NOTHING;

CREATE RULE prevent_delete_audit_logs AS
    ON DELETE TO audit_logs DO INSTEAD NOTHING;
